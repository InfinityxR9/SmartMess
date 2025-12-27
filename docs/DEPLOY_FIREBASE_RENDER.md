# Deployment Guide: Firebase Hosting (Frontend) + Render (Backend)

This guide is written for beginners and walks through every step to deploy:
- Flutter web frontend to Firebase Hosting
- Flask backend to Render

You will deploy the backend first to get its URL, then build and deploy the frontend.

## 0) What you need (accounts + tools)

Accounts:
- Firebase account: https://console.firebase.google.com
- Render account: https://render.com
- GitHub account (Render deploys from a git repo)

Tools to install on your computer:
- Git: https://git-scm.com/downloads
- Flutter SDK: https://docs.flutter.dev/get-started/install
- Node.js (includes npm): https://nodejs.org

Verify installs (these should print versions):
```bash
git --version
flutter --version
node -v
npm -v
```

Install Firebase CLI:
```bash
npm install -g firebase-tools
firebase --version
```

## 1) Put the code on GitHub (required by Render)

If your code is already on GitHub, skip this section.

1. Create a new GitHub repository (empty).
2. In your local project folder:
```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

## 2) Create your Firebase project (once)

1. Go to Firebase Console: https://console.firebase.google.com
2. Click "Add project" and follow the wizard.
3. Create Firestore database:
   - In the left menu, open Firestore Database.
   - Click "Create database".
   - Choose "Start in test mode" for quick setup (lock this down later).
4. Enable Firebase Authentication (anonymous sign-in is used by this app):
   - Authentication -> Sign-in method -> enable "Anonymous".
5. Create a Web App in Firebase:
   - Project settings (gear icon) -> "Your apps" -> add Web app.
   - Register the app and note the config values.

## 3) Connect the Flutter app to your Firebase project

Option A (recommended): FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
Choose your Firebase project and select Web. This generates or updates:
`frontend/lib/firebase_options.dart`

Option B (manual): Replace values in `frontend/lib/firebase_options.dart`
with the config shown in the Firebase Console Web App page.

## 4) Deploy the backend to Render

### 4.1 Create a Render web service
1. In Render dashboard, click "New" -> "Web Service".
2. Connect your GitHub repo and select the branch.
3. Set "Root Directory" to `backend`.
4. Set Build Command:
```
pip install -r requirements.txt
```
5. Set Start Command:
```
gunicorn main:app
```
6. Choose a plan. If TensorFlow fails on free tier, use a larger plan.
7. Click "Create Web Service".

### 4.2 Add Firebase Admin credentials to Render
The backend uses Firebase Admin SDK and expects a service account JSON file.

1. In Firebase Console:
   - Project settings -> Service accounts
   - Click "Generate new private key" and download the JSON.
2. In Render service settings:
   - Environment -> "Secret Files"
   - Add a file named `serviceAccountKey.json`
   - Paste the entire JSON contents
   - Set the path to:
     `/opt/render/project/src/backend/serviceAccountKey.json`
3. (Optional but recommended) Add an environment variable:
   - Key: `GOOGLE_APPLICATION_CREDENTIALS`
   - Value: `/opt/render/project/src/backend/serviceAccountKey.json`

Important: Do not commit `serviceAccountKey.json` to git.

### 4.3 Lock CORS to your Firebase Hosting domain
Set the CORS allowlist in Render so only your frontend can call the backend:

Environment Variable:
- Key: `CORS_ORIGINS`
- Value: `https://YOUR-PROJECT.web.app,https://YOUR-PROJECT.firebaseapp.com`

If you have a custom domain, add it to the list.

### 4.4 Confirm the backend is running
After Render finishes deploying, open:
```
https://YOUR-SERVICE.onrender.com/health
```
You should see:
```
{"status":"healthy"}
```

## 5) Build the frontend with the backend URL

The frontend uses a compile-time variable for the backend URL.
Build with your Render URL:

```bash
cd frontend
flutter pub get
flutter build web --release --dart-define=SMARTMESS_BACKEND_URL=https://YOUR-SERVICE.onrender.com
```

This outputs the static site to: `frontend/build/web`

## 6) Deploy the frontend to Firebase Hosting

From the `frontend` directory:
```bash
firebase login
firebase init hosting
```

When prompted:
- Select your Firebase project
- Public directory: `build/web`
- Configure as single-page app: Yes
- Set up GitHub Actions: No (optional)

Deploy:
```bash
firebase deploy --only hosting
```

Firebase will print a Hosting URL like:
```
https://YOUR-PROJECT.web.app
```

## 7) End-to-end verification

1. Open the Firebase Hosting URL.
2. Use the app and confirm:
   - Predictions load (calls Render backend).
   - Firebase Auth works (anonymous sign-in).
   - Firestore reads/writes work.
   - QR scan works (HTTPS required, Firebase Hosting is HTTPS).

## 8) Updating later

- Backend changes:
  - Push to GitHub; Render redeploys automatically.
- Frontend changes or backend URL change:
  - Rebuild with the correct `--dart-define=SMARTMESS_BACKEND_URL=...`
  - Re-deploy with `firebase deploy --only hosting`

## Troubleshooting

If the backend build fails on Render:
- TensorFlow is heavy. Use a larger plan or upgrade instance size.
- Set a supported Python version in Render (Environment -> `PYTHON_VERSION`, e.g. `3.10.12`).

If Firestore is "unavailable":
- Check the service account file path on Render.
- Confirm the service account belongs to the correct Firebase project.

If the frontend cannot reach the backend:
- Confirm the `SMARTMESS_BACKEND_URL` used in `flutter build web`.
- Open `https://YOUR-SERVICE.onrender.com/health` in a browser.

If you get CORS errors:
- Update allowed origins in `backend/main.py` or keep `*` for now.

If QR scanning does not work:
- Use HTTPS (Firebase Hosting is HTTPS).
- Allow camera permissions in the browser.
