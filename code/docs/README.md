# SmartMess - Mess Management System

A comprehensive Flutter Web application for managing mess crowd prediction and student feedback with AI-powered insights.

## Project Overview

**SmartMess** is a three-tier system consisting of:

1. **Flutter Web Frontend** - Real-time crowd tracking and predictions
2. **Firebase Backend** - Real-time database and authentication
3. **Python ML Backend** - TensorFlow-based crowd prediction API

### Primary Features

- **Crowd Prediction**: AI-powered predictions for best time to visit the mess
- **QR Code Scanning**: Quick mess entry logging (or manual fallback)
- **Real-time Dashboard**: Live crowd levels and capacity tracking
- **Feedback System**: 1-5 star ratings with real-time average calculation
- **Menu Display**: Daily menu management
- **Location Map**: Google Maps integration for mess location

## Technology Stack

### Frontend
- **Framework**: Flutter Web
- **State Management**: Provider
- **Database**: Firebase Cloud Firestore
- **Authentication**: Firebase Anonymous Auth
- **API Calls**: HTTP
- **QR Scanning**: mobile_scanner (for mobile support)

### Backend
- **Framework**: Flask (Python)
- **Deployment**: Google Cloud Run
- **Database**: Firebase Firestore
- **ML Framework**: TensorFlow 2.13
- **Data Processing**: Pandas, NumPy, Scikit-learn

### Infrastructure
- **Authentication**: Firebase Auth
- **Database**: Cloud Firestore
- **Hosting**: Firebase Hosting (Frontend) + Cloud Run (Backend)
- **Containerization**: Docker

## Project Structure

```
SmartMess/
├── frontend/                 # Flutter Web App
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/          # Data models
│   │   ├── services/        # Firebase & API services
│   │   ├── screens/         # UI screens
│   │   ├── widgets/         # Reusable widgets
│   │   ├── providers/       # State management
│   │   └── utils/           # Utilities
│   ├── web/                 # Web platform files
│   └── pubspec.yaml
│
├── backend/                 # Python Flask API
│   ├── main.py             # Flask app & endpoints
│   ├── prediction_model.py # Prediction logic
│   ├── requirements.txt
│   ├── Dockerfile
│   └── deploy.sh
│
└── ml_model/               # TensorFlow Training
    ├── crowd_predictor.py  # Neural network model
    ├── train.py           # Training pipeline
    └── requirements.txt
```

## Firebase Firestore Schema

### Collections

```
messes/
  ├── {messId}
  │   ├── name: String
  │   ├── capacity: Integer
  │   ├── latitude: Double
  │   ├── longitude: Double
  │   └── imageUrl: String (optional)

users/
  ├── {uid}
  │   └── homeMessId: String

scans/
  ├── {scanId}
  │   ├── uid: String
  │   ├── messId: String
  │   └── ts: Timestamp

menus/
  ├── {menuId}
  │   ├── messId: String
  │   ├── date: Timestamp
  │   └── items: Array<{name, description}>

ratings/
  ├── {ratingId}
  │   ├── uid: String
  │   ├── messId: String
  │   ├── score: Integer (1-5)
  │   ├── comment: String
  │   └── ts: Timestamp

rating_summary/
  ├── {messId}
  │   ├── messId: String
  │   ├── count: Integer
  │   ├── sum: Integer
  │   └── avg: Double
```

## Setup Instructions

### 1. Firebase Setup

```bash
# Create Firebase project
# 1. Go to https://console.firebase.google.com
# 2. Create a new project named "smartmess-project"
# 3. Enable:
#    - Anonymous Authentication
#    - Cloud Firestore
#    - Cloud Storage (optional)

# Get Firebase Config
# 1. Go to Project Settings
# 2. Create Web app
# 3. Copy config values to frontend/lib/firebase_options.dart
```

### 2. Frontend Setup

```bash
cd frontend

# Install dependencies
flutter pub get

# Generate build files for web
flutter pub get
flutter web build

# Run on web
flutter run -d chrome
```

### 3. Backend Setup

```bash
cd backend

# Install Python dependencies
pip install -r requirements.txt

# Set Firebase credentials
# Place serviceAccountKey.json in this directory

# Run locally
python main.py

# Or with Docker
docker build -t smartmess-backend .
docker run -p 8080:8080 smartmess-backend
```

### 4. ML Model Training

```bash
cd ml_model

# Install dependencies
pip install -r requirements.txt

# Train model with Firebase data
python train.py

# This creates:
# - mess_crowd_model.h5 (model weights)
# - mess_crowd_model_scaler.pkl (feature scaler)
```

## API Endpoints

### Prediction API

**Base URL**: `https://your-cloud-run-url.run.app`

#### POST /predict
- **Purpose**: Get crowd prediction for a mess
- **Input**: `{"messId": "mess_id"}`
- **Response**:
```json
{
  "messId": "mess_1",
  "current_crowd": 45,
  "predictions": [
    {
      "time_slot": "02:00 PM",
      "predicted_crowd": 32,
      "crowd_percentage": 64.0
    }
  ],
  "best_slot": {
    "time_slot": "03:00 PM",
    "predicted_crowd": 25,
    "crowd_percentage": 50.0
  }
}
```

#### POST /train
- **Purpose**: Retrain model with latest data
- **Response**: `{"message": "Model trained successfully", "samples": 1500}`

## Deployment

### Frontend (Firebase Hosting)

```bash
cd frontend

# Build for web
flutter build web

# Deploy to Firebase
firebase deploy --only hosting
```

### Backend (Cloud Run)

```bash
cd backend

# Deploy to Cloud Run
gcloud run deploy smartmess-api \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

## Features in Detail

### 1. Crowd Prediction
- Analyzes 10-minute scan history
- Uses TensorFlow model for next 4-hour predictions
- Displays current crowd level with percentage
- Color-coded indicators (Low/Medium/High)

### 2. QR Code Scanning
- Mobile support via `mobile_scanner`
- Web fallback: Manual "Mark Entry" button
- Logs entry to Firestore with timestamp

### 3. Real-time Dashboard
- Live crowd count updates
- Current capacity utilization
- Predicted best time to visit
- Upcoming slot predictions

### 4. Feedback System
- 5-star rating interface
- Optional comments
- Real-time average calculation using Firestore transactions
- Displays total ratings count

### 5. Menu Management
- Daily menu display
- Supports multiple food items
- Item descriptions

### 6. Maps Integration
- Shows mess location coordinates
- Get directions button (opens maps app)
- Displays capacity and location info

## Configuration

### Firebase Options

Update [frontend/lib/firebase_options.dart](frontend/lib/firebase_options.dart):

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_API_KEY',
  appId: 'YOUR_APP_ID',
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'smartmess-project',
  authDomain: 'smartmess-project.firebaseapp.com',
  storageBucket: 'smartmess-project.appspot.com',
);
```

### Prediction API Endpoint

Update [frontend/lib/services/prediction_service.dart](frontend/lib/services/prediction_service.dart):

```dart
static const String baseUrl = 'https://your-cloud-run-url.run.app';
```

## Demo Flow (2 minutes)

1. **Splash Screen** → Authenticate user
2. **Mess Selection** → Choose your mess
3. **Crowd Dashboard** → View current crowd and predictions
4. **QR Scanner** → Log entry (manual or QR)
5. **Crowd Updates** → See real-time update
6. **Menu** → Check today's menu
7. **Rating** → Submit feedback (1-5 stars)
8. **Average Rating** → See collective feedback
9. **Maps** → View mess location

## Development Notes

### Important TODOs

1. **QR Scanner Web Support**
   - `mobile_scanner` has limited web support
   - Currently uses fallback manual entry button
   - Can be enhanced with `qr_flutter` for QR code display

2. **Maps Integration**
   - Replace placeholder with actual Google Maps
   - Requires `google_maps_flutter_web` configuration
   - Add Maps API key to web/index.html

3. **Real TensorFlow Model**
   - Current backend uses simple time-based prediction
   - Deploy actual trained model via TensorFlow Serving
   - Replace with proper model weights after training

4. **Notification System**
   - Add Firebase Cloud Messaging for predictions
   - Notify users when "best time" is approaching

5. **Admin Panel**
   - Create admin interface for:
     - Menu management
     - QR code generation
     - Analytics dashboard

## Testing

### Manual Testing Checklist

- [ ] Anonymous authentication works
- [ ] Mess selection persists selection
- [ ] Crowd count updates in real-time
- [ ] QR scanner fallback works
- [ ] Ratings submit successfully
- [ ] Average rating updates in real-time
- [ ] Menu displays correctly
- [ ] Maps page shows location
- [ ] Predictions display with best slot highlighted

### Performance Considerations

- Firestore real-time listeners limited to 10 per app
- Optimize queries with proper indexing
- Consider caching predictions (5-minute TTL)
- Batch rating updates with transactions

## Troubleshooting

### Firebase Connection Issues
```
Error: PlatformException(error, Failed to get document, null)
→ Check Firestore rules and authentication
```

### Prediction API Not Responding
```
Error: timeout
→ Verify Cloud Run deployment and CORS settings
```

### Model Training Issues
```
Error: No module named tensorflow
→ Install: pip install tensorflow==2.13.0
```

## Future Enhancements

1. **Analytics Dashboard** - Mess authorities view
2. **Notification System** - Smart alerts for best times
3. **Mobile App** - Native iOS/Android versions
4. **Loyalty Program** - Points for ratings/feedback
5. **Staff Management** - Mess staff features
6. **Advanced ML** - Multi-day patterns, holidays, special events

## Team Requirements

- **Frontend Developer**: Flutter Web, State Management
- **Backend Developer**: Flask/Python, Cloud deployment
- **ML Engineer**: TensorFlow model training and optimization

## License

MIT License - Feel free to use for educational purposes

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Firebase Firestore rules
3. Verify API endpoint configuration
4. Check browser console for errors

---

**Built with** ❤️ for Smart Mess Management
