# SmartMess Deployment Guide

## Prerequisites

- Google Cloud Project with billing enabled
- Firebase project initialized
- Docker installed (for backend)
- Flutter SDK installed (v3.0+)
- Python 3.10+ installed

## Step 1: Firebase Setup

### Create Firebase Project

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Create new project
firebase init
```

### Configure Firestore

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project: `smartmess-project`
3. Enable Cloud Firestore
4. Set security rules:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to read/write their data
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Get Firebase Config

1. Go to Project Settings → Your Apps
2. Click Web App
3. Copy the Firebase config
4. Update `frontend/lib/firebase_options.dart`

## Step 2: Frontend Deployment

### Deploy to Firebase Hosting

```bash
cd frontend

# Install dependencies
flutter pub get

# Build for web
flutter build web --release

# Deploy
firebase deploy --only hosting
```

### Web Configuration

Update `frontend/web/index.html`:

```html
<!-- Add Google Maps API key -->
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_MAPS_API_KEY"></script>

<!-- Add Firebase scripts (if not auto-injected) -->
<script src="https://www.gstatic.com/firebasejs/9.22.2/firebase-app.js"></script>
<script src="https://www.gstatic.com/firebasejs/9.22.2/firebase-auth.js"></script>
<script src="https://www.gstatic.com/firebasejs/9.22.2/firebase-firestore.js"></script>
```

## Step 3: Backend Deployment

### Deploy to Cloud Run

```bash
cd backend

# Build Docker image
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/smartmess-api

# Deploy to Cloud Run
gcloud run deploy smartmess-api \
  --image gcr.io/YOUR_PROJECT_ID/smartmess-api \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 1Gi \
  --timeout 300
```

### Get Cloud Run URL

```bash
gcloud run services describe smartmess-api --platform managed
```

Update `frontend/lib/services/prediction_service.dart`:

```dart
static const String baseUrl = 'https://smartmess-api-XXXXX.run.app';
```

### Enable CORS on Cloud Run

The Flask app already handles CORS, but verify:

```python
from flask_cors import CORS
CORS(app)
```

## Step 4: ML Model Deployment

### Option A: Serve Model via Cloud Run

```bash
cd ml_model

# Train model
python train.py

# Copy trained model to backend
cp mess_crowd_model.h5 ../backend/
cp mess_crowd_model_scaler.pkl ../backend/

# Update backend/prediction_model.py to use trained model
```

### Option B: Use TensorFlow Serving

```bash
# Create TensorFlow Serving container
docker run -t gcr.io/YOUR_PROJECT/tf-serving \
  -v $(pwd)/models:/models \
  tensorflow/serving

# Deploy to Cloud Run
gcloud run deploy smartmess-tf-serving \
  --image gcr.io/YOUR_PROJECT/tf-serving \
  --platform managed \
  --region us-central1
```

## Step 5: Environment Setup

### Backend Environment Variables

Create `.env` in backend directory:

```
FIREBASE_PROJECT_ID=smartmess-project
FLASK_ENV=production
MODELS_PATH=/app/models
```

### Cloud Run Secrets

```bash
# Create secret for Firebase credentials
gcloud secrets create firebase-credentials \
  --data-file=serviceAccountKey.json

# Grant Cloud Run service account access
gcloud secrets add-iam-policy-binding firebase-credentials \
  --member=serviceAccount:smartmess-api@YOUR_PROJECT.iam.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor
```

## Step 6: Monitoring & Logging

### View Cloud Run Logs

```bash
gcloud run logs read smartmess-api --limit=50
```

### Set Up Monitoring

```bash
# Create uptime check
gcloud monitoring uptime create smartmess-api \
  --display-name="SmartMess API" \
  --resource-type="uptime-url" \
  --monitored-resource="https://smartmess-api-XXXXX.run.app/health"
```

## Step 7: Security

### Set Firestore Rules

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Messes - readable by all, writable by admin only
    match /messes/{messId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.admin == true;
    }
    
    // Users - read/write own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Scans - any authenticated user can write
    match /scans/{docId} {
      allow create: if request.auth != null;
      allow read: if request.auth.token.admin == true;
    }
    
    // Ratings - write own, read all
    match /ratings/{docId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
    }
    
    // Menus - readable by all, writable by admin
    match /menus/{docId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.admin == true;
    }
    
    // Rating Summary - readable by all
    match /rating_summary/{messId} {
      allow read: if request.auth != null;
      allow write: if false; // Updated via transactions only
    }
  }
}
```

### Enable API Keys

```bash
# Restrict API key to specific APIs
gcloud services enable apikeys.googleapis.com

# Create restricted API key
gcloud alpha services api-keys create \
  --api-target=firestore.googleapis.com \
  --display-name="SmartMess Firestore Key"
```

## Step 8: Performance Optimization

### Frontend Optimization

```bash
cd frontend

# Enable prerendering
flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true

# Use CDN for assets
firebase deploy --only hosting
```

### Backend Optimization

```python
# Add caching headers
@app.after_request
def add_cache_headers(response):
    response.cache_control.max_age = 300  # 5 minutes
    return response

# Use request timeouts
client = http.Client(timeout=Duration(seconds=10))
```

## Step 9: Testing & Verification

### Test Endpoints

```bash
# Test health endpoint
curl https://smartmess-api-XXXXX.run.app/health

# Test prediction endpoint
curl -X POST https://smartmess-api-XXXXX.run.app/predict \
  -H "Content-Type: application/json" \
  -d '{"messId": "mess_1"}'
```

### Load Testing

```bash
# Install load testing tool
pip install locust

# Create locustfile.py and run tests
locust -f locustfile.py --host=https://smartmess-api-XXXXX.run.app
```

## Step 10: Backup & Recovery

### Backup Firestore Data

```bash
# Export data
gcloud firestore export gs://YOUR_BUCKET/backup-$(date +%s)

# Schedule regular backups
gcloud scheduler jobs create app-engine firestore-backup \
  --schedule="0 2 * * *" \
  --http-method=POST \
  --uri="https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/firestore-backup"
```

## Troubleshooting Deployment

### Firebase Authentication Issues

```
Error: "permission-denied" in Firestore
→ Check Firestore security rules
→ Verify anonymous authentication is enabled
```

### Cloud Run Connection Timeout

```
Error: "Connection refused"
→ Check Cloud Run service is running
→ Verify port 8080 is exposed
→ Check environment variables
```

### CORS Errors

```
Error: "No 'Access-Control-Allow-Origin' header"
→ Verify Flask-CORS is initialized
→ Check @CORS decorator on routes
```

## Post-Deployment Checklist

- [ ] Firebase project created and configured
- [ ] Frontend deployed to Firebase Hosting
- [ ] Backend deployed to Cloud Run
- [ ] ML model trained and integrated
- [ ] Firestore security rules set
- [ ] Environment variables configured
- [ ] Domain/SSL configured
- [ ] Monitoring and logging enabled
- [ ] Backup strategy implemented
- [ ] Performance optimized

## Maintenance

### Monthly Tasks

- Review Cloud Run costs
- Check model accuracy metrics
- Backup Firestore data
- Update dependencies
- Review security logs

### Quarterly Tasks

- Retrain ML model with new data
- Performance optimization review
- Security audit
- User feedback analysis

---

**Deployment Complete!** 🎉

Your SmartMess application is now live and ready for use.
