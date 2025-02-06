import pytest
import os

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

@pytest.fixture
def mock_request():
    """Create a mock HTTP request object."""
    from firebase_functions import https_fn
    # Create minimal WSGI environ
    environ = {
        'REQUEST_METHOD': 'GET',
        'SCRIPT_NAME': '',
        'PATH_INFO': '',
        'QUERY_STRING': '',
        'SERVER_NAME': 'localhost',
        'SERVER_PORT': '80',
        'SERVER_PROTOCOL': 'HTTP/1.1',
        'wsgi.version': (1, 0),
        'wsgi.url_scheme': 'http',
        'wsgi.input': None,
        'wsgi.errors': None,
        'wsgi.multithread': False,
        'wsgi.multiprocess': False,
        'wsgi.run_once': False
    }
    return https_fn.Request(environ)
