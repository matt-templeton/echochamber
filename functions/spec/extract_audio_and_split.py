from firebase_functions import https_fn, options
import json
import requests

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
    pass
