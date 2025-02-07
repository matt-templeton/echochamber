from firebase_functions import https_fn
import json
from datetime import datetime, timezone

@https_fn.on_request()
def health_check(request: https_fn.Request) -> https_fn.Response:
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