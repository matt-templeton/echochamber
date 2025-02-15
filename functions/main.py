# Welcome to Cloud Functions for Firebase for Python!
# Deploy with `firebase deploy`

from spec import health_check, validate_and_prepare_video, extract_audio_and_split

# Export the functions
__all__ = [
    'health_check',               # Health check endpoint that returns success status
    'validate_and_prepare_video',  # Validates uploaded video and creates OpenShot project
    'extract_audio_and_split',     # Extracts and splits audio from video into separate tracks
]