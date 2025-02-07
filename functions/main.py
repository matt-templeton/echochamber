# Welcome to Cloud Functions for Firebase for Python!
# Deploy with `firebase deploy`

from spec import health_check, validate_and_prepare_video, app

# Export the functions
__all__ = [
    'health_check',               # Health check endpoint that returns success status
    'validate_and_prepare_video',  # Validates uploaded video and creates OpenShot project
    ]