# SmartMess API Documentation

## Overview

The SmartMess backend API provides endpoints for crowd prediction and model training. The API is built with Flask and deployed on Google Cloud Run.

## Base URL

```
https://smartmess-api-XXXXX.run.app
```

## Authentication

Currently, all endpoints are unauthenticated (suitable for web access). In production, consider adding API key authentication.

## Endpoints

### 1. Health Check

**Endpoint**: `GET /health`

Check if the API is running.

**Response** (200 OK):
```json
{
  "status": "healthy"
}
```

**Example**:
```bash
curl https://smartmess-api-XXXXX.run.app/health
```

---

### 2. Crowd Prediction

**Endpoint**: `POST /predict`

Get crowd predictions for a specific mess.

**Request**:
```json
{
  "messId": "mess_1"
}
```

**Response** (200 OK):
```json
{
  "messId": "mess_1",
  "current_crowd": 45,
  "predictions": [
    {
      "time_slot": "02:00 PM",
      "predicted_crowd": 32,
      "crowd_percentage": 64.0
    },
    {
      "time_slot": "03:00 PM",
      "predicted_crowd": 25,
      "crowd_percentage": 50.0
    },
    {
      "time_slot": "04:00 PM",
      "predicted_crowd": 38,
      "crowd_percentage": 76.0
    },
    {
      "time_slot": "05:00 PM",
      "predicted_crowd": 55,
      "crowd_percentage": 110.0
    }
  ],
  "best_slot": {
    "time_slot": "03:00 PM",
    "predicted_crowd": 25,
    "crowd_percentage": 50.0
  }
}
```

**Error Responses**:

400 Bad Request:
```json
{
  "error": "messId is required"
}
```

500 Internal Server Error:
```json
{
  "error": "Internal server error message"
}
```

**Example**:
```bash
curl -X POST https://smartmess-api-XXXXX.run.app/predict \
  -H "Content-Type: application/json" \
  -d '{"messId": "mess_1"}'
```

**Parameters**:
- `messId` (string, required): The unique identifier of the mess

**Response Fields**:
- `messId` (string): The mess ID
- `current_crowd` (integer): Current crowd count from last 10 minutes of scans
- `predictions` (array): Array of TimeSlotPrediction objects
  - `time_slot` (string): Predicted time slot (e.g., "02:00 PM")
  - `predicted_crowd` (integer): Predicted number of people
  - `crowd_percentage` (float): Predicted percentage of capacity
- `best_slot` (object): The time slot with lowest predicted crowd

---

### 3. Model Training

**Endpoint**: `POST /train`

Trigger model retraining with data from the last 30 days.

**Request**:
```json
{}
```

**Response** (200 OK):
```json
{
  "message": "Model trained successfully",
  "samples": 1500
}
```

**Error Responses**:

500 Internal Server Error:
```json
{
  "error": "Firebase not initialized"
}
```

**Example**:
```bash
curl -X POST https://smartmess-api-XXXXX.run.app/train \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Notes**:
- This endpoint requires Firebase credentials to be configured
- Training uses scans from the last 30 days
- Should be called periodically (e.g., weekly) for model updates
- Returns number of samples used for training

---

## Data Models

### TimeSlotPrediction

```typescript
interface TimeSlotPrediction {
  time_slot: string;      // "02:00 PM"
  predicted_crowd: number; // 25
  crowd_percentage: number; // 50.0
}
```

### PredictionResponse

```typescript
interface PredictionResponse {
  messId: string;
  current_crowd: number;
  predictions: TimeSlotPrediction[];
  best_slot: TimeSlotPrediction;
}
```

---

## Error Handling

The API returns standard HTTP status codes:

| Status | Description |
|--------|-------------|
| 200 | Request successful |
| 400 | Bad request (missing or invalid parameters) |
| 500 | Internal server error |

All error responses include an `error` field with description.

---

## Rate Limiting

Currently no rate limiting is implemented. In production, consider:
- Limit to 100 requests per minute per IP
- Cache predictions for 5 minutes
- Batch training requests

---

## Performance Considerations

### Request Timing

- Prediction request: ~500ms (with Firebase query)
- Training request: ~2-5 minutes (depends on data size)

### Caching Strategy

Predictions are not cached by default. To improve performance:

```python
from flask_caching import Cache

cache = Cache(app, config={'CACHE_TYPE': 'simple'})

@app.route('/predict', methods=['POST'])
@cache.cached(timeout=300)  # Cache for 5 minutes
def predict():
    ...
```

---

## Integration Examples

### Flutter Web

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<PredictionResult?> getPrediction(String messId) async {
  try {
    final response = await http.post(
      Uri.parse('https://smartmess-api-XXXXX.run.app/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'messId': messId}),
    );

    if (response.statusCode == 200) {
      return PredictionResult.fromJson(
        jsonDecode(response.body)
      );
    }
  } catch (e) {
    print('Error: $e');
  }
  return null;
}
```

### JavaScript

```javascript
async function getPrediction(messId) {
  try {
    const response = await fetch(
      'https://smartmess-api-XXXXX.run.app/predict',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ messId }),
      }
    );

    if (response.ok) {
      return await response.json();
    }
  } catch (error) {
    console.error('Error:', error);
  }
  return null;
}
```

### Python

```python
import requests
import json

def get_prediction(mess_id):
    url = 'https://smartmess-api-XXXXX.run.app/predict'
    payload = {'messId': mess_id}
    
    response = requests.post(
        url,
        json=payload,
        headers={'Content-Type': 'application/json'},
        timeout=10
    )
    
    if response.status_code == 200:
        return response.json()
    return None
```

---

## Monitoring & Debugging

### View API Logs

```bash
gcloud run logs read smartmess-api --limit=100
```

### Test Endpoints

```bash
# Health check
curl https://smartmess-api-XXXXX.run.app/health

# Prediction with specific mess
curl -X POST https://smartmess-api-XXXXX.run.app/predict \
  -H "Content-Type: application/json" \
  -d '{"messId": "mess_1"}'

# Start training
curl -X POST https://smartmess-api-XXXXX.run.app/train \
  -H "Content-Type: application/json"
```

### Common Issues

**Connection Timeout**
- Check if Cloud Run service is running: `gcloud run services list`
- Verify endpoint URL is correct
- Check network connectivity

**Internal Server Error (500)**
- Review logs: `gcloud run logs read smartmess-api`
- Check Firebase credentials
- Verify Firestore rules allow read access

**Bad Request (400)**
- Verify `messId` is provided
- Check JSON formatting
- Ensure Content-Type is application/json

---

## Future API Enhancements

1. **Authentication**
   - API key authentication
   - OAuth 2.0 for secure endpoints

2. **Rate Limiting**
   - Per-IP limits
   - User-based quotas

3. **Caching**
   - Redis for prediction caching
   - Automatic cache invalidation

4. **Analytics Endpoints**
   - Historical trends
   - Accuracy metrics
   - Peak hours analysis

5. **Admin Endpoints**
   - Manual model updates
   - Data reset
   - Configuration changes

---

## Support

For API issues:
1. Check the logs: `gcloud run logs read smartmess-api`
2. Review error response message
3. Verify Firebase configuration
4. Test with curl examples

---

**Last Updated**: 2024
**API Version**: 1.0
