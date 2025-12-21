#!/bin/bash

# Build Docker image
docker build -t smartmess-backend .

# Run locally (replace with Cloud Run deployment for production)
docker run -p 8080:8080 \
  -e GOOGLE_APPLICATION_CREDENTIALS=/app/serviceAccountKey.json \
  -v $(pwd)/serviceAccountKey.json:/app/serviceAccountKey.json \
  smartmess-backend

# To deploy to Cloud Run:
# gcloud run deploy smartmess-api \
#   --source . \
#   --platform managed \
#   --region us-central1 \
#   --allow-unauthenticated
