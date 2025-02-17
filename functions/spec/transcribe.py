from firebase_functions import https_fn, options
import json
import tempfile
import os
from datetime import datetime, timezone
import yt_dlp
import requests
from basic_pitch.inference import predict_and_save
from basic_pitch import ICASSP_2022_MODEL_PATH
from spec.config import db, bucket
from pydub import AudioSegment
import sys
import subprocess

# Remove global encoding setup as it interferes with yt-dlp

@https_fn.on_request(
    memory=1024,  # Set memory limit to 1GB
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["POST", "OPTIONS"]
    )
)
def transcribe_to_midi(req: https_fn.Request) -> https_fn.Response:
    """
    Cloud Function to transcribe an audio track to MIDI using basic-pitch.
    
    Expected request body:
    {
        "trackId": string,  # Format: "videoId/audioTrackId"
        "startTime": float | None,  # Optional start time in seconds
        "endTime": float | None     # Optional end time in seconds
    }
    
    Returns:
        JSON response containing the MIDI file data as a base64 string
    """
    try:
        # Get request data
        try:
            request_json = req.get_json()
            track_id = request_json.get("trackId")
            start_time = request_json.get("startTime")
            end_time = request_json.get("endTime")
        except ValueError:
            return https_fn.Response(
                json.dumps({
                    "success": False,
                    "error": "Invalid JSON in request body"
                }),
                status=400,
                headers={"Content-Type": "application/json"}
            )
        
        if not track_id:
            return https_fn.Response(
                json.dumps({
                    "success": False,
                    "error": "Missing required field: trackId"
                }),
                status=400,
                headers={"Content-Type": "application/json"}
            )

        # Parse the track_id into video_id and audio_track_id
        try:
            video_id, audio_track_id = track_id.split('/')
        except ValueError:
            return https_fn.Response(
                json.dumps({
                    "success": False,
                    "error": "Invalid trackId format. Expected format: videoId/audioTrackId"
                }),
                status=400,
                headers={"Content-Type": "application/json"}
            )

        # Get audio track info from Firestore subcollection
        track_doc = db.collection("videos").document(video_id)\
                     .collection("audioTracks").document(audio_track_id).get()
        print("TRACK DOC: ", track_doc)
        if not track_doc.exists:
            return https_fn.Response(
                json.dumps({
                    "success": False,
                    "error": f"Audio track {audio_track_id} not found in video {video_id}"
                }),
                status=404,
                headers={"Content-Type": "application/json"}
            )
            
        track_data = track_doc.to_dict()
        master_url = track_data.get("masterPlaylistUrl")
        if not master_url:
            return https_fn.Response(
                json.dumps({
                    "success": False,
                    "error": "Master playlist URL not found in track data"
                }),
                status=404,
                headers={"Content-Type": "application/json"}
            )

        # Create temporary directory for processing
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download audio file
            downloaded_audio_path = os.path.join(temp_dir, "downloaded_audio.wav")
            try:
                print(f"Attempting to download audio from URL: {master_url}")
                
                # Configure yt-dlp with HLS handling and explicit encoding settings
                ydl_opts = {
                    'format': 'bestaudio/best',
                    'outtmpl': downloaded_audio_path,
                    'extract_audio': True,
                    'audio_format': 'wav',
                    'verbose': True,
                    'no_warnings': False,
                    'encoding': None,  # Let yt-dlp handle encoding
                    'legacy_server_connect': False,
                    'force_generic_extractor': True
                }
                print("HERE")
                print(ydl_opts)
                
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    # First try to extract info
                    print("Extracting info...")
                    info = ydl.extract_info(master_url, download=False)
                    print(f"Found format: {info.get('format', 'unknown')}")
                    
                    # Then download
                    print("Starting download...")
                    ydl.download([master_url])
                print("Download completed successfully")

            except Exception as e:
                error_detail = str(e)
                if hasattr(e, 'stderr'):
                    error_detail += f"\nFFmpeg stderr: {e.stderr}"
                if hasattr(e, 'stdout'):
                    error_detail += f"\nFFmpeg stdout: {e.stdout}"
                    
                return https_fn.Response(
                    json.dumps({
                        "success": False,
                        "error": f"Error downloading audio: {error_detail}"
                    }, ensure_ascii=False).encode('utf-8'),
                    status=500,
                    headers={"Content-Type": "application/json; charset=utf-8"}
                )

            # Load the audio file
            try:
                audio = AudioSegment.from_wav(downloaded_audio_path)
                print("AUDIO: ", audio)
                # Apply time slicing if start_time or end_time is provided
                if start_time is not None or end_time is not None:
                    # Convert times to milliseconds
                    start_ms = int(start_time * 1000) if start_time is not None else 0
                    end_ms = int(end_time * 1000) if end_time is not None else len(audio)
                    
                    # Validate time range
                    if start_ms < 0:
                        start_ms = 0
                    if end_ms > len(audio):
                        end_ms = len(audio)
                    if start_ms >= end_ms:
                        return https_fn.Response(
                            json.dumps({
                                "success": False,
                                "error": "Invalid time range: start_time must be less than end_time"
                            }),
                            status=400,
                            headers={"Content-Type": "application/json"}
                        )
                    
                    # Extract the segment
                    audio = audio[start_ms:end_ms]
                
                # Save the processed audio
                processed_audio_path = os.path.join(temp_dir, "processed_audio.wav")
                audio.export(processed_audio_path, format="wav")
                
            except Exception as e:
                return https_fn.Response(
                    json.dumps({
                        "success": False,
                        "error": f"Error processing audio segment: {str(e)}"
                    }),
                    status=500,
                    headers={"Content-Type": "application/json"}
                )

            # Generate MIDI using basic-pitch
            try:
                predict_and_save(
                    [processed_audio_path],
                    temp_dir,
                    model_or_model_path=ICASSP_2022_MODEL_PATH,
                    save_midi=True,
                    sonify_midi=False,
                    save_model_outputs=False,
                    save_notes=False
                )
                
                # Read the generated MIDI file
                midi_path = os.path.join(temp_dir, "processed_audio.midi")
                if not os.path.exists(midi_path):
                    return https_fn.Response(
                        json.dumps({
                            "success": False,
                            "error": "MIDI file generation failed - output file not found"
                        }, ensure_ascii=False).encode('utf-8'),
                        status=500,
                        headers={"Content-Type": "application/json; charset=utf-8"}
                    )
                
                with open(midi_path, "rb") as f:
                    midi_data = f.read()
                
                # Return MIDI data as base64 string
                import base64
                midi_base64 = base64.b64encode(midi_data).decode('utf-8')
                
                # Include time range in response
                time_range = {
                    "startTime": start_time if start_time is not None else 0,
                    "endTime": end_time if end_time is not None else audio.duration_seconds
                }
                
                return https_fn.Response(
                    json.dumps({
                        "success": True,
                        "midiData": midi_base64,
                        "filename": f"{track_id}_{time_range['startTime']:.1f}_{time_range['endTime']:.1f}.midi",
                        "timeRange": time_range,
                        "timestamp": datetime.now(timezone.utc).isoformat()
                    }, ensure_ascii=False).encode('utf-8'),
                    status=200,
                    headers={"Content-Type": "application/json; charset=utf-8"}
                )
                
            except Exception as e:
                error_msg = str(e)
                # Remove any problematic characters from error message
                error_msg = ''.join(c for c in error_msg if ord(c) < 128)
                return https_fn.Response(
                    json.dumps({
                        "success": False,
                        "error": f"Error generating MIDI: {error_msg}"
                    }, ensure_ascii=False).encode('utf-8'),
                    status=500,
                    headers={"Content-Type": "application/json; charset=utf-8"}
                )
                
    except Exception as e:
        error_msg = str(e)
        # Remove any problematic characters from error message
        error_msg = ''.join(c for c in error_msg if ord(c) < 128)
        return https_fn.Response(
            json.dumps({
                "success": False,
                "error": f"Error processing transcription: {error_msg}"
            }, ensure_ascii=False).encode('utf-8'),
            status=500,
            headers={"Content-Type": "application/json; charset=utf-8"}
        )
