from firebase_functions import https_fn, options
import json
import requests
from spec.config import db, bucket, OPENSHOT_API_URL, OPENSHOT_HEADERS

@https_fn.on_call(
    cors=options.CorsOptions(
        cors_origins=["*"],
        cors_methods=["POST"]
    )
)
def validate_and_prepare_video(req: https_fn.CallableRequest) -> dict:
    """
    Cloud Function to validate a video file and prepare it for processing using OpenShot.
    
    Expected request data:
    {
        "videoId": string,
        "userId": string,
        "title": string,
        "description": string
    }
    """
    try:
        # Get request data
        data = req.data
        video_id = data.get("videoId")
        user_id = data.get("userId")
        
        if not all([video_id, user_id]):
            raise ValueError("Missing required fields: videoId and userId are required")

        # Get video file from Firebase Storage
        video_blob = bucket.get_blob(f"videos/{user_id}/{video_id}/openshot/original.mp4")
        
        if not video_blob:
            raise ValueError("Video file not found in storage")

        # Create OpenShot project
        project_data = {
            "name": f"video_{video_id}",
            "width": 1920,
            "height": 1080,
            "fps_num": 30,
            "fps_den": 1,
            "sample_rate": 44100,
            "channels": 2,
            "channel_layout": 3,
            "json": "{}"
        }
        
        project_response = requests.post(
            f"{OPENSHOT_API_URL}/projects/",
            headers=OPENSHOT_HEADERS,
            json=project_data
        )
        project_response.raise_for_status()
        project_data = project_response.json()
        project_id = project_data["id"]
        
        # Upload video file to OpenShot
        file_data = {
            "media": None,
            "project": f"{OPENSHOT_API_URL}/projects/{project_id}/",
            "json": json.dumps({
                "url": video_blob.public_url,
                "name": f"video_{video_id}.mp4"
            })
        }
        
        file_response = requests.post(
            f"{OPENSHOT_API_URL}/files/",
            headers=OPENSHOT_HEADERS,
            json=file_data
        )
        file_response.raise_for_status()
        file_data = file_response.json()
        
        # Extract validation metadata from OpenShot response
        validation_metadata = {
            "width": file_data["json"].get("width"),
            "height": file_data["json"].get("height"),
            "duration": file_data["json"].get("duration"),
            "codec": file_data["json"].get("vcodec"),
            "format": file_data["json"].get("media_type"),
            "bitrate": file_data["json"].get("video_bit_rate")
        }
        
        # Update Firestore document with OpenShot metadata
        video_ref = db.collection("videos").document(video_id)
        video_ref.update({
            "processingStatus": "pending",
            "validationMetadata": validation_metadata,
            "openshot": {
                "projectId": project_id,
                "fileId": file_data["id"]
            }
        })
        
        return {
            "success": True,
            "projectId": project_id,
            "fileId": file_data["id"],
            "validationMetadata": validation_metadata
        }
        
    except requests.exceptions.RequestException as e:
        # Handle OpenShot API errors
        error_message = f"OpenShot API error: {str(e)}"
        if hasattr(e, 'response') and e.response is not None:
            error_message += f" - {e.response.text}"
        
        # Update Firestore with error status
        video_ref = db.collection("videos").document(video_id)
        video_ref.update({
            "processingStatus": "failed",
            "processingError": "invalid_format",
            "validationErrors": [error_message]
        })
        
        raise https_fn.HttpsError("failed-precondition", error_message)
        
    except Exception as e:
        # Handle other errors
        error_message = f"Error processing video: {str(e)}"
        
        # Update Firestore with error status
        video_ref = db.collection("videos").document(video_id)
        video_ref.update({
            "processingStatus": "failed",
            "processingError": "processing_failed",
            "validationErrors": [error_message]
        })
        
        raise https_fn.HttpsError("internal", error_message) 