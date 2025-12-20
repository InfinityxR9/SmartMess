# SmartMess - Getting Started Checklist

## ✅ Pre-Setup Requirements

- [ ] Flutter SDK installed (3.0+)
  ```bash
  flutter --version
  ```

- [ ] Python installed (3.10+)
  ```bash
  python --version
  ```

- [ ] Node.js installed (16+) - for Firebase CLI
  ```bash
  node --version
  ```

- [ ] Git installed
  ```bash
  git --version
  ```

- [ ] Google account created
- [ ] Google Cloud account with billing enabled
- [ ] VS Code or preferred editor
- [ ] Google Chrome or Firefox browser

---

## 📋 Phase 1: Project Setup (30 minutes)

### 1.1 Create Firebase Project
- [ ] Go to https://console.firebase.google.com
- [ ] Click "Add project"
- [ ] Name: `smartmess-project`
- [ ] Enable Google Analytics (optional)
- [ ] Click "Create project"
- [ ] Wait for project creation to complete

### 1.2 Create Web App
- [ ] In Firebase Console, click Web icon `</>`
- [ ] App name: `SmartMess Web`
- [ ] Check "Also set up Firebase Hosting"
- [ ] Click "Register app"
- [ ] **Save the configuration** (you'll need this)
- [ ] Copy config values to notepad

### 1.3 Enable Authentication
- [ ] Go to Firebase → Authentication
- [ ] Click "Get Started"
- [ ] Select "Anonymous"
- [ ] Toggle "Enable"
- [ ] Click "Save"

### 1.4 Create Firestore Database
- [ ] Go to Firebase → Firestore Database
- [ ] Click "Create database"
- [ ] Choose region: `us-central1` (or closest to you)
- [ ] Choose "Start in test mode"
- [ ] Click "Create"
- [ ] Wait for database creation

### 1.5 Set Firestore Security Rules
- [ ] Go to Firestore → Rules tab
- [ ] Replace with provided rules from [FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)
- [ ] Click "Publish"

---

## 💻 Phase 2: Frontend Setup (20 minutes)

### 2.1 Clone/Open Project
- [ ] Navigate to project folder:
  ```bash
  cd d:\CodePlayground\Flutter\Projects\SmartMess\code\frontend
  ```

### 2.2 Install Dependencies
- [ ] Run:
  ```bash
  flutter pub get
  ```
- [ ] Wait for dependencies to download

### 2.3 Update Firebase Options
- [ ] Open `lib/firebase_options.dart`
- [ ] Replace placeholders with your Firebase config:
  - `YOUR_WEB_API_KEY` → From Firebase console
  - `YOUR_APP_ID` → From Firebase console
  - `YOUR_MESSAGING_SENDER_ID` → From Firebase console
- [ ] Save file

### 2.4 Test Locally
- [ ] Run:
  ```bash
  flutter run -d chrome
  ```
- [ ] Wait for build to complete
- [ ] Verify app loads in Chrome
- [ ] Check for errors in console
- [ ] You should see: Splash → Home/Mess Selection
- [ ] Close browser (Ctrl+C in terminal)

---

## 🔧 Phase 3: Backend Setup (15 minutes)

### 3.1 Navigate to Backend
- [ ] Open new terminal
- [ ] Navigate to:
  ```bash
  cd d:\CodePlayground\Flutter\Projects\SmartMess\code\backend
  ```

### 3.2 Create Virtual Environment
- [ ] Create venv:
  ```bash
  python -m venv venv
  ```
- [ ] Activate venv:
  ```bash
  # Windows
  venv\Scripts\activate
  # Mac/Linux
  source venv/bin/activate
  ```

### 3.3 Install Dependencies
- [ ] Run:
  ```bash
  pip install -r requirements.txt
  ```
- [ ] Wait for installation to complete

### 3.4 Test Backend Locally
- [ ] Run:
  ```bash
  python main.py
  ```
- [ ] You should see: "Running on http://127.0.0.1:8080"
- [ ] In another terminal, test:
  ```bash
  curl http://localhost:8080/health
  ```
- [ ] You should see: `{"status": "healthy"}`
- [ ] Stop server (Ctrl+C)

---

## 🤖 Phase 4: ML Model Setup (10 minutes)

### 4.1 Navigate to ML Folder
- [ ] Open new terminal
- [ ] Navigate to:
  ```bash
  cd d:\CodePlayground\Flutter\Projects\SmartMess\code\ml_model
  ```

### 4.2 Create Virtual Environment
- [ ] Create venv:
  ```bash
  python -m venv venv
  ```
- [ ] Activate venv:
  ```bash
  # Windows
  venv\Scripts\activate
  # Mac/Linux
  source venv/bin/activate
  ```

### 4.3 Install Dependencies
- [ ] Run:
  ```bash
  pip install -r requirements.txt
  ```
- [ ] This installs TensorFlow (may take 5-10 minutes)

### 4.4 (Optional) Train Model
- [ ] After Firestore has scan data, run:
  ```bash
  python train.py
  ```
- [ ] Model will be saved as `mess_crowd_model.h5`

---

## 🎬 Phase 5: Feature Testing (30 minutes)

### 5.1 Start All Services
- [ ] Terminal 1 - Frontend:
  ```bash
  cd d:\CodePlayground\Flutter\Projects\SmartMess\code\frontend
  flutter run -d chrome
  ```

- [ ] Terminal 2 - Backend:
  ```bash
  cd d:\CodePlayground\Flutter\Projects\SmartMess\code\backend
  python main.py
  ```

### 5.2 Test in App

#### Splash & Auth
- [ ] App loads splash screen
- [ ] Auto-logs in with anonymous auth
- [ ] Navigates to home screen
- [ ] No errors in console

#### Mess Selection
- [ ] See "No messes available" message (expected, no data yet)
- [ ] Can go back (navigation works)

#### Add Sample Data to Firestore
- [ ] Go to Firebase Console → Firestore
- [ ] Create document in `messes` collection:
  ```json
  {
    "name": "Main Mess",
    "capacity": 100,
    "latitude": 28.5355,
    "longitude": 77.3910
  }
  ```
- [ ] Add another document for testing

#### Test Mess Selection Again
- [ ] Refresh app or rerun `flutter run -d chrome`
- [ ] Now see messes in list
- [ ] Click on a mess
- [ ] Navigate to crowd dashboard

#### Test Crowd Dashboard
- [ ] See current crowd (should be 0 initially)
- [ ] See "0%" capacity
- [ ] See "No predictions" (API not deployed yet)
- [ ] All 5 tabs are accessible

#### Test QR Scanner
- [ ] Go to QR Scanner tab
- [ ] Click "Mark Entry Manually"
- [ ] Confirm you entered the mess
- [ ] See success message
- [ ] Go back to Crowd tab
- [ ] Crowd count should be 1 now

#### Test Menu
- [ ] Go to Menu tab
- [ ] Add menu to Firestore:
  ```json
  {
    "messId": "MESS_DOC_ID",
    "date": Timestamp.now(),
    "items": [
      {"name": "Rice", "description": "Basmati Rice"},
      {"name": "Dal", "description": "Lentil curry"}
    ]
  }
  ```
- [ ] Refresh app
- [ ] Menu tab should show items

#### Test Rating
- [ ] Go to Rating tab
- [ ] Click on 5 stars
- [ ] See "Excellent" label
- [ ] Add a comment (optional)
- [ ] Click "Submit Rating"
- [ ] See success message
- [ ] Scroll down
- [ ] See average rating displayed
- [ ] Submit more ratings from different "users" (new browser tab in incognito)
- [ ] Average should update

#### Test Maps
- [ ] Go to Maps tab
- [ ] See mess location details
- [ ] See coordinates displayed
- [ ] Click "Get Directions"

---

## 🚀 Phase 6: Cloud Deployment (30 minutes)

### 6.1 Deploy Frontend to Firebase Hosting

- [ ] Install Firebase CLI:
  ```bash
  npm install -g firebase-tools
  ```

- [ ] Login:
  ```bash
  firebase login
  ```

- [ ] Navigate to frontend:
  ```bash
  cd d:\CodePlayground\Flutter\Projects\SmartMess\code\frontend
  ```

- [ ] Build web:
  ```bash
  flutter build web --release
  ```

- [ ] Deploy:
  ```bash
  firebase deploy --only hosting
  ```

- [ ] Note the hosting URL displayed
- [ ] Test in browser: `https://your-project.web.app`

### 6.2 Deploy Backend to Cloud Run

- [ ] Install Google Cloud CLI (if not done)
- [ ] Initialize:
  ```bash
  gcloud init
  ```

- [ ] Navigate to backend:
  ```bash
  cd d:\CodePlayground\Flutter\Projects\SmartMess\code\backend
  ```

- [ ] Deploy:
  ```bash
  gcloud run deploy smartmess-api --source .
  ```

- [ ] Choose region: `us-central1`
- [ ] Allow unauthenticated: `Y`
- [ ] Note the service URL

### 6.3 Update Frontend with API Endpoint

- [ ] Copy Cloud Run URL
- [ ] Update `frontend/lib/services/prediction_service.dart`:
  ```dart
  static const String baseUrl = 'https://YOUR_CLOUD_RUN_URL.run.app';
  ```

- [ ] Rebuild and redeploy:
  ```bash
  cd frontend
  flutter build web --release
  firebase deploy --only hosting
  ```

---

## 📊 Phase 7: End-to-End Testing

- [ ] [ ] Open deployed Firebase Hosting URL
- [ ] [ ] Test mess selection
- [ ] [ ] Test QR/manual entry
- [ ] [ ] Watch crowd count update live
- [ ] [ ] Test predictions (API should now work)
- [ ] [ ] See best slot highlighted
- [ ] [ ] Test menu display
- [ ] [ ] Test rating submission
- [ ] [ ] See rating average update
- [ ] [ ] Test maps/location

---

## 🔒 Phase 8: Production Hardening

- [ ] [ ] Update Firestore security rules for production
- [ ] [ ] Remove debug logs from code
- [ ] [ ] Enable HTTPS everywhere
- [ ] [ ] Set up monitoring (Cloud Logging)
- [ ] [ ] Configure error tracking
- [ ] [ ] Test on multiple devices/browsers
- [ ] [ ] Load test the API
- [ ] [ ] Backup Firestore data regularly
- [ ] [ ] Document deployment steps
- [ ] [ ] Create runbook for common issues

---

## 📝 Important Notes

### Credentials
- [ ] Save Firebase config in secure location
- [ ] Download `serviceAccountKey.json` from Firebase
- [ ] Never commit credentials to git
- [ ] Use environment variables in production

### Configuration
- [ ] Update `firebase_options.dart` with real credentials
- [ ] Update `prediction_service.dart` with Cloud Run URL
- [ ] Update `web/index.html` with Maps API key
- [ ] Add Firebase Hosting domain to CORS whitelist

### Testing
- [ ] Test on Chrome, Firefox, Safari, Edge
- [ ] Test on mobile browsers
- [ ] Test with slow internet (DevTools)
- [ ] Test error scenarios (Firebase down, API timeout)
- [ ] Load test with multiple users

### Monitoring
- [ ] Set up Cloud Logging alerts
- [ ] Monitor Firestore quota usage
- [ ] Monitor Cloud Run costs
- [ ] Set up uptime monitoring
- [ ] Track API response times

---

## 🎯 Success Criteria

You'll know everything is working when:

✅ Firebase project created and configured
✅ Flutter app runs locally without errors
✅ Backend runs locally and responds to API calls
✅ App authenticates with Firebase
✅ Mess selection works
✅ QR/manual entry logs to Firestore
✅ Crowd count updates in real-time
✅ Predictions display from API
✅ Ratings submit and aggregate correctly
✅ Menu displays today's items
✅ Maps shows location
✅ Frontend deployed to Firebase Hosting
✅ Backend deployed to Cloud Run
✅ App is accessible via public URL
✅ All features work in production

---

## 🆘 If Something Goes Wrong

1. **Check the [SETUP.md](docs/SETUP.md)** for detailed instructions
2. **Review [FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)** for Firebase issues
3. **Check [DEPLOYMENT.md](docs/DEPLOYMENT.md)** for deployment problems
4. **Read [API_DOCUMENTATION.md](docs/API_DOCUMENTATION.md)** for API issues
5. **Check browser console** for JavaScript errors
6. **Check terminal output** for backend errors
7. **Check Cloud Logging** for deployment issues

---

## 📞 Quick Reference

| Command | Purpose |
|---------|---------|
| `flutter run -d chrome` | Run frontend locally |
| `python main.py` | Run backend locally |
| `python train.py` | Train ML model |
| `firebase deploy` | Deploy to Firebase |
| `gcloud run deploy` | Deploy to Cloud Run |
| `curl http://localhost:8080/health` | Test backend |

---

## 🎉 You're Ready!

Once you complete this checklist, SmartMess will be:
- ✅ Fully operational locally
- ✅ Deployed to production
- ✅ Integrated with Firebase
- ✅ Running predictions via ML
- ✅ Handling real-time updates
- ✅ Ready for actual users

**Estimated Total Time**: 2-3 hours (depending on experience)

---

**Good luck! 🚀**

For questions, refer to the comprehensive documentation in the `docs/` folder.
