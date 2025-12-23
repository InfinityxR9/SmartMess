# SmartMess Deployment Guide

## Overview

SmartMess is deployed on Google Cloud Platform with the following architecture:
- **Frontend:** Flutter Web hosted on Firebase Hosting
- **Backend:** Flask API on Cloud Run
- **Database:** Firebase Firestore
- **ML Model:** Crowd prediction model trained on attendance data

## Prerequisites

- Google Cloud Project with billing enabled
- Firebase project initialized (smartmess-project)
- Docker installed (for backend)
- Flutter SDK v3.0+ installed
- Python 3.10+ installed
- gcloud CLI installed and configured
- Firebase CLI installed

## Pre-Deployment Checklist

- [ ] Clone repository and install all dependencies
- [ ] Update Firebase configuration in `frontend/lib/firebase_options.dart`
- [ ] Create `serviceAccountKey.json` from Firebase Console
- [ ] Place `serviceAccountKey.json` in `backend/` directory
- [ ] Create `.env` file in `backend/` with `SECRET_KEY`
- [ ] Test locally: `cd backend && python main.py`
- [ ] Test frontend: `cd frontend && flutter run -d web`
- [ ] Train ML model: `cd ml_model && python train.py`

---

## Step 1: Firestore Setup

### Create Collections

Ensure the following collections exist in Firestore:

```
attendance          - Student attendance records
attendance          - All marked attendance (breakfast/lunch/dinner)
loginCredentials    - User login credentials (username, password, role)
reviews             - Student reviews and ratings
messes              - Mess information (name, capacity, timings)
qrCodes             - QR codes for attendance (auto-delete after 7 days)
predictions         - ML predictions (auto-delete after 90 days)
```

### Set Data Retention Policies

For TTL (Time-to-Live) on collections, add a `deleteAt` field to documents:

```javascript
// In backend when creating records:

// QR Codes - delete after 7 days
db.collection('qrCodes').add({
  code: qrCode,
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  deleteAt: admin.firestore.FieldValue.serverTimestamp() + 7 * 24 * 60 * 60
})

// Predictions - keep for 3 months
db.collection('predictions').add({
  messId: messId,
  timestamp: admin.firestore.FieldValue.serverTimestamp(),
  deleteAt: admin.firestore.FieldValue.serverTimestamp() + 90 * 24 * 60 * 60
})
```

### Set Security Rules

Go to Firestore → Rules and update:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Allow unauthenticated read access to loginCredentials for login
    match /loginCredentials/{document=**} {
      allow read;
    }
    
    // Attendance - authenticated read, backend write
    match /attendance/{document=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Reviews - authenticated only
    match /reviews/{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Messes - read-only
    match /messes/{document=**} {
      allow read: if true;
      allow write: if false;
    }
    
    // Predictions - read-only
    match /predictions/{document=**} {
      allow read: if true;
      allow write: if false;
    }
    
    // Default deny all
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Step 2: Backend Deployment (Cloud Run)

### Prepare Backend

1. **Create `.env` file in `backend/` directory:**

```env
FLASK_ENV=production
SECRET_KEY=<generate-using-secrets-module>
PORT=8080
```

2. **Generate SECRET_KEY:**

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

3. **Verify requirements.txt** contains all dependencies:

```
Flask
Flask-CORS
firebase-admin
numpy
pandas
python-dotenv
```

### Deploy to Cloud Run

```bash
# Navigate to backend directory
cd backend

# Build and deploy to Cloud Run
gcloud run deploy smartmess-backend \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 512Mi \
  --timeout 60 \
  --set-env-vars FLASK_ENV=production

# Note the service URL displayed (e.g., https://smartmess-backend-xxxxx.run.app)
```

### Verify Backend Deployment

```bash
# Test health endpoint
curl https://smartmess-backend-xxxxx.run.app/health

# Should respond: {"status": "healthy"}

# Test prediction endpoint (during meal hours)
curl -X POST https://smartmess-backend-xxxxx.run.app/predict \
  -H "Content-Type: application/json" \
  -d '{"messId": "mess_001"}'
```

### Set Up Cloud Scheduler for Auto-Training

```bash
# Create a Cloud Scheduler job to retrain model every 7 days
gcloud scheduler jobs create http smartmess-retrain \
  --schedule="0 2 * * MON" \
  --uri="https://smartmess-backend-xxxxx.run.app/train" \
  --http-method=POST \
  --location=us-central1

# Verify job was created
gcloud scheduler jobs describe smartmess-retrain --location=us-central1
```

---

## Step 3: ML Model Training

### Initial Training

```bash
cd ml_model

# Place serviceAccountKey.json in ml_model/ or ../backend/
# Run training
python train.py

# If no Firebase data exists, the script will offer to generate dummy data
# Select 'y' to generate test data and train the model

# Output: crowd_model.h5 and scaler.pkl
```

### Deploy Trained Model

```bash
# Copy trained model to backend
cp crowd_model.h5 ../backend/
cp scaler.pkl ../backend/

# Commit to version control (or use Cloud Storage)
git add crowd_model.h5 scaler.pkl
git commit -m "Update trained ML model"
```

### Verify Training

```bash
# Check if model was created
ls -la crowd_model.h5 scaler.pkl

# Test predictions locally
python -c "from crowd_predictor import MessCrowdPredictor; p = MessCrowdPredictor(); print(p.predict_next_slots())"
```

---

## Step 4: Frontend Deployment (Firebase Hosting)

### Build Frontend

```bash
cd frontend

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build for web (release mode)
flutter build web --release
```

### Update API Configuration

Before deploying, update `frontend/lib/services/prediction_service.dart`:

```dart
class PredictionService {
  // Update this to your Cloud Run backend URL
  static const String baseUrl = 'https://smartmess-backend-xxxxx.run.app';
  
  // Or use environment variable for flexibility
  static final String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080'
  );
  
  // ... rest of code
}
```

### Deploy to Firebase Hosting

```bash
# From frontend directory
cd frontend

# Deploy only to hosting
firebase deploy --only hosting

# Or deploy with custom message
firebase deploy --only hosting --message "Production release v1.0"
```

### Verify Frontend Deployment

- Navigate to: `https://smartmess-project.web.app`
- Test student login with credentials from `loginCredentials` collection
- Test manager login
- Verify predictions work (during meal hours):
  - 7:30-9:30 AM (Breakfast)
  - 12:00-2:00 PM (Lunch)
  - 7:30-9:30 PM (Dinner)
- Test QR code scanning on web (Chrome/Firefox)

---

## Step 5: DNS & Domain Configuration

### Connect Custom Domain

```bash
firebase hosting:channel:deploy production --expire 7d
```

Then configure DNS:
1. In Firebase Console: Hosting → Custom Domain
2. Add your domain (e.g., smartmess.example.com)
3. Update DNS records as instructed
4. Wait for SSL certificate provisioning (24-48 hours)

---

## Step 6: Monitoring & Logging

### Cloud Run Logs

```bash
# View recent logs
gcloud run logs read smartmess-backend --limit 50

# Stream logs in real-time
gcloud run logs read smartmess-backend --stream

# Filter by error level
gcloud run logs read smartmess-backend --filter "severity=ERROR"
```

### Set Up Alerts

```bash
# Create alert for high error rate
gcloud alpha monitoring policies create \
  --notification-channels=YOUR_CHANNEL_ID \
  --display-name="SmartMess High Error Rate" \
  --condition-display-name="Error rate > 5%" \
  --condition-threshold-value=5
```

### Monitor Model Performance

```bash
# Check Cloud Storage for model metrics
gsutil ls gs://smartmess-models/

# View model training logs
gcloud ai-platform jobs describe smartmess-training-job
```

---

## Step 7: Backup & Recovery

### Firestore Backups

```bash
# Create manual backup
gcloud firestore databases backup \
  --async \
  --location=us-central1

# Schedule automatic daily backups
gcloud scheduler jobs create app-engine firestore-daily-backup \
  --schedule="0 2 * * *" \
  --http-method=POST \
  --uri="https://region-project.cloudfunctions.net/firestore-backup"
```

### Restore from Backup

```bash
# List available backups
gcloud firestore backups describe backup-id

# Restore specific backup
gcloud firestore databases restore backup-id
```

---

## Step 8: Performance Optimization

### Frontend Optimization

```bash
# Build with optimizations
flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true

# Enable gzip compression in Firebase
firebase.json:
{
  "hosting": {
    "headers": [{
      "source": "**",
      "headers": [{
        "key": "Cache-Control",
        "value": "public, max-age=300"
      }]
    }]
  }
}
```

### Backend Optimization

- Cloud Run automatically scales based on traffic
- Set memory to 512MB minimum for ML predictions
- Use connection pooling for Firestore
- Enable response caching where applicable

---

## Step 9: Security Checklist

- [ ] Firestore security rules reviewed and applied
- [ ] API endpoints have rate limiting
- [ ] CORS properly configured (only allow your domain)
- [ ] SECRET_KEY stored in .env (not in code)
- [ ] serviceAccountKey.json not committed to git
- [ ] Cloud Run service requires authentication where needed
- [ ] SSL/TLS enabled for all endpoints
- [ ] Regular security audits scheduled
- [ ] Error messages don't expose sensitive information
- [ ] Input validation implemented on all endpoints

---

## Step 10: Post-Deployment Testing

### Functional Testing

```bash
# Test all meal time predictions (7:30-9:30 AM breakfast)
# Verify QR code scanning works on web
# Test attendance marking
# Verify analytics show all metrics
# Check manager dashboard updates
# Verify predictions visible to students
```

### Performance Testing

```bash
# Test with multiple concurrent users
# Load test backend API
# Monitor response times
# Check error rates
```

### Security Testing

```bash
# Test unauthorized access to endpoints
# Verify sensitive data is not exposed
# Test input validation
# Check for CORS vulnerabilities
```

---

## Troubleshooting Deployment

### Backend Issues

| Issue | Solution |
|-------|----------|
| **503 Service Unavailable** | Check Cloud Run logs: `gcloud run logs read smartmess-backend --limit 50` |
| **Timeout errors** | Increase timeout setting in Cloud Run (max 3600s) |
| **Firebase connection failed** | Verify serviceAccountKey.json in container, check Firestore rules |
| **CORS errors** | Ensure Flask-CORS is initialized, check `@CORS(app)` |
| **Out of memory** | Increase Cloud Run memory allocation (512MB → 1GB) |

### Frontend Issues

| Issue | Solution |
|-------|----------|
| **Blank page** | Check browser console for errors, verify API URL is correct |
| **Predictions unavailable** | Verify current time is during meal hours, check backend health |
| **QR scan not working** | Grant camera permission, use Chrome/Firefox, ensure HTTPS |
| **Firebase connection failed** | Verify firebase_options.dart has correct config, check Firestore rules |

### ML Model Issues

| Issue | Solution |
|-------|----------|
| **No training data** | Check attendance collection has records, verify Firebase credentials |
| **Model prediction errors** | Retrain model, check for NaN values in data, verify capacity values |
| **Slow predictions** | Optimize model size, use Cloud TPU for large models, cache results |

---

## Maintenance Schedule

### Weekly
- Review Cloud Run logs for errors
- Monitor prediction accuracy
- Check for failed auto-training jobs

### Monthly
- Review and optimize costs
- Update dependencies
- Performance analysis
- User feedback review

### Quarterly
- Retrain ML model with accumulated data
- Security audit
- Capacity planning review
- Backup verification

---

## Rollback Procedure

If deployment has critical issues:

```bash
# Rollback Firebase Hosting to previous version
firebase hosting:channels:list
firebase hosting:channels:deploy production --expire 0

# Rollback Cloud Run to previous revision
gcloud run services update-traffic smartmess-backend --to-revisions=PREVIOUS_REVISION_ID=100

# Restore Firestore from backup
gcloud firestore restore backup-id
```

---

## Cost Optimization

- **Firebase:** Use Firestore pay-per-use (cheaper for low traffic)
- **Cloud Run:** Scales to zero when not in use
- **Storage:** Use Cloud Storage for large model files instead of inline
- **Bandwidth:** Use CDN caching for static assets
- **Monitoring:** Set budget alerts in Google Cloud Console

---

## Support & Resources

- [Google Cloud Documentation](https://cloud.google.com/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Flutter Web Deployment](https://flutter.dev/docs/deployment/web)
- [Project Documentation](../README.md)
- [QUERIES_AND_ANSWERS.md](../QUERIES_AND_ANSWERS.md) - FAQ for common issues

---

**Last Updated:** December 23, 2025  
**Version:** 2.0 (Updated for current project scope)

Deployment Guide Complete! 🚀

