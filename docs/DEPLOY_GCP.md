# SmartMess Production Deployment (GCP Free Tier)

This guide deploys:
- Backend API (Flask + TensorFlow) to Cloud Run
- Frontend (Flutter web) to Firebase Hosting
- Firestore/Auth on Firebase (same GCP project)

It also includes production notes for fonts/icons and asset paths.

## 1) Prereqs

- Google Cloud project (free tier)
- Firebase project linked to the same GCP project
- Installed tools:
  - `gcloud` CLI
  - `firebase` CLI
  - Flutter SDK

Enable APIs:
```
gcloud services enable run.googleapis.com cloudbuild.googleapis.com firestore.googleapis.com
```

## 2) Firestore + Auth

- In Firebase Console, create Firestore in **Native** mode.
- Configure Authentication providers you use.

## 3) Backend (Cloud Run)

### 3.1 Service account (recommended)

Create a dedicated service account with Firestore access:
```
gcloud iam service-accounts create smartmess-backend \
  --display-name "SmartMess Backend"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:smartmess-backend@$PROJECT_ID.iam.gserviceaccount.com" \
  --role "roles/datastore.user"
```

### 3.2 Build the container (IMPORTANT: build context is repo root)

The backend Dockerfile expects repo-root context so it can copy `ml_model`.
```
# From repo root
PROJECT_ID=<your-project-id>

gcloud builds submit \
  --tag gcr.io/$PROJECT_ID/smartmess-backend \
  -f backend/Dockerfile \
  .
```

### 3.3 Deploy to Cloud Run
```
gcloud run deploy smartmess-backend \
  --image gcr.io/$PROJECT_ID/smartmess-backend \
  --region us-central1 \
  --allow-unauthenticated \
  --service-account smartmess-backend@$PROJECT_ID.iam.gserviceaccount.com \
  --memory 2Gi \
  --cpu 1
```

Copy the service URL (example):
```
https://smartmess-backend-<hash>-uc.a.run.app
```

Notes:
- Cloud Run file system is ephemeral. Models are retrained as needed; reboots will reset them.
- Do **not** rely on `backend/serviceAccountKey.json` in production. Use the service account above.

## 4) Frontend (Firebase Hosting)

### 4.1 Build Flutter web
```
# From repo root
cd frontend
flutter pub get
flutter build web --release \
  --web-renderer canvaskit \
  --dart-define=SMARTMESS_BACKEND_URL=https://smartmess-backend-<hash>-uc.a.run.app
```

If hosting under a subpath (not root), also add:
```
  --base-href /your-subpath/
```

### 4.2 Deploy with Firebase Hosting
```
firebase init hosting
# Public directory: build/web
# Single-page app: Yes

firebase deploy --only hosting
```

## 5) Production Asset Notes (fonts/icons)

If icons/fonts appear in localhost but not in production, it usually means:
- The server is not serving `build/web` as the web root.
- The base path is wrong (use `--base-href` or update `web/index.html`).
- The host is not serving `.wasm` or font files with correct MIME types.

Recommendations:
- Firebase Hosting handles MIME types for `.wasm` and fonts automatically.
- If you serve via a custom server, ensure:
  - `.wasm` -> `application/wasm`
  - `.ttf/.otf/.woff/.woff2` -> correct font MIME types
- Verify that `build/web/assets/FontManifest.json` and `build/web/assets/MaterialIcons-Regular.otf` are accessible.

## 6) Post-deploy checks

Backend health:
```
curl https://<cloud-run-url>/health
```

Frontend:
- Open the Firebase Hosting URL
- Verify icons render and QR scanning works (requires HTTPS)
- Check predictions (analytics page triggers train + predict)

## 7) Security/Secrets

- Keep `backend/serviceAccountKey.json` out of production containers.
- Use Secret Manager if you must inject credentials.
- Restrict CORS in `backend/main.py` if you want to lock to your domain.
