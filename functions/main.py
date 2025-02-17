# Welcome to Cloud Functions for Firebase for Python!
# Deploy with `firebase deploy`

from spec import health_check, transcribe_to_midi

# Export the functions
__all__ = [
    'health_check',               # Health check endpoint that returns success status
    'transcribe_to_midi',         # Transcribes audio track to MIDI using basic-pitch
]