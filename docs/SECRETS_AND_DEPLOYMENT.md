# Secrets and Deployment: Handling API Keys and Credentials

This guide shows where sensitive data appears in this repo, what is actually secret,
and how to inject secrets safely during deployment (Firebase Hosting + Render).

## 1) What I found in this repo

Paths that reference credentials or secrets:
- `backend/serviceAccountKey.json` (file exists locally; not tracked)
- `backend/main.py` (loads `serviceAccountKey.json` or ADC)
- `backend/data_retention_and_autotraining.py` (loads `serviceAccountKey.json` or ADC)
- `ml_model/train_tensorflow.py` (loads `serviceAccountKey.json` or ADC)
- `backend/deploy.sh` (mentions `GOOGLE_APPLICATION_CREDENTIALS`)
- `frontend/lib/firebase_options.dart` (Firebase web config: apiKey, projectId, etc.)
- `backend/.env.example` (placeholder `SECRET_KEY`)

Important note: `frontend/lib/firebase_options.dart` is **not a secret**.
Firebase Web API keys are public by design. Security is enforced by Firebase
rules, App Check, and project-level restrictions.

## 2) What is secret vs. what is public

Secret (must NOT be in the frontend or git):
- `serviceAccountKey.json` (Firebase Admin credentials)
- Any third-party API keys that can access paid resources or write data
- Flask `SECRET_KEY` or JWT signing keys

Public (ok to be in frontend build):
- Firebase web config (apiKey, authDomain, projectId, etc.)
- Backend URL used by the frontend

Rule of thumb: if the browser can read it, it is not secret.
All secrets must live on the backend or in a secrets manager.

## 3) Where to store secrets in production

### Render (backend)
Use Render "Secret Files" or "Environment Variables".

Recommended for Firebase Admin:
- Secret File: `serviceAccountKey.json`
- Path: `/opt/render/project/src/backend/serviceAccountKey.json`
- Environment Variable:
  - `GOOGLE_APPLICATION_CREDENTIALS=/opt/render/project/src/backend/serviceAccountKey.json`

Never commit `serviceAccountKey.json` to git.

### Firebase Hosting (frontend)
You cannot hide secrets in Flutter web builds.
Use `--dart-define` only for **public** config like backend URL:
```bash
flutter build web --release \
  --dart-define=SMARTMESS_BACKEND_URL=https://YOUR-SERVICE.onrender.com
```

If you need a secret for a third-party API, call it from the backend instead.

## 4) How to inject secrets at deploy time

### Backend (Render)
1. Add the `serviceAccountKey.json` secret file in Render.
2. Set `GOOGLE_APPLICATION_CREDENTIALS` env var.
3. Deploy.

The code in `backend/main.py` already loads the file or ADC.

### Frontend (Firebase Hosting)
1. Build with `--dart-define=SMARTMESS_BACKEND_URL=...`
2. Deploy with `firebase deploy --only hosting`

## 5) Local development (safe way)

Use a local `backend/serviceAccountKey.json` and keep it ignored by git.
This repo already ignores it via `.gitignore`.

If you add other secrets:
- Create a local `.env`
- Keep it out of git (`.gitignore` already covers `.env`)
- Load it in Python using `python-dotenv` (already in requirements)

## 6) Extra security recommendations

- Restrict Firebase API key usage to your domains in Google Cloud Console.
- Use separate Firebase projects for dev and prod.
- Enable Firebase App Check to reduce abuse.
- Lock Firestore rules before production.
- Tighten CORS in `backend/main.py` (replace `*` with your hosting domain).
- Rotate any key if it was ever committed or leaked.

## 7) If a secret was committed by mistake

1. Remove it from git:
   ```bash
   git rm --cached path/to/secret
   git commit -m "Remove secret from repo"
   ```
2. Rotate the secret in the provider console.
3. For history cleanup, use `git filter-repo` (only if necessary).

## 8) Quick checklist (production)

- [ ] `backend/serviceAccountKey.json` is NOT in git
- [ ] Render secret file is configured
- [ ] `GOOGLE_APPLICATION_CREDENTIALS` set in Render
- [ ] Frontend built with correct `SMARTMESS_BACKEND_URL`
- [ ] Firestore rules are locked down
- [ ] CORS restricted to the Hosting domain
