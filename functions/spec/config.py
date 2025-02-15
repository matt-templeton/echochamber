from firebase_admin import initialize_app, storage, firestore, credentials
from firebase_functions import https_fn, options
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Load service account credentials
service_account_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'service-account.json')
cred = credentials.Certificate(service_account_path)
app = initialize_app(cred)
db = firestore.client()
bucket = storage.bucket(name="gs://echo-chamber-8fb5f.firebasestorage.app")

# OpenShot configuration from environment variables
OPENSHOT_API_URL = os.getenv('OPENSHOT_API_URL')
OPENSHOT_AUTH_HEADER = os.getenv('OPENSHOT_AUTH_HEADER')
OPENSHOT_CONTENT_TYPE = os.getenv('OPENSHOT_CONTENT_TYPE')

OPENSHOT_HEADERS = {
    "Authorization": OPENSHOT_AUTH_HEADER,
    "Content-Type": OPENSHOT_CONTENT_TYPE
}