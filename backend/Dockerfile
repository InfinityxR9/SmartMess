FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first
COPY backend/requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Copy backend app
COPY backend/ /app/

# Copy ML model
COPY ml_model/ /ml_model/

ENV ML_MODEL_DIR=/ml_model
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

EXPOSE 8080

CMD gunicorn --preload --workers 1 --threads 4 --timeout 120 \
    --bind 0.0.0.0:${PORT:-8080} main:app
