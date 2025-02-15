from firebase_functions import https_fn, options
import json
import requests
import os
import tempfile
import subprocess
import torch
from openunmix import predict
import soundfile as sf
from spec.config import db, bucket
from urllib.parse import urlparse

@https_fn.on_call(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["POST"]
    )
)
def extract_audio_and_split(req: https_fn.CallableRequest) -> dict:
    """
    Cloud Function to take a video that's already uploaded,
    extract the audio into an identical hls schema, then split 
    each audio segment into separate instruments. 

    (MVP of this will use the uxm model to split any audio into
    vocals, drums, bass, and 'other')
    
    Expected request data:
    {
        "videoId": string
    }
    """
    try:
        # Get request data and validate
        data = req.data
        video_id = data.get("videoId")
        
        if not video_id:
            raise ValueError("Missing required field: videoId")

        # Check if video exists in Firestore
        video_doc = db.collection("videos").document(video_id).get()
        if not video_doc.exists:
            raise ValueError(f"Video with ID {video_id} not found")
        
        video_data = video_doc.to_dict()
        user_id = video_data.get("userId")
        video_url = video_data.get("videoUrl")

        if not all([user_id, video_url]):
            raise ValueError("Video document missing required fields")

        # Parse the video URL to get the base path
        # Example URL: https://storage.googleapis.com/bucket-name/videos/user-id/video-id/master.m3u8
        parsed_url = urlparse(video_url)
        path_parts = parsed_url.path.split('/')
        video_base_path = '/'.join(path_parts[2:])  # Remove bucket name and leading slash
        video_base_path = os.path.dirname(video_base_path)  # Remove master.m3u8

        # Check if audio has already been extracted
        audio_base_path = f"audio/{video_id}"
        audio_exists = False
        try:
            audio_exists = any(True for _ in bucket.list_blobs(prefix=audio_base_path))
        except Exception:
            pass

        if audio_exists:
            raise ValueError("Audio has already been extracted for this video")

        # Get list of all stream directories
        stream_blobs = list(bucket.list_blobs(prefix=video_base_path))
        stream_dirs = set()
        for blob in stream_blobs:
            if "stream_" in blob.name and blob.name.endswith(".ts"):
                stream_dir = os.path.dirname(blob.name)
                stream_dirs.add(stream_dir)

        # Create audio directory structure
        audio_tracks = ["original", "drums", "bass", "vocals", "other"]
        
        # Process each stream directory
        for stream_dir in stream_dirs:
            # Get all segment files in this stream
            segment_blobs = [b for b in stream_blobs if b.name.startswith(stream_dir) and b.name.endswith(".ts")]
            
            # Process each segment
            for segment_blob in segment_blobs:
                segment_name = os.path.basename(segment_blob.name)
                stream_name = os.path.basename(stream_dir)
                
                # Create temporary directory for processing
                with tempfile.TemporaryDirectory() as temp_dir:
                    # Download segment
                    temp_ts_path = os.path.join(temp_dir, "segment.ts")
                    segment_blob.download_to_filename(temp_ts_path)
                    
                    # Convert to WAV using ffmpeg
                    temp_wav_path = os.path.join(temp_dir, "segment.wav")
                    ffmpeg_cmd = f'ffmpeg -i "{temp_ts_path}" -ab 160k -ac 2 -ar 44100 -vn "{temp_wav_path}"'
                    subprocess.run(ffmpeg_cmd, shell=True, check=True)
                    
                    # Upload original audio
                    original_path = f"{audio_base_path}/original/{stream_name}/{segment_name}"
                    bucket.blob(original_path).upload_from_filename(temp_wav_path)
                    
                    # Split audio using openunmix
                    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
                    audio_data, sr = sf.read(temp_wav_path)
                    estimates = predict.separate(
                        torch.as_tensor(audio_data).float(),
                        rate=sr,
                        device=device
                    )
                    
                    # Save and upload each stem
                    for target, estimate in estimates.items():
                        if target == "original":  # Skip original as we already handled it
                            continue
                            
                        # Convert to audio and save temporarily
                        audio = estimate.detach().cpu().numpy()[0]
                        temp_stem_path = os.path.join(temp_dir, f"{target}.wav")
                        sf.write(temp_stem_path, audio.T, sr, subtype='PCM_24')
                        
                        # Convert back to TS format
                        temp_stem_ts = os.path.join(temp_dir, f"{target}.ts")
                        ffmpeg_cmd = f'ffmpeg -i "{temp_stem_path}" -c:a aac -b:a 128k "{temp_stem_ts}"'
                        subprocess.run(ffmpeg_cmd, shell=True, check=True)
                        
                        # Upload to appropriate directory
                        stem_path = f"{audio_base_path}/{target}/{stream_name}/{segment_name}"
                        bucket.blob(stem_path).upload_from_filename(temp_stem_ts)

        # Update video document to indicate audio processing is complete
        video_doc.reference.update({
            "audioProcessingStatus": "completed",
            "audioTracks": audio_tracks
        })

        return {
            "success": True,
            "message": "Audio extraction and splitting completed successfully",
            "audioTracks": audio_tracks
        }

    except subprocess.CalledProcessError as e:
        error_message = f"FFmpeg processing error: {str(e)}"
        if hasattr(e, 'output'):
            error_message += f" - {e.output.decode()}"
        
        db.collection("videos").document(video_id).update({
            "audioProcessingStatus": "failed",
            "audioProcessingError": error_message
        })
        
        raise https_fn.HttpsError("internal", error_message)
        
    except Exception as e:
        error_message = f"Error processing audio: {str(e)}"
        
        db.collection("videos").document(video_id).update({
            "audioProcessingStatus": "failed",
            "audioProcessingError": error_message
        })
        
        raise https_fn.HttpsError("internal", error_message)
