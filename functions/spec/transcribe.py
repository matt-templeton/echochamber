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
import contextlib
import io
import gc
import base64

# Set Python's IO encoding to UTF-8
os.environ['PYTHONIOENCODING'] = 'utf-8'

# Context manager for UTF-8 stdout
@contextlib.contextmanager
def utf8_stdout():
    old_stdout = sys.stdout
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='ignore')
    try:
        yield
    finally:
        sys.stdout = old_stdout

@https_fn.on_request(
    region="us-central1",
    memory=options.MemoryOption.GB_1,
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
        print("\n=== Starting new transcription request ===")
        
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

        # Get audio track info from Firestore
        track_doc = db.collection("videos").document(video_id)\
                     .collection("audioTracks").document(audio_track_id).get()
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
        temp_dir = tempfile.mkdtemp()
        print(f"Created temp directory: {temp_dir}")
        
        try:
            # Download audio file
            downloaded_audio_path = os.path.join(temp_dir, "downloaded_audio.wav")
            try:
                # First download as TS file
                temp_ts_path = os.path.join(temp_dir, "temp.ts")
                ydl_opts = {
                    'format': 'bestaudio/best',
                    'outtmpl': temp_ts_path,
                    'verbose': False,
                    'no_warnings': True,
                    'encoding': None,
                    'legacy_server_connect': False,
                    'force_generic_extractor': True
                }
                
                ydl = None
                try:
                    print("Starting yt-dlp download...")
                    ydl = yt_dlp.YoutubeDL(ydl_opts)
                    ydl.download([master_url])
                    print("yt-dlp download completed")
                finally:
                    if ydl:
                        print("Closing yt-dlp...")
                        ydl.close()
                        print("yt-dlp closed")
                
                # Convert TS to WAV using FFmpeg
                print("Converting TS to WAV...")
                ffmpeg_cmd = [
                    'ffmpeg', '-y',
                    '-i', temp_ts_path,
                    '-acodec', 'pcm_s16le',
                    '-ar', '44100',
                    '-ac', '2',
                    '-loglevel', 'error',
                    downloaded_audio_path
                ]
                
                result = subprocess.run(ffmpeg_cmd, capture_output=True, text=True)
                if result.returncode != 0:
                    raise Exception(f"FFmpeg conversion failed with code: {result.returncode}")
                
                print("Audio conversion completed")

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

            # Load and process audio file
            audio = None
            audio_duration = None
            try:
                print("Loading audio file...")
                audio = AudioSegment.from_wav(downloaded_audio_path)
                audio_duration = len(audio) / 1000.0  # Store duration in seconds
                
                if start_time is not None or end_time is not None:
                    print("Applying time slicing...")
                    start_ms = int(start_time * 1000) if start_time is not None else 0
                    end_ms = int(end_time * 1000) if end_time is not None else len(audio)
                    
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
                    
                    audio = audio[start_ms:end_ms]
                    audio_duration = len(audio) / 1000.0  # Update duration after slicing
                
                processed_audio_path = os.path.join(temp_dir, "processed_audio.wav")
                print(f"Exporting processed audio to: {processed_audio_path}")
                audio.export(processed_audio_path, format="wav")
                print("Audio export completed")
                
            finally:
                if audio:
                    print("Cleaning up audio resources...")
                    if hasattr(audio, '_data'):
                        print("Clearing audio data")
                        audio._data = None
                    if hasattr(audio, 'converter'):
                        print(f"Audio converter type: {type(audio.converter)}")
                        if hasattr(audio.converter, 'cleanup'):
                            print("Cleaning up audio converter")
                            try:
                                audio.converter.cleanup()
                            except Exception as e:
                                print(f"Warning: Failed to cleanup audio converter: {e}")
                    audio = None
                    print("Audio resources cleanup completed")
            
            # Generate MIDI
            try:
                print("Generating MIDI...")
                midi_path = os.path.join(temp_dir, "processed_audio_basic_pitch.mid")
                
                # Only use utf8_stdout for the MIDI generation
                with utf8_stdout():
                    predict_and_save(
                        [processed_audio_path],
                        temp_dir,
                        model_or_model_path=ICASSP_2022_MODEL_PATH,
                        save_midi=True,
                        sonify_midi=False,
                        save_model_outputs=False,
                        save_notes=False
                    )
                
                # Separate file check and reading from MIDI generation
                if not os.path.exists(midi_path):
                    print(f"MIDI file not found at: {midi_path}")
                    print(f"Directory contents: {os.listdir(temp_dir)}")
                    return https_fn.Response(
                        json.dumps({
                            "success": False,
                            "error": "MIDI file generation failed - output file not found"
                        }, ensure_ascii=False).encode('utf-8'),
                        status=500,
                        headers={"Content-Type": "application/json; charset=utf-8"}
                    )
                
                # Read MIDI file with explicit file handling
                print("Reading MIDI file...")
                try:
                    with open(midi_path, "rb") as f:
                        midi_data = f.read()
                    print("MIDI file read successfully")
                except IOError as e:
                    print(f"Error reading MIDI file: {e}")
                    return https_fn.Response(
                        json.dumps({
                            "success": False,
                            "error": f"Failed to read generated MIDI file: {str(e)}"
                        }, ensure_ascii=False).encode('utf-8'),
                        status=500,
                        headers={"Content-Type": "application/json; charset=utf-8"}
                    )
                
                midi_base64 = base64.b64encode(midi_data).decode('utf-8')
                
                time_range = {
                    "startTime": start_time if start_time is not None else 0,
                    "endTime": end_time if end_time is not None else audio_duration
                }
                
                print("Preparing successful response")
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
                error_msg = ''.join(c for c in error_msg if ord(c) < 128)
                print(f"Error in MIDI generation: {error_msg}")
                return https_fn.Response(
                    json.dumps({
                        "success": False,
                        "error": f"Error generating MIDI: {error_msg}"
                    }, ensure_ascii=False).encode('utf-8'),
                    status=500,
                    headers={"Content-Type": "application/json; charset=utf-8"}
                )
        finally:
            print("\n=== Cleanup Phase ===")
            print("Running garbage collection...")
            gc.collect()
            
            print(f"Cleaning up temp directory: {temp_dir}")
            try:
                import shutil
                if os.path.exists(temp_dir):
                    print("Directory exists, attempting removal...")
                    shutil.rmtree(temp_dir)
                    print("Directory removed successfully")
                else:
                    print("Directory already removed")
            except Exception as e:
                print(f"Warning: Failed to clean up temporary directory: {e}")
            print("=== Cleanup Phase Complete ===\n")
                
    except Exception as e:
        error_msg = str(e)
        error_msg = ''.join(c for c in error_msg if ord(c) < 128)
        print(f"Unhandled error: {error_msg}")
        return https_fn.Response(
            json.dumps({
                "success": False,
                "error": f"Error processing transcription: {error_msg}"
            }, ensure_ascii=False).encode('utf-8'),
            status=500,
            headers={"Content-Type": "application/json; charset=utf-8"}
        )
