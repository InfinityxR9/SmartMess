# SmartMess

SmartMess is a mess crowd management system that combines a Flutter web front end, a Flask prediction API, and optional ML models to help students and managers choose the best time to eat.

**Version**: 2.0.0  
**Status**: Production Ready ✅  
**Last Updated**: 28-12-2025

## Overview

SmartMess is an intelligent mess management system featuring:
- 🧠 TensorFlow-based crowd prediction
- 🔐 Mess-specific data isolation
- 📊 Real-time attendance tracking
- 🚀 Flutter mobile frontend
- ☁️ Firebase backend
- 📈 ML-powered predictions

## Highlights

- Meal-aware crowd predictions (15-minute slots)
- Real-time crowd dashboards and attendance tracking
- QR-based check-ins and feedback collection
- Manager and student portals
- Firebase-backed data storage (auth, attendance, reviews, menus)

## Core Features

### 🧠 TensorFlow Crowd Prediction

- **Mess-Specific Models**: Each mess (alder, oak, etc.) has its own trained model
- **15-Minute Predictions**: Predicts crowd for upcoming 15-minute slots
- **Meal-Time Awareness**: Breakfast (7:30-9:30), Lunch (11:00-15:00), Dinner (18:00-22:00)
- **Confidence Scoring**: Returns prediction confidence levels
- **Recommendations**: Good time, Moderate, or Avoid

### 🔐 Data Isolation

- No cross-contamination between messes
- Each mess model trained on its own data only
- Complete privacy and isolation

### 📱 QR Code Integration: 
- Quick entry logging with staff verification
### ⭐ Feedback System: 
- Real-time rating aggregation and display
### 📋 Menu Management: 
- Daily menu tracking and updates

## Architecture

- frontend/ - Flutter web UI
- backend/ - Flask API for predictions and health checks
- ml_model/ - Training scripts and model artifacts
- Firebase - Auth and Firestore for app data

## Technologies

| Component | Technology |
|-----------|-----------|
| ML Framework | TensorFlow 2.20.0 + Keras |
| Backend | Flask + Python 3.13 |
| Frontend | Flutter + Dart |
| Database | Firebase Firestore |
| Deployment | Docker-ready |

## API

Base URL: `http://localhost:8080` by default.

### GET /health

Returns service status.

### POST /predict

Request body:

```json
{
  "messId": "alder",
  "mealType": "lunch",
  "capacity": 120
}
```

Response (shape):

```json
{
  "messId": "alder",
  "mealType": "lunch",
  "capacity": 120,
  "predictions": [
    {
      "time_slot": "12:15 PM",
      "time_24h": "12:15",
      "predicted_crowd": 40,
      "crowd_percentage": 33.3,
      "confidence": "low",
      "recommendation": "Good time"
    }
  ],
  "timestamp": "2025-01-01T12:00:00Z"
}
```

## Meal Windows

- Breakfast: 07:30-09:30
- Lunch: 12:00-14:00
- Dinner: 19:30-21:30

## Local Development

### Prerequisites

- Flutter 3.x (Dart >= 3.0)
- Python 3.10+
- Firebase project for auth and Firestore (already configured in `frontend/lib/firebase_options.dart`)

### 1) Run the backend API

```bash
cd backend
python -m venv .venv
.\.venv\Scripts\activate  # Windows
pip install -r requirements.txt
python main.py
```

The API runs on `http://localhost:8080`.

### 2) Run the Flutter web app

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=SMARTMESS_BACKEND_URL=http://localhost:8080
```

### 3) Verify the prediction endpoint

```bash
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d "{\"messId\":\"alder\",\"mealType\":\"lunch\",\"capacity\":120}"
```

### 4) Reproduce the UI flow

- Open the web app.
- Navigate to the predictions section.
- Confirm upcoming slot predictions render for the current meal.

## Optional: Train ML Models

If you want ML-backed predictions instead of the fallback logic:

```bash
cd ml_model
python train_tensorflow.py alder
python train_tensorflow.py oak
```

The backend automatically uses ML predictions when models are available. If not, it falls back to meal-aware heuristics.

## Configuration

### Frontend

- `SMARTMESS_BACKEND_URL` sets the prediction API base URL.

Example (hosted frontend):

```bash
flutter run -d chrome --dart-define=SMARTMESS_BACKEND_URL=https://your-api.example.com
```

### Backend

- `PORT` sets the HTTP port (default: 8080).

## Project Structure

```
SMARTMESS/
  backend/      Flask API
  frontend/     Flutter web app
  ml_model/     ML training and model files
  README.md     Project overview
```

## Troubleshooting

- Mixed content errors: hosted web apps must use an https backend URL.
- Empty predictions: verify the server time and `mealType` match meal windows.
- CORS issues: ensure the frontend origin is in the backend CORS allowlist.

## Notes

- Meal windows are defined in `backend/main.py`.
- Predictions are returned in 15-minute slots.

## 👥 Team

- [Aryan Sisodiya]('https://github.com/InfinityxR')
-  [Daksh Rathi]('https://github.com/dakshrathi-india')

## 🎓 Learning Resources

- [Flutter Documentation](https://flutter.dev)
- [Firebase Guides](https://firebase.google.com/docs)
- [TensorFlow Tutorials](https://www.tensorflow.org/tutorials)

---
<div align="center">

**Built with ❤️ for better mess management**
</div>