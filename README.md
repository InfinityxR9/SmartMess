# SmartMess - AI-Powered Mess Management System

![Flutter Web](https://img.shields.io/badge/Flutter-Web-blue.svg)
![Firebase](https://img.shields.io/badge/Firebase-Realtime%20DB-orange.svg)
![TensorFlow](https://img.shields.io/badge/TensorFlow-2.13-red.svg)
![Python](https://img.shields.io/badge/Python-3.10+-green.svg)

## 📱 Project Overview

**SmartMess** is a comprehensive mess management system for educational institutions that combines real-time crowd tracking, AI-powered predictions, and student feedback to optimize dining experiences.

### ✨ Key Features

- 🤖 **AI Crowd Prediction**: Machine learning-based predictions for best time to visit
- 📊 **Real-time Dashboard**: Live crowd metrics and capacity tracking
- 🔐 **QR Code Integration**: Quick entry logging with staff verification
- ⭐ **Feedback System**: Real-time rating aggregation and display
- 📋 **Menu Management**: Daily menu tracking and updates
- 🗺️ **Google Maps Integration**: Location-based mess information

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│            Flutter Web Frontend (UI Layer)               │
│        - Real-time dashboards                           │
│        - QR scanning / Manual entry                     │
│        - Feedback forms                                 │
└────────────┬──────────────────────┬────────────────────┘
             │                      │
             ├─────────────────┐    │
             │                 │    │
    ┌────────▼─────┐  ┌───────▼──────┐
    │   Firebase   │  │ Flask API    │
    │  Firestore   │  │ (Cloud Run)  │
    │  + Auth      │  │              │
    └──────────────┘  └───────┬──────┘
                              │
                      ┌───────▼──────┐
                      │ TensorFlow   │
                      │ Model        │
                      │ Predictions  │
                      └──────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Flutter 3.0+
- Python 3.10+
- Node.js 16+
- Firebase Account
- Google Cloud Account

### Installation

```bash
# Clone repository
git clone https://github.com/yourusername/smartmess.git
cd smartmess

# Frontend setup
cd frontend
flutter pub get
flutter run -d chrome

# Backend setup (new terminal)
cd backend
pip install -r requirements.txt
python main.py

# ML Model training (new terminal)
cd ml_model
pip install -r requirements.txt
python train.py
```

## 📚 Documentation

- **[Setup Guide](docs/SETUP.md)** - Complete setup instructions
- **[Firebase Setup](docs/FIREBASE_SETUP.md)** - Firebase configuration
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Deploy to production
- **[API Documentation](docs/API_DOCUMENTATION.md)** - API reference
- **[Project README](docs/README.md)** - Detailed project documentation

## 🎯 Project Structure

```
smartmess/
├── frontend/              # Flutter Web App
├── backend/              # Flask API
├── ml_model/             # TensorFlow Models
├── docs/                 # Documentation
└── README.md            # This file
```

## 🔧 Technology Stack

### Frontend
- **Flutter Web** - Cross-platform UI
- **Provider** - State management
- **Firebase** - Real-time database & auth

### Backend
- **Flask** - REST API framework
- **Firebase Admin SDK** - Database access
- **TensorFlow** - ML predictions

### Infrastructure
- **Firebase Hosting** - Frontend deployment
- **Cloud Run** - Backend deployment
- **Firestore** - Real-time database
- **Docker** - Container orchestration

## 📊 Firestore Schema

```
messes/
  ├── {messId}
  │   ├── name: String
  │   ├── capacity: Integer
  │   ├── latitude: Double
  │   └── longitude: Double

users/
  ├── {uid}
  │   └── homeMessId: String

scans/
  ├── {scanId}
  │   ├── uid: String
  │   ├── messId: String
  │   └── ts: Timestamp

ratings/
  ├── {ratingId}
  │   ├── uid: String
  │   ├── messId: String
  │   ├── score: Integer (1-5)
  │   └── ts: Timestamp

menus/
  ├── {menuId}
  │   ├── messId: String
  │   ├── date: Timestamp
  │   └── items: Array

rating_summary/
  ├── {messId}
  │   ├── count: Integer
  │   ├── sum: Integer
  │   └── avg: Double
```

## 🎬 Demo Flow

1. **Authentication** - Anonymous login
2. **Mess Selection** - Choose your mess
3. **Crowd Dashboard** - View live crowd and predictions
4. **Entry Logging** - QR scan or manual entry
5. **Menu Check** - Today's menu
6. **Feedback** - Rate and comment
7. **Map View** - Location information

## 🌐 API Endpoints

### Health Check
```bash
GET /health
```

### Crowd Prediction
```bash
POST /predict
Content-Type: application/json

{"messId": "mess_1"}
```

### Model Training
```bash
POST /train
```

## 🚢 Deployment

### Firebase Hosting (Frontend)
```bash
cd frontend
flutter build web --release
firebase deploy --only hosting
```

### Cloud Run (Backend)
```bash
cd backend
gcloud run deploy smartmess-api --source .
```

## 🧪 Testing

```bash
# Frontend tests
cd frontend
flutter test

# Backend tests
cd backend
pytest tests/

# API testing
curl http://localhost:8080/health
```

## 📈 Performance

- **Prediction Latency**: ~500ms
- **Real-time Updates**: <100ms
- **API Response Time**: ~200ms
- **Model Training**: ~2-5 minutes

## 🔒 Security Features

- Anonymous authentication (Firebase)
- Real-time security rules
- API rate limiting
- CORS protection
- Input validation
- Secure credentials management

## 🐛 Troubleshooting

### Issue: Firebase Connection Failed
```
Solution: Check firebase_options.dart configuration
          Verify Anonymous Auth is enabled
          Clear browser cache
```

### Issue: Prediction API Timeout
```
Solution: Verify Cloud Run service is running
          Check API endpoint URL
          Review Cloud Run logs
```

### Issue: TensorFlow Installation Error
```
Solution: pip install --upgrade pip
          pip install tensorflow==2.13.0
          Check Python version (3.10+)
```

See [SETUP.md](docs/SETUP.md) for more troubleshooting.

## 📱 Features in Development

- [ ] Push notifications for best times
- [ ] Admin dashboard for staff
- [ ] Loyalty points system
- [ ] Historical analytics
- [ ] Advanced ML models
- [ ] Mobile app (iOS/Android)

## 📊 Project Statistics

- **Frontend**: 2000+ lines of Dart
- **Backend**: 500+ lines of Python
- **ML Models**: 300+ lines of Python
- **Documentation**: 2000+ lines
- **Total Code**: 5000+ lines

## 👥 Team

- **Frontend Developer**: Flutter Web specialist
- **Backend Developer**: Python/Flask expertise
- **ML Engineer**: TensorFlow proficiency

## 📝 License

MIT License - See LICENSE file for details

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/AmazingFeature`
3. Commit changes: `git commit -m 'Add AmazingFeature'`
4. Push to branch: `git push origin feature/AmazingFeature`
5. Open Pull Request

## 📞 Support & Contact

- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Email**: support@smartmess.dev

## 🎓 Learning Resources

- [Flutter Documentation](https://flutter.dev)
- [Firebase Guides](https://firebase.google.com/docs)
- [TensorFlow Tutorials](https://www.tensorflow.org/tutorials)
- [Cloud Run Docs](https://cloud.google.com/run/docs)

## 🙏 Acknowledgments

- Flutter and Firebase communities
- TensorFlow developers
- Google Cloud Platform support

---

<div align="center">

**Built with ❤️ for better mess management**

[View Documentation](docs/README.md) • [Setup Guide](docs/SETUP.md) • [API Docs](docs/API_DOCUMENTATION.md)

</div>
