# SmartMess

> A mess crowd management system that combines a Flutter web UI, a Flask prediction API, and ML models to help students choose the best time to eat.

![Flutter](https://img.shields.io/badge/Flutter-Web-green)
![Firebase](https://img.shields.io/badge/Firebase-Firestore-red)
![Flask](https://img.shields.io/badge/Backend-Flask-blue)
![Python](https://img.shields.io/badge/Python-3.10%2B-yellow)
![TensorFlow](https://img.shields.io/badge/ML-TensorFlow-ff6f00)

## Table of Contents

- [What it does](#what-it-does)
- [Highlights](#highlights)
- [Tech Stack](#tech-stack)
- [System overview](#system-overview)
- [Meal windows](#meal-windows)
- [API](#api)
- [Quick start](#quick-start)
- [Reproduce the predictions flow](#reproduce-the-predictions-flow)
- [Optional ML training](#optional-ml-training)
- [Configuration](#configuration)
- [Project structure](#project-structure)
- [Team](#team)
- [Learning Resource](#learning-resources)

## What it does

SmartMess provides real-time mess crowd visibility, attendance tracking, and meal-aware predictions. The UI surfaces the best time slots to visit the mess, while managers can review attendance, menus, and feedback.

## Highlights

- 15-minute slot predictions with best-slot recommendations
- Student and manager dashboards
- QR-based attendance capture
- Menu and review tracking
- ML-backed predictions when models are available, fallback logic otherwise

## Tech Stack

| Component | Technology |
|-----------|-----------|
| ML Framework | TensorFlow 2.20.0 + Keras |
| Backend | Flask + Python 3.13 |
| Frontend | Flutter + Dart |
| Database | Firebase Firestore |
| Deployment | Docker-ready |

## System overview

Data flow (high level):

```
Flutter Web UI -> Flask API (/predict) -> ML model -> Firebase (auth, attendance, reviews, menus)
```

## Meal windows

- Breakfast: 07:30-09:30
- Lunch: 12:00-14:00
- Dinner: 19:30-21:30

Predictions are generated for the current meal window. Outside these windows, the backend returns an empty list.

## API

Base URL: `http://localhost:8080` by default.

### GET /health

Returns backend service status.

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
  "capacity": 120,
  "current_crowd": 60,
  "current_percentage": 50.0,
  "fallback": false,
  "mealType": "lunch",
  "messId": "alder",
  "predictions": [
    {
      "capacity": 120,
      "confidence": "low",
      "crowd_percentage": 40.0,
      "predicted_crowd": 48,
      "recommendation": "Moderate crowd",
      "time_24h": "13:30",
      "time_slot": "01:30 PM"
    },
    {
      "capacity": 120,
      "confidence": "low",
      "crowd_percentage": 46.0,
      "predicted_crowd": 55,
      "recommendation": "Moderate crowd",
      "time_24h": "13:45",
      "time_slot": "01:45 PM"
    }
  ],
  "source": "fallback",
  "timestamp": "2025-12-28T07:58:07.009597"
}
```

## Quick start

### Prerequisites

- Flutter 3.x (Dart >= 3.0)
- Python 3.10+
- Firebase project (configured in `frontend/lib/firebase_options.dart`)

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

## Reproduce the predictions flow

1. Start the backend and frontend.
2. Open the web app.
3. Navigate to the predictions section.
4. Confirm upcoming slots render for the active meal window.

## ML training

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
- Update CORS origins in `backend/main.py` when hosting the frontend.

## Project structure

```
SMARTMESS/
  backend/      Flask API
  frontend/     Flutter web app
  ml_model/     ML training and model files
  README.md     Project overview
```

## Team

- [Aryan Sisodiya]('https://github.com/InfinityxR')
-  [Daksh Rathi]('https://github.com/dakshrathi-india')

## Learning Resources

- [Flutter Documentation](https://flutter.dev)
- [Firebase Guides](https://firebase.google.com/docs)
- [TensorFlow Tutorials](https://www.tensorflow.org/tutorials)
<div align="center">

--- 

**Built with ❤️ for better mess management**
</div>
