# SmartMess - Quick Reference Guide

## 🚀 30-Second Start

```bash
# Frontend
cd frontend
flutter pub get
flutter run -d chrome

# Backend (new terminal)
cd backend
pip install -r requirements.txt
python main.py

# ML Training (new terminal)
cd ml_model
pip install -r requirements.txt
python train.py
```

## 📁 Important Files

| File | Purpose | Update Needed? |
|------|---------|---|
| `frontend/lib/firebase_options.dart` | Firebase credentials | ✅ YES |
| `frontend/lib/services/prediction_service.dart` | API endpoint URL | ✅ YES |
| `frontend/web/index.html` | Maps API key | ✅ YES |
| `backend/serviceAccountKey.json` | Firebase service account | ✅ YES |
| `backend/.env` | Environment variables | ⚠️ OPTIONAL |

## 🎯 Project Goals

### Primary
- ✅ QR scan → log crowd entry
- ✅ Real-time crowd dashboard
- ✅ AI predicts best time to eat

### Secondary
- ✅ 1-5 star ratings
- ✅ Real-time average
- ✅ Daily menu
- ✅ Location map

## 🏗️ Architecture

```
Flutter Web → Firebase ← Python Flask API
                ↓
            TensorFlow
          (Predictions)
```

## 📊 Database Schema

```
messes/
  ├── name, capacity, lat, lng

users/
  ├── homeMessId

scans/
  ├── uid, messId, ts (last 10 min = crowd)

menus/
  ├── messId, date, items[]

ratings/
  ├── uid, messId, score (1-5), comment

rating_summary/
  ├── messId → count, sum, avg
```

## 🔑 Key Classes

### Frontend Models
- `Mess` - Mess information
- `Scan` - Entry logs
- `Menu` / `MenuItem` - Daily menu
- `Rating` / `RatingSummary` - Feedback
- `PredictionResult` - AI predictions

### Frontend Providers
- `AuthProvider` - Firebase auth
- `MessProvider` - Mess selection
- `CrowdProvider` - Live crowd tracking
- `RatingProvider` - Feedback management
- `PredictionProvider` - AI predictions

### Frontend Screens
1. `SplashScreen` - Auto-login
2. `HomeScreen` - Navigation hub
3. `MessSelectionScreen` - Choose mess
4. `CrowdDashboardScreen` - Main dashboard (5 tabs)
5. `QRScannerScreen` - QR/manual entry
6. `MenuScreen` - Today's menu
7. `RatingScreen` - Feedback form
8. `MapsScreen` - Location info

### Backend API
- `GET /health` - Health check
- `POST /predict` - Get predictions
- `POST /train` - Retrain model

## 📋 Screens Overview

```
┌─────────────────────────────┐
│      Splash Screen          │
│   (Auto-authenticate)       │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│   Home / Mess Selection     │
│   (Select your mess)        │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────────┐
│  Crowd Dashboard (Main Screen)  │
│  ├─ Crowd Tab (Primary)         │
│  ├─ Menu Tab                    │
│  ├─ QR Scanner Tab              │
│  ├─ Rating Tab                  │
│  └─ Maps Tab                    │
└────────────────────────────────┘
```

## 🎨 UI Features

### Crowd Tab
- Current crowd count
- Capacity percentage
- Crowd level badge (Low/Med/High)
- Predicted best time slot
- Next 4 hours predictions

### QR Scanner Tab
- Camera button (web fallback)
- Manual entry confirmation
- Success message

### Menu Tab
- Today's date
- Food items list
- Item descriptions

### Rating Tab
- 5-star selector
- Comment input
- Submit button
- Real-time average display

### Maps Tab
- Location coordinates
- Capacity info
- Get directions button

## 🔗 API Endpoints

### Predict
```bash
POST /predict
Content-Type: application/json
{"messId": "mess_1"}

Response:
{
  "messId": "mess_1",
  "current_crowd": 45,
  "predictions": [
    {"time_slot": "2:00 PM", "crowd_percentage": 64.0}
  ],
  "best_slot": {...}
}
```

### Train
```bash
POST /train

Response:
{"message": "Model trained", "samples": 1500}
```

## 🔧 Configuration

### Firebase Options Update
```dart
// frontend/lib/firebase_options.dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_WEB_API_KEY',
  appId: 'YOUR_APP_ID',
  messagingSenderId: 'YOUR_SENDER_ID',
  projectId: 'smartmess-project',
  authDomain: 'smartmess-project.firebaseapp.com',
  storageBucket: 'smartmess-project.appspot.com',
);
```

### Prediction Service Update
```dart
// frontend/lib/services/prediction_service.dart
static const String baseUrl = 'https://your-cloud-run-url.run.app';
```

### Maps API Key Update
```html
<!-- frontend/web/index.html -->
<script src="https://maps.googleapis.com/maps/api/js?key=YOUR_MAPS_API_KEY"></script>
```

## 📦 Dependencies

### Frontend (pubspec.yaml)
- firebase_core, firebase_auth, cloud_firestore
- provider (state management)
- mobile_scanner (QR code)
- http (API calls)
- intl (date formatting)
- shimmer, lottie (animations)

### Backend (requirements.txt)
- Flask 2.3.2
- firebase-admin 6.0.0
- tensorflow 2.13.0
- numpy, pandas, scikit-learn

### ML Model (requirements.txt)
- tensorflow 2.13.0
- numpy, pandas, scikit-learn
- firebase-admin
- joblib

## 🚢 Deployment Commands

### Firebase Hosting
```bash
cd frontend
flutter build web --release
firebase deploy --only hosting
```

### Cloud Run
```bash
cd backend
gcloud run deploy smartmess-api --source .
```

### ML Model
```bash
cd ml_model
python train.py  # Creates .h5 and .pkl files
```

## 🧪 Testing

### Local Backend Test
```bash
curl http://localhost:8080/health
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"messId": "mess_1"}'
```

### Firebase Rules Test
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## ⚠️ Common Issues

| Issue | Solution |
|-------|----------|
| Firebase auth fails | Check `firebase_options.dart`, enable Anonymous Auth |
| Crowd doesn't update | Check Firestore real-time listeners, verify queries |
| Prediction API timeout | Verify Cloud Run is running, check endpoint URL |
| QR scan not working | Web has limited support, use manual entry |
| Model training fails | Install TensorFlow, check Python 3.10+, verify Firebase creds |

## 📊 Performance Tips

1. **Cache predictions** for 5 minutes
2. **Limit Firestore listeners** to 10 max
3. **Batch Firestore writes** with transactions
4. **Optimize queries** with indexes
5. **Use pagination** for large lists

## 🔐 Security Checklist

- [ ] Remove debug prints in production
- [ ] Set proper Firestore security rules
- [ ] Use environment variables for secrets
- [ ] Never commit `serviceAccountKey.json`
- [ ] Enable CORS only for trusted domains
- [ ] Validate all API inputs
- [ ] Use HTTPS/TLS for all endpoints

## 📚 Documentation Files

| File | Content |
|------|---------|
| [README.md](docs/README.md) | Full project overview |
| [SETUP.md](docs/SETUP.md) | Installation & configuration |
| [FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) | Firebase guide |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | Production deployment |
| [API_DOCUMENTATION.md](docs/API_DOCUMENTATION.md) | API reference |

## 🎯 Demo Checklist

- [ ] App loads without errors
- [ ] Anonymous auth works
- [ ] Can select a mess
- [ ] Crowd dashboard shows data
- [ ] Can log entry (QR/manual)
- [ ] Crowd count updates live
- [ ] Predictions display
- [ ] Can submit rating
- [ ] Average rating updates
- [ ] Menu displays
- [ ] Maps shows location

## 🚀 Next Steps

1. **Setup Firebase** - Follow FIREBASE_SETUP.md
2. **Update Credentials** - Fill in firebase_options.dart
3. **Test Frontend** - flutter run -d chrome
4. **Deploy Backend** - gcloud run deploy
5. **Update API URL** - In prediction_service.dart
6. **Train Model** - python train.py
7. **Deploy Frontend** - firebase deploy

## 💡 Pro Tips

1. Use VS Code for all development
2. Keep Firebase rules simple in dev, strict in prod
3. Test each feature independently first
4. Monitor Firestore usage to avoid quota
5. Use git commits frequently
6. Document any custom changes
7. Always backup Firestore data

## 📞 Quick Help

**Q: Where do I add Firebase credentials?**
A: `frontend/lib/firebase_options.dart`

**Q: How do I deploy the backend?**
A: `cd backend && gcloud run deploy smartmess-api --source .`

**Q: Where's the API endpoint?**
A: `frontend/lib/services/prediction_service.dart` (line ~8)

**Q: How do I train the ML model?**
A: `cd ml_model && python train.py`

**Q: Is this production-ready?**
A: Yes! Follow security best practices from DEPLOYMENT.md

---

**Status**: ✅ Ready for Deployment

**Last Updated**: December 20, 2024

**Version**: 1.0 (MVP)
