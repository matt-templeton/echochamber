# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

from firebase_functions import https_fn
from firebase_admin import initialize_app
import json
from datetime import datetime, timezone

# Initialize Firebase Admin SDK
initialize_app()

@https_fn.on_request()
def baseline_function(request: https_fn.Request) -> https_fn.Response:
    """Simple test function to verify cloud functions are working.
    
    Returns:
        https_fn.Response: JSON response indicating successful function call
    """
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

# initialize_app()
#
#
# @https_fn.on_request()
# def on_request_example(req: https_fn.Request) -> https_fn.Response:
#     return https_fn.Response("Hello world!")