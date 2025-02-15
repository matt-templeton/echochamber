import pytest
from unittest.mock import Mock, patch
from flask import Flask
from flask_cors import CORS
from firebase_functions import https_fn
import json
import requests
from spec.validate_and_prepare_video import validate_and_prepare_video

@pytest.fixture(autouse=True)
def app_context():
    app = Flask(__name__)
    CORS(app)
    with app.app_context():
        with app.test_request_context():
            yield

@pytest.fixture
def mock_storage_blob():
    mock_blob = Mock()
    mock_blob.public_url = "https://storage.googleapis.com/test-bucket/test-video.mp4"
    return mock_blob

@pytest.fixture
def mock_firestore_doc():
    mock_doc = Mock()
    mock_doc.exists = True
    return mock_doc

@pytest.fixture
def mock_request():
    mock = Mock(spec=https_fn.CallableRequest)
    mock.method = "POST"
    mock.headers = {"Content-Type": "application/json"}
    return mock

def test_validate_and_prepare_video_success(mock_request, mock_storage_blob, mock_firestore_doc):
    # Arrange
    request_data = {
        "videoId": "test-video-id",
        "userId": "test-user-id",
        "title": "Test Video",
        "description": "Test Description"
    }
    mock_request.data = json.dumps({"data": request_data})
    mock_request.json = {"data": request_data}

    # Mock OpenShot API responses
    mock_project_response = Mock()
    mock_project_response.json.return_value = {
        "id": "test-project-id",
        "url": "http://test-url/projects/test-project-id/"
    }

    mock_file_response = Mock()
    mock_file_response.json.return_value = {
        "id": "test-file-id",
        "json": {
            "width": 1920,
            "height": 1080,
            "duration": 120.5,
            "vcodec": "h264",
            "media_type": "video",
            "video_bit_rate": 5000000
        }
    }

    with patch("spec.config.bucket") as mock_bucket, \
         patch("spec.config.db") as mock_db, \
         patch("requests.post") as mock_post:

        # Setup mocks
        mock_bucket.get_blob.return_value = mock_storage_blob
        mock_db.collection.return_value.document.return_value = mock_firestore_doc
        mock_post.side_effect = [mock_project_response, mock_file_response]

        # Act
        response = validate_and_prepare_video(mock_request)
        result = json.loads(response.data)
        assert 'result' in result
        result = result['result']
        # Assert
        assert result["success"] is True
        assert result["projectId"] == "test-project-id"
        assert result["fileId"] == "test-file-id"
        assert result["validationMetadata"]["width"] == 1920
        assert result["validationMetadata"]["height"] == 1080
        
        # Verify Firestore update was called
        mock_firestore_doc.update.assert_called_once()
        update_data = mock_firestore_doc.update.call_args[0][0]
        assert update_data["processingStatus"] == "pending"
        assert update_data["openshot"]["projectId"] == "test-project-id"
        assert update_data["openshot"]["fileId"] == "test-file-id"

def test_validate_and_prepare_video_missing_fields(mock_request):
    # Arrange
    request_data = {
        "videoId": "test-video-id"
        # Missing userId
    }
    mock_request.data = json.dumps({"data": request_data})
    mock_request.json = {"data": request_data}
    
    with patch("spec.config.db") as mock_db:
        mock_doc = Mock()
        mock_db.collection.return_value.document.return_value = mock_doc
        
        # Act
        response = validate_and_prepare_video(mock_request)
        
        # Assert
        assert response.status_code == 500
        error_data = json.loads(response.data)
        assert "error" in error_data
        assert "Missing required fields" in error_data["error"]["message"]
        assert error_data["error"]["status"] == "INTERNAL"

def test_validate_and_prepare_video_file_not_found(mock_request):
    # Arrange
    request_data = {
        "videoId": "test-video-id",
        "userId": "test-user-id"
    }
    mock_request.data = json.dumps({"data": request_data})
    mock_request.json = {"data": request_data}
    
    with patch("spec.config.bucket") as mock_bucket, \
         patch("spec.config.db") as mock_db:
        # Setup mocks
        mock_bucket.get_blob.return_value = None
        mock_doc = Mock()
        mock_db.collection.return_value.document.return_value = mock_doc
        
        # Act
        response = validate_and_prepare_video(mock_request)
        
        # Assert
        assert response.status_code == 500
        error_data = json.loads(response.data)
        assert "error" in error_data
        assert "Video file not found" in error_data["error"]["message"]
        assert error_data["error"]["status"] == "INTERNAL"
        
        # Verify Firestore was updated with error status
        mock_doc.update.assert_called_once()
        update_data = mock_doc.update.call_args[0][0]
        assert update_data["processingStatus"] == "failed"
        assert "Video file not found" in update_data.get("validationErrors", [])[0]

def test_validate_and_prepare_video_openshot_error(mock_request, mock_storage_blob, mock_firestore_doc):
    # Arrange
    request_data = {
        "videoId": "test-video-id",
        "userId": "test-user-id"
    }
    mock_request.data = json.dumps({"data": request_data})
    mock_request.json = {"data": request_data}
    
    with patch("spec.config.bucket") as mock_bucket, \
         patch("spec.config.db") as mock_db, \
         patch("requests.post") as mock_post:
        
        # Setup mocks
        mock_bucket.get_blob.return_value = mock_storage_blob
        mock_db.collection.return_value.document.return_value = mock_firestore_doc
        mock_post.side_effect = requests.exceptions.RequestException("OpenShot API error")
        
        # Act
        response = validate_and_prepare_video(mock_request)
        
        # Assert
        assert response.status_code == 400
        error_data = json.loads(response.data)
        assert "error" in error_data
        assert "OpenShot API error" in error_data["error"]["message"]
        assert error_data["error"]["status"] == "FAILED_PRECONDITION"
        
        # Verify error status was updated in Firestore
        mock_firestore_doc.update.assert_called_once()
        update_data = mock_firestore_doc.update.call_args[0][0]
        assert update_data["processingStatus"] == "failed"
        assert update_data["processingError"] == "invalid_format"
        assert "OpenShot API error" in update_data.get("validationErrors", [])[0] 