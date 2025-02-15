from firebase_functions import https_fn, options
import json
# import requests
# import os
# import tempfile
# import subprocess
# import torch
# from openunmix import predict
# import soundfile as sf
from spec.config import db, bucket
from urllib.parse import urlparse
from datetime import datetime, timezone


# @https_fn.on_call(
#     cors=options.CorsOptions(
#         cors_origins=["*"],
#         cors_methods=["POST"]
#     )
# )
@https_fn.on_request()
def extract_audio_and_split_v2(req: https_fn.Request) -> https_fn.Response:
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
        response_data = {
            "status": "success",
            "message": "Cloud function successfully called",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
        return https_fn.Response(
            json.dumps(response_data),
            status=200,
            headers={"Content-Type": "application/json"}
        )
    except Exception as e:
        error_response = {
            "status": "error",
            "message": str(e),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        return https_fn.Response(
            json.dumps(error_response),
            status=500,
            headers={"Content-Type": "application/json"}
        )

    # try:
    #     # Get request data
    #     # data = req.data
    #     # video_id = data.get("videoId")
    #     response_data = {
    #         "status": "success",
    #         "message": "Cloud function successfully called",
    #         "timestamp": datetime.now(timezone.utc).isoformat()
    #     }
    #     return https_fn.Response(
    #         json.dumps(response_data),
    #         status=200,
    #         headers={"Content-Type": "application/json"}
    #     ) 
    #     return https_fn.Response(
    #         json.dumps(response_data),
    #         status=200,
    #         headers={"Content-Type": "application/json"}
    #     ) 
            
    #     if not video_id:
    #         raise ValueError("Missing required field: videoId")

    #     # Return success for now - implementation to come
    #     return {
    #         "success": True,
    #         "message": "Function shell created successfully",
    #         "videoId": video_id
    #     }
        
    # except Exception as e:
    #     raise https_fn.HttpsError("internal", str(e))

    # # except subprocess.CalledProcessError as e:
    # #     error_message = f"FFmpeg processing error: {str(e)}"
    # #     if hasattr(e, 'output'):
    # #         error_message += f" - {e.output.decode()}"
        
    # #     db.collection("videos").document(video_id).update({
    # #         "audioProcessingStatus": "failed",
    # #         "audioProcessingError": error_message
    # #     })
        
    # # except ValueError as e:
    # #     error_message = str(e)
    # #     print("error_message", error_message)
    # #     print("video_id", video_id)
    # #     if video_id:
    # #         db.collection("videos").document(video_id).update({
    # #             "audioProcessingStatus": "failed",
    # #             "audioProcessingError": error_message
    # #         })
        
    # #     raise https_fn.HttpsError("internal", error_message)
        
    # # except Exception as e:
    # #     error_message = f"Error processing audio: {str(e)}"
        
    # #     if video_id:
    # #         db.collection("videos").document(video_id).update({
    # #             "audioProcessingStatus": "failed",
    # #             "audioProcessingError": error_message
    # #         })
        
    # #     raise https_fn.HttpsError("internal", error_message)
