# Deployment Instructions - Real-Time Predictions

## Overview

This guide covers deploying the real-time prediction system to Google Cloud Run.

## Prerequisites

- ✅ Flask backend (`backend/main.py`)
- ✅ Prediction model (`backend/prediction_model.py`)
- ✅ Training script (`ml_model/train_simple.py`)
- ✅ Firebase credentials (`backend/serviceAccountKey.json`)
- ✅ Google Cloud project with Cloud Run enabled

## Step 1: Prepare the Backend

### 1.1 Copy Model Data to Backend
```bash
# From project root
cp ml_model/model_data.json backend/

# Verify
ls -la backend/model_data.json
```

### 1.2 Verify Python Dependencies
```bash
cd backend
pip install -r requirements.txt
```

**Backend requirements should include:**
- flask
- flask-cors
- firebase-admin
- numpy

## Step 2: Deploy Backend to Cloud Run

### 2.1 Build Docker Image
```bash
cd backend

# Build
docker build -t smartmess-backend:latest .

# Tag for Google Cloud
docker tag smartmess-backend:latest \
  gcr.io/YOUR_PROJECT_ID/smartmess-backend:latest
```

### 2.2 Push to Google Cloud Registry
```bash
# Configure Docker
gcloud auth configure-docker

# Push
docker push gcr.io/YOUR_PROJECT_ID/smartmess-backend:latest
```

### 2.3 Deploy to Cloud Run
```bash
gcloud run deploy smartmess-backend \
  --image gcr.io/YOUR_PROJECT_ID/smartmess-backend:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "FIREBASE_PROJECT_ID=YOUR_PROJECT_ID"
```

**Note:** Get your service URL from the deployment output

## Step 3: Set Up Automated Model Training

### 3.1 Create Cloud Scheduler Job

```bash
# Create job
gcloud scheduler jobs create pubsub train-predictions \
  --schedule "*/15 * * * *" \
  --topic smartmess-training \
  --message-body '{"action":"train"}' \
  --location us-central1
```

### 3.2 Create Cloud Function for Training

**File:** `functions/train_model.py`

```python
import subprocess
import os
import firebase_admin
from firebase_admin import credentials, storage
from google.cloud import storage as gcs

def train_model(event, context):
    """
    Cloud Function triggered by Cloud Scheduler to retrain model
    """
    print("Starting model training...")
    
    try:
        # Run training script
        result = subprocess.run(
            ['python', '/workspace/ml_model/train_simple.py'],
            capture_output=True,
            text=True,
            timeout=600
        )
        
        if result.returncode == 0:
            print("✓ Training completed successfully")
            
            # Upload model_data.json to Cloud Storage
            bucket = gcs.Client().bucket('smartmess-models')
            blob = bucket.blob('model_data.json')
            blob.upload_from_filename('/workspace/ml_model/model_data.json')
            
            # Download to backend container
            # (This is handled by the backend at startup)
            
            return {'status': 'success', 'output': result.stdout}
        else:
            print("✗ Training failed")
            return {'status': 'error', 'output': result.stderr}
            
    except Exception as e:
        print(f"✗ Error: {e}")
        return {'status': 'error', 'error': str(e)}
```

### 3.3 Deploy Cloud Function

```bash
gcloud functions deploy train-model \
  --runtime python39 \
  --trigger-topic smartmess-training \
  --entry-point train_model \
  --timeout 600s \
  --memory 512MB
```

## Step 4: Configure Environment Variables

### Backend Environment
```bash
# In Cloud Run service
gcloud run services update smartmess-backend \
  --update-env-vars \
  MODEL_PATH=/app/model_data.json,\
  FIREBASE_PROJECT_ID=your-project,\
  FLASK_ENV=production
```

### Training Environment
```bash
# For Cloud Functions
gcloud functions deploy train-model \
  --update-env-vars \
  FIREBASE_PROJECT_ID=your-project
```

## Step 5: Verify Deployment

### 5.1 Test Backend Endpoint

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe smartmess-backend \
  --region us-central1 --format 'value(status.url)')

# Test prediction endpoint
curl -X POST $SERVICE_URL/predict \
  -H "Content-Type: application/json" \
  -d '{
    "mess_id": "mess1",
    "timestamp": "2025-12-23T13:00:00Z"
  }'
```

### 5.2 Check Training Logs

```bash
# View most recent training
gcloud functions describe train-model --format='value(status.updateTime)'

# View logs
gcloud functions logs read train-model --limit 100

# Watch logs in real-time
gcloud functions logs read train-model --follow
```

### 5.3 Monitor Model Updates

```bash
# Check if model_data.json is being updated
gcloud storage ls -h gs://smartmess-models/model_data.json
```

## Step 6: Configure CORS (If Needed)

### In backend/main.py

```python
from flask_cors import CORS

app = Flask(__name__)
CORS(app, resources={
    r"/predict": {
        "origins": ["https://smartmess-frontend.com"],
        "methods": ["POST"],
        "max_age": 3600
    }
})
```

## Step 7: Set Up Monitoring

### Create Cloud Monitoring Alert

```bash
# Monitor error rate
gcloud monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="SmartMess Backend Errors" \
  --condition-display-name="High Error Rate" \
  --condition-threshold-filter='metric.type="run.googleapis.com/request_count" AND resource.label.service_name="smartmess-backend"'
```

### Create Logs Dashboard

```bash
# View backend logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=smartmess-backend" \
  --limit 100 \
  --format json
```

## Step 8: Database Setup

### Firebase Firestore Structure

Ensure your Firestore has the correct structure:

```
attendance/
├── mess1/
│   ├── 2025-12-23/
│   │   ├── breakfast/
│   │   │   └── students/{student_id}
│   │   ├── lunch/
│   │   │   └── students/{student_id}
│   │   └── dinner/
│   │       └── students/{student_id}
│   └── 2025-12-22/
│       └── (same structure)
├── mess2/
└── mess3/
```

### Create Sample Collection Rules

```bash
# In Firebase Console -> Firestore -> Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /attendance/{messId}/{date}/{meal}/students/{studentId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == studentId;
      allow read: if false; // Disable for public
    }
  }
}
```

## Step 9: Backup & Recovery

### Backup Model Data

```bash
# Create backup
gsutil cp gs://smartmess-models/model_data.json \
  gs://smartmess-backups/model_data_$(date +%Y%m%d_%H%M%S).json

# Schedule automatic backups
gsutil rsync -d -r gs://smartmess-models/ gs://smartmess-backups/
```

## Troubleshooting Deployment

### Backend not starting
```bash
# Check logs
gcloud run logs read smartmess-backend --limit 100

# Common issues:
# - serviceAccountKey.json not found
# - PORT environment variable not set
# - Requirements not installed
```

### Model training failing
```bash
# Check function logs
gcloud functions logs read train-model --limit 50

# Common issues:
# - Firebase credentials not configured
# - Firestore collection structure incorrect
# - Insufficient permissions
```

### Slow predictions
```bash
# Check Cloud Run metrics
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_latencies"'

# Common issues:
# - Firebase query slow
# - Network latency
# - High CPU usage
```

## Production Checklist

- [ ] Backend deployed to Cloud Run
- [ ] Model data in cloud storage
- [ ] Cloud Scheduler job created (every 15 min)
- [ ] Cloud Function for training deployed
- [ ] Environment variables configured
- [ ] CORS settings configured for frontend domain
- [ ] Firebase Firestore structure verified
- [ ] Monitoring and alerts configured
- [ ] Backup procedures tested
- [ ] Load testing completed
- [ ] Frontend integration tested
- [ ] Logging configured and visible

## Quick Deployment Script

```bash
#!/bin/bash

PROJECT_ID="your-project-id"
REGION="us-central1"
SERVICE_NAME="smartmess-backend"

echo "Building Docker image..."
cd backend
docker build -t gcr.io/$PROJECT_ID/$SERVICE_NAME:latest .

echo "Pushing to registry..."
docker push gcr.io/$PROJECT_ID/$SERVICE_NAME:latest

echo "Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME:latest \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --set-env-vars "FIREBASE_PROJECT_ID=$PROJECT_ID"

echo "✓ Deployment complete!"
gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)'
```

## Rollback Procedure

```bash
# If something goes wrong, rollback to previous version
gcloud run services update-traffic smartmess-backend \
  --to-revisions PREVIOUS_REVISION=100

# Or deploy previous image
docker push gcr.io/$PROJECT_ID/smartmess-backend:previous
gcloud run deploy smartmess-backend \
  --image gcr.io/$PROJECT_ID/smartmess-backend:previous
```

---

**Deployment Version:** 1.0
**Last Updated:** 2025-12-23
**Status:** Ready for Production ✅
