import pytest
from unittest.mock import Mock, patch, MagicMock
import torch
import numpy as np
from firebase_functions import https_fn
import json
from spec.extract_audio_and_split import extract_audio_and_split
import subprocess
from flask import Flask
from flask_cors import CORS

@pytest.fixture(autouse=True)
def app_context():
    app = Flask(__name__)
    CORS(app)
    with app.app_context():
        with app.test_request_context():
            yield

@pytest.fixture
def mock_request():
    mock = Mock(spec=https_fn.CallableRequest)
    mock.method = "POST"
    mock.headers = {"Content-Type": "application/json"}
    return mock

@pytest.fixture
def mock_storage_blob():
    mock_blob = Mock()
    mock_blob.name = "videos/test-user/test-video/stream_0/segment_0.ts"
    return mock_blob

@pytest.fixture
def mock_firestore_doc():
    mock_doc = Mock()
    mock_doc.exists = True
    mock_doc.to_dict.return_value = {
        "userId": "test-user",
        "videoUrl": "https://storage.googleapis.com/test-bucket/videos/test-user/test-video/master.m3u8"
    }
    return mock_doc

@pytest.fixture
def mock_estimates():
    return {
        "vocals": torch.tensor([[[0.1, 0.2, 0.3]]]),
        "drums": torch.tensor([[[0.2, 0.3, 0.4]]]),
        "bass": torch.tensor([[[0.3, 0.4, 0.5]]]),
        "other": torch.tensor([[[0.4, 0.5, 0.6]]])
    }

def test_extract_audio_and_split_success(mock_request, mock_storage_blob, mock_firestore_doc, mock_estimates):
    # Arrange
    request_data = {
        "videoId": "test-video"
    }
    mock_request.data = json.dumps({"data": request_data})
    mock_request.json = {"data": request_data}

    # Mock the stream blobs list
    mock_stream_blobs = [
        mock_storage_blob
    ]

    with patch("spec.config.bucket") as mock_bucket, \
         patch("spec.config.db") as mock_db, \
         patch("subprocess.run") as mock_subprocess, \
         patch("soundfile.read") as mock_sf_read, \
         patch("soundfile.write") as mock_sf_write, \
         patch("openunmix.predict.separate") as mock_separate, \
         patch("tempfile.TemporaryDirectory") as mock_temp_dir:
        
        # Setup mocks
        mock_bucket.list_blobs.side_effect = [
            [], # First call for checking if audio exists
            mock_stream_blobs # Second call for getting video segments
        ]
        mock_db.collection.return_value.document.return_value.get.return_value = mock_firestore_doc
        mock_sf_read.return_value = (np.array([0.1, 0.2, 0.3]), 44100)
        mock_separate.return_value = mock_estimates
        mock_temp_dir.return_value.__enter__.return_value = "/tmp/test"
        
        # Act
        response = extract_audio_and_split(mock_request)
        result = json.loads(response.data)['result']

        # Assert
        assert result["success"] is True
        assert result["audioTracks"] == ["original", "drums", "bass", "vocals", "other"]
        
        # Verify Firestore update was called
        mock_firestore_doc.reference.update.assert_called_once()
        update_data = mock_firestore_doc.reference.update.call_args[0][0]
        assert update_data["audioProcessingStatus"] == "completed"
        assert update_data["audioTracks"] == ["original", "drums", "bass", "vocals", "other"]

def test_extract_audio_and_split_missing_video_id(mock_request):
    # Arrange
    request_data = {}  # Missing videoId
    mock_request.data = json.dumps({"data": request_data})
    mock_request.json = {"data": request_data}
    
    # Act
    response = extract_audio_and_split(mock_request)
    
    # Assert
    assert response.status_code == 500
    error_data = json.loads(response.data)
    assert "error" in error_data
    assert "Missing required field: videoId" in error_data["error"]["message"]
    assert error_data["error"]["status"] == "INTERNAL"

def test_extract_audio_and_split_video_not_found(mock_request):
    # Arrange
    request_data = {
        "videoId": "nonexistent-video"
    }
    mock_request.data = json.dumps({"data": request_data})
    mock_request.json = {"data": request_data}
    
    with patch("spec.config.db") as mock_db:
        # Setup mock to return non-existent document
        mock_doc = Mock()
        mock_doc.exists = False
        mock_db.collection.return_value.document.return_value.get.return_value = mock_doc
        
        # Act
        response = extract_audio_and_split(mock_request)
        
        # Assert
        assert response.status_code == 500
        error_data = json.loads(response.data)
        assert "error" in error_data
        assert "Video with ID nonexistent-video not found" in error_data["error"]["message"]
        assert error_data["error"]["status"] == "INTERNAL"

def test_extract_audio_and_split_missing_video_url(mock_request):
    # Arrange
    request_data = {
        "videoId": "test-video"
    }
    mock_request.data = json.dumps({"data": request_data})
    mock_request.json = {"data": request_data}
    
    with patch("spec.config.db") as mock_db:
        # Setup mock to return doc without videoUrl
        mock_doc = Mock()
        mock_doc.exists = True
        mock_doc.to_dict.return_value = {
            "userId": "test-user"
            # Missing videoUrl
        }
        mock_db.collection.return_value.document.return_value.get.return_value = mock_doc
        
        # Act
        response = extract_audio_and_split(mock_request)
        
        # Assert
        assert response.status_code == 500
        error_data = json.loads(response.data)
        assert "error" in error_data
        assert "Video document missing required fields" in error_data["error"]["message"]
        assert error_data["error"]["status"] == "INTERNAL"

def test_extract_audio_and_split_audio_already_exists(mock_request, mock_firestore_doc):
    # Arrange
    request_data = {
        "videoId": "test-video"
    }
    mock_request.data = json.dumps({"data": request_data})
    mock_request.json = {"data": request_data}
    
    with patch("spec.config.bucket") as mock_bucket, \
         patch("spec.config.db") as mock_db:
        
        # Setup mocks to indicate audio already exists
        mock_bucket.list_blobs.return_value = [Mock()]  # Return a non-empty list
        mock_db.collection.return_value.document.return_value.get.return_value = mock_firestore_doc
        
        # Act
        response = extract_audio_and_split(mock_request)
        
        # Assert
        assert response.status_code == 500
        error_data = json.loads(response.data)
        assert "error" in error_data
        assert "Audio has already been extracted" in error_data["error"]["message"]
        assert error_data["error"]["status"] == "INTERNAL"

def test_extract_audio_and_split_ffmpeg_error(mock_request, mock_storage_blob, mock_firestore_doc):
    # Arrange
    request_data = {
        "videoId": "test-video"
    }
    mock_request.data = json.dumps({"data": request_data})
    mock_request.json = {"data": request_data}
    
    mock_stream_blobs = [mock_storage_blob]
    
    with patch("spec.config.bucket") as mock_bucket, \
         patch("spec.config.db") as mock_db, \
         patch("subprocess.run") as mock_subprocess, \
         patch("tempfile.TemporaryDirectory") as mock_temp_dir:
        
        # Setup mocks
        mock_bucket.list_blobs.side_effect = [[], mock_stream_blobs]
        mock_db.collection.return_value.document.return_value.get.return_value = mock_firestore_doc
        mock_subprocess.side_effect = subprocess.CalledProcessError(1, "ffmpeg", output=b"FFmpeg error")
        mock_temp_dir.return_value.__enter__.return_value = "/tmp/test"
        
        # Act
        response = extract_audio_and_split(mock_request)
        
        # Assert
        assert response.status_code == 500
        error_data = json.loads(response.data)
        assert "error" in error_data
        assert "FFmpeg processing error" in error_data["error"]["message"]
        assert error_data["error"]["status"] == "INTERNAL"
        
        # Verify error status was updated in Firestore
        mock_firestore_doc.reference.update.assert_called_once()
        update_data = mock_firestore_doc.reference.update.call_args[0][0]
        assert update_data["audioProcessingStatus"] == "failed"
        assert "FFmpeg processing error" in update_data["audioProcessingError"] 