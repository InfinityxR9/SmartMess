#!/bin/bash
# SmartMess Deployment Quick Start
# Run this to deploy the application

set -e

echo "=== SmartMess Deployment ===" 
echo ""
echo "Status: ✅ Ready for Deployment"
echo ""

# Step 1: Verify Build
echo "Step 1: Verifying Flutter web build..."
cd frontend
if [ -d "build/web" ]; then
    echo "✅ Build directory exists"
else
    echo "❌ Build directory not found - building now..."
    flutter build web --no-wasm-dry-run --release
fi

echo ""
echo "Step 2: Backend Configuration"
echo "  - Ensure serviceAccountKey.json is in backend/ directory"
echo "  - Check requirements.txt is updated with TensorFlow"
echo ""

echo "Step 3: Model Training (Run Once)"
echo "  cd ml_model"
echo "  python train_tensorflow.py alder"
echo "  python train_tensorflow.py oak"
echo "  python train_tensorflow.py pine"
echo ""

echo "Step 4: Deployment Options"
echo ""
echo "Option A: Firebase Hosting (Frontend)"
echo "  firebase deploy --only hosting"
echo ""
echo "Option B: Google Cloud Run (Backend)"
echo "  gcloud run deploy smartmess-backend --source ./backend"
echo ""
echo "Option C: Local Testing"
echo "  Backend: cd backend && python main.py"
echo "  Frontend: cd frontend && flutter run -d web-server"
echo ""

echo "=== Deployment Checklist ==="
echo "[ ] Frontend builds without errors (run: flutter build web)"
echo "[ ] Backend has serviceAccountKey.json"
echo "[ ] Models trained for alder, oak, pine"
echo "[ ] Firebase Firestore configured"
echo "[ ] HTTPS enabled in production"
echo "[ ] Environment variables set"
echo ""

echo "✅ Ready to deploy!"
echo ""
echo "For full details, see: DEPLOYMENT_READY.md"
