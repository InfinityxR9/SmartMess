# SmartMess Project Setup Instructions

## Quick Start

### Prerequisites

- **Flutter**: 3.0+ ([Install Flutter](https://flutter.dev/docs/get-started/install))
- **Python**: 3.10+ ([Install Python](https://www.python.org/downloads/))
- **Node.js**: 16+ (for Firebase CLI)
- **Git**: Latest version
- **Google Account** (for Firebase)

### Installation Steps

#### 1. Frontend Setup

```bash
cd frontend

# Install Flutter dependencies
flutter pub get

# Build web assets
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Or build for web
flutter build web --release
```

#### 2. Backend Setup

```bash
cd backend

# Install Python dependencies
pip install -r requirements.txt

# Run locally
python main.py

# Server runs on: http://localhost:8080
```

#### 3. ML Model Setup

```bash
cd ml_model

# Install dependencies
pip install -r requirements.txt

# Train the model (requires Firebase credentials)
python train.py
```

## Configuration Files

### 1. Firebase Configuration

**File**: `frontend/lib/firebase_options.dart`

```dart
// Update with your Firebase credentials
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_API_KEY',
  appId: 'YOUR_APP_ID',
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'smartmess-project',
  authDomain: 'smartmess-project.firebaseapp.com',
  storageBucket: 'smartmess-project.appspot.com',
);
```

### 2. Backend API Endpoint

**File**: `frontend/lib/services/prediction_service.dart`

```dart
// Update with your Cloud Run URL
static const String baseUrl = 'https://your-cloud-run-url.run.app';
```

### 3. Maps API Key

**File**: `frontend/web/index.html`

```html
<!-- Replace with your Maps API key -->
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_MAPS_API_KEY"></script>
```

### 4. Backend Firebase Credentials

**File**: `backend/serviceAccountKey.json`

Download from Firebase Console → Project Settings → Service Accounts

## Directory Structure

```
SmartMess/
├── frontend/                          # Flutter Web Application
│   ├── lib/
│   │   ├── main.dart                  # App entry point
│   │   ├── models/                    # Data models
│   │   │   ├── mess_model.dart
│   │   │   ├── scan_model.dart
│   │   │   ├── menu_model.dart
│   │   │   ├── rating_model.dart
│   │   │   └── prediction_model.dart
│   │   ├── services/                  # Business logic
│   │   │   ├── auth_service.dart
│   │   │   ├── firestore_service.dart
│   │   │   └── prediction_service.dart
│   │   ├── screens/                   # UI Screens
│   │   │   ├── splash_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── mess_selection_screen.dart
│   │   │   ├── crowd_dashboard_screen.dart
│   │   │   ├── qr_scanner_screen.dart
│   │   │   ├── menu_screen.dart
│   │   │   ├── rating_screen.dart
│   │   │   └── maps_screen.dart
│   │   ├── widgets/                   # Reusable widgets
│   │   │   └── crowd_badge.dart
│   │   ├── providers/                 # State management
│   │   │   ├── auth_provider.dart
│   │   │   ├── mess_provider.dart
│   │   │   ├── crowd_provider.dart
│   │   │   ├── rating_provider.dart
│   │   │   └── prediction_provider.dart
│   │   ├── utils/                     # Utility functions
│   │   └── firebase_options.dart      # Firebase config
│   ├── web/                           # Web platform
│   │   ├── index.html
│   │   └── manifest.json
│   ├── pubspec.yaml                   # Dependencies
│   └── analysis_options.yaml          # Lint rules
│
├── backend/                            # Python Flask API
│   ├── main.py                        # Flask app & endpoints
│   ├── prediction_model.py            # Prediction logic
│   ├── requirements.txt               # Python dependencies
│   ├── Dockerfile                     # Container image
│   └── deploy.sh                      # Deployment script
│
├── ml_model/                           # TensorFlow Training
│   ├── crowd_predictor.py             # NN model
│   ├── train.py                       # Training pipeline
│   └── requirements.txt               # Python dependencies
│
└── docs/                               # Documentation
    ├── README.md                      # Project overview
    ├── SETUP.md                       # This file
    ├── FIREBASE_SETUP.md              # Firebase guide
    ├── DEPLOYMENT.md                  # Deployment guide
    └── API_DOCUMENTATION.md           # API reference
```

## Running Locally

### All Services Together

```bash
# Terminal 1: Frontend
cd frontend
flutter run -d chrome

# Terminal 2: Backend
cd backend
python main.py

# Terminal 3: Monitor logs
gcloud run logs read smartmess-api --limit=50
```

### Testing

```bash
# Test backend health
curl http://localhost:8080/health

# Test prediction endpoint
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"messId": "mess_1"}'
```

## Environment Variables

### Backend (.env file)

```
FIREBASE_PROJECT_ID=smartmess-project
FLASK_ENV=development
DEBUG=True
LOG_LEVEL=DEBUG
```

### Frontend (Dart defines)

```bash
flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY=your_key \
  --dart-define=API_ENDPOINT=http://localhost:8080
```

## Troubleshooting

### Flutter Web Issues

```
Error: "Unable to connect to Firebase"
→ Check firebase_options.dart credentials
→ Verify Anonymous Auth is enabled
→ Clear browser cache: Ctrl+Shift+Delete

Error: "QR Scanner not working"
→ mobile_scanner has limited web support
→ Use manual entry fallback button (already implemented)
```

### Backend Issues

```
Error: "ModuleNotFoundError: No module named 'tensorflow'"
→ pip install -r requirements.txt
→ Verify Python 3.10+ is being used: python --version

Error: "Firebase connection failed"
→ Check serviceAccountKey.json exists
→ Verify GOOGLE_APPLICATION_CREDENTIALS env var
```

### Firebase Issues

```
Error: "Permission denied" in Firestore
→ Check security rules allow authenticated access
→ Verify Anonymous Auth is enabled
→ Test with rule: allow read, write: if true; (dev only)

Error: "Collection not found"
→ Collections are auto-created on first write
→ Use Firebase console to manually create if needed
```

## Development Workflow

### 1. Make Changes

```bash
# Frontend changes
cd frontend
# Edit files in lib/

# Backend changes
cd backend
# Edit .py files
```

### 2. Test Locally

```bash
# Terminal 1: Frontend
flutter run -d chrome

# Terminal 2: Backend  
python main.py

# Manual testing
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"messId": "mess_1"}'
```

### 3. Deploy

```bash
# Frontend to Firebase Hosting
firebase deploy --only hosting

# Backend to Cloud Run
gcloud run deploy smartmess-api --source backend/
```

## Database Seeding

Create `frontend/scripts/seed.dart`:

```dart
// Seed Firestore with test data
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedDatabase() async {
  final db = FirebaseFirestore.instance;
  
  // Add messes
  await db.collection('messes').add({
    'name': 'Main Mess',
    'capacity': 100,
    'latitude': 28.5355,
    'longitude': 77.3910,
  });
}
```

Run with:
```bash
dart frontend/scripts/seed.dart
```

## Performance Optimization

### Frontend

```bash
# Enable web optimization
flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true
```

### Backend

```python
# Add caching
from flask_caching import Cache
cache = Cache(app, config={'CACHE_TYPE': 'redis'})

# Add rate limiting
from flask_limiter import Limiter
limiter = Limiter(app)
```

## Security Checklist

- [ ] Remove debug prints from production code
- [ ] Set Firestore security rules properly
- [ ] Use environment variables for secrets
- [ ] Enable HTTPS/TLS on all endpoints
- [ ] Implement rate limiting
- [ ] Add request validation
- [ ] Use API authentication tokens
- [ ] Sanitize user inputs
- [ ] Enable CORS only for trusted domains

## Next Steps

1. **Complete Firebase Setup**: Follow [FIREBASE_SETUP.md](FIREBASE_SETUP.md)
2. **Deploy Backend**: Follow [DEPLOYMENT.md](DEPLOYMENT.md)
3. **Train ML Model**: Run `python ml_model/train.py`
4. **Test All Features**: Use the demo flow
5. **Optimize Performance**: Implement caching and indexing

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [TensorFlow Guide](https://www.tensorflow.org/guide)
- [Cloud Run Guide](https://cloud.google.com/run/docs)

## Support

For issues:
1. Check this setup guide
2. Review troubleshooting section
3. Check logs: `gcloud run logs read smartmess-api`
4. Review documentation in `docs/` folder

---

**Setup Complete!** 🎉

Your SmartMess project is ready for development.
