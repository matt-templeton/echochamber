import json
import pytest
from firebase_functions import https_fn
from ..main import baseline_function

def test_test_function_success(mock_request):
    """Test that test_function returns expected success response."""
    # Call the function
    response = baseline_function(mock_request)
    
    # Parse response
    response_data = json.loads(response.data)
    
    # Assertions
    assert response.status_code == 200
    assert response.headers.get('Content-Type') == 'application/json'
    assert response_data['status'] == 'success'
    assert response_data['message'] == 'Cloud function successfully called'
    assert 'timestamp' in response_data  # verify timestamp exists

def test_test_function_response_format(mock_request):
    """Test that test_function response follows expected format."""
    response = baseline_function(mock_request)
    response_data = json.loads(response.data)
    
    # Check response structure
    expected_keys = {'status', 'message', 'timestamp'}
    assert set(response_data.keys()) == expected_keys

def test_basic_function_call(mock_request):
    """Test the basic function call works."""
    response = baseline_function(mock_request)
    assert response.status_code == 200  # Assert instead of returning
    assert response.headers.get('Content-Type') == 'application/json'
