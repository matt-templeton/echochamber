from firebase_admin import initialize_app, storage, firestore, credentials
from firebase_functions import https_fn, options
import os

    # Load service account credentials
service_account_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'service-account.json')
cred = credentials.Certificate(service_account_path)
app = initialize_app(cred)
db = firestore.client()
bucket = storage.bucket(name="gs://echo-chamber-8fb5f.firebasestorage.app")


# OpenShot configuration from environment variables
OPENSHOT_API_URL = os.getenv('OPENSHOT_API_URL', 'http://localhost')
OPENSHOT_API_TOKEN = os.getenv('OPENSHOT_API_TOKEN', '')
OPENSHOT_HEADERS = {
    "Authorization": f"Token {OPENSHOT_API_TOKEN}",
    "Content-Type": "application/json"
}