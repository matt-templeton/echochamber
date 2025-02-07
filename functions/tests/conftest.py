import pytest
import os
from unittest.mock import Mock, patch
import firebase_admin
from firebase_functions import https_fn

@pytest.fixture(autouse=True)
def env():
    """Set up test environment variables."""
    # Set test environment variables
    os.environ['FIREBASE_PROJECT_ID'] = 'test-project'
    os.environ['GCLOUD_PROJECT'] = 'test-project'
    yield
    # Clean up after tests
    os.environ.pop('FIREBASE_PROJECT_ID', None)
    os.environ.pop('GCLOUD_PROJECT', None)

@pytest.fixture(autouse=True)
def mock_firebase_admin():
    """Mock Firebase Admin initialization to avoid credential errors."""
    with patch('firebase_admin.initialize_app') as mock_init, \
         patch('firebase_admin.credentials.Certificate') as mock_cert, \
         patch('firebase_admin.firestore.client') as mock_firestore, \
         patch('firebase_admin.storage.bucket') as mock_storage:
        
        # Set up mock returns
        mock_firestore.return_value = Mock()
        mock_storage.return_value = Mock()
        
        yield {
            'init': mock_init,
            'cert': mock_cert,
            'firestore': mock_firestore,
            'storage': mock_storage
        }

@pytest.fixture
def mock_request():
    """Create a mock HTTP request."""
    mock_req = Mock(spec=https_fn.Request)
    mock_req.get_json.return_value = {}
    return mock_req
