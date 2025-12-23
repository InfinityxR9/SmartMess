# Frontend Integration Guide - Real-Time Predictions API

## Quick Start for Frontend Teams

The SmartMess backend now provides real-time crowd predictions for the analytics page. Here's how to integrate it:

## API Endpoint

**Endpoint:** `POST /predict`  
**Base URL:** `https://smartmess-backend.appspot.com` (or your deployment URL)

## Request

```json
{
  "mess_id": "mess1",
  "timestamp": "2025-12-23T22:30:00Z"
}
```

**Parameters:**
- `mess_id` (string, required): Unique identifier for the mess
- `timestamp` (string, ISO 8601 format, optional): Current time. If omitted, uses server time.

## Response

```json
{
  "messId": "mess1",
  "timestamp": "2025-12-23T22:30:00Z",
  "date": "2025-12-23",
  "mealType": "dinner",
  "current_crowd": 28,
  "capacity": 120,
  "current_percentage": 23.3,
  "predictions": [
    {
      "time_slot": "10:45 PM",
      "time_24h": "22:45",
      "predicted_crowd": 32,
      "capacity": 120,
      "crowd_percentage": 26.7,
      "recommendation": "Good time",
      "confidence": "high"
    },
    {
      "time_slot": "11:00 PM",
      "time_24h": "23:00",
      "predicted_crowd": 35,
      "capacity": 120,
      "crowd_percentage": 29.2,
      "recommendation": "Good time",
      "confidence": "high"
    }
  ]
}
```

**Response Fields:**
- `messId`: The mess for which prediction was requested
- `timestamp`: Server timestamp of the prediction
- `date`: Date (YYYY-MM-DD) of the prediction
- `mealType`: Detected meal type (breakfast, lunch, dinner)
- `current_crowd`: Current number of students (real-time count)
- `capacity`: Total capacity of the mess
- `current_percentage`: Current crowd as percentage
- `predictions`: Array of predictions for upcoming 15-minute intervals

**Prediction Details:**
- `time_slot`: Human-readable time (12-hour format with AM/PM)
- `time_24h`: Military time format
- `predicted_crowd`: Estimated students at this time
- `crowd_percentage`: Predicted percentage of capacity
- `recommendation`: "Good time", "Moderate crowd", or "Avoid"
- `confidence`: "high", "medium", or "low" based on historical data availability

## Code Examples

### React/Dart (Frontend)

```dart
// Dart example for Flutter
Future<void> fetchPredictions() async {
  final response = await http.post(
    Uri.parse('${API_BASE_URL}/predict'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'mess_id': selectedMessId,
      'timestamp': DateTime.now().toIso8601String(),
    }),
  );

  if (response.statusCode == 200) {
    final predictions = jsonDecode(response.body);
    setState(() {
      currentCrowd = predictions['current_crowd'];
      predictedCrowd = predictions['predictions'];
    });
  }
}
```

### JavaScript (Web)

```javascript
// JavaScript example
async function fetchPredictions(messId) {
  const response = await fetch('/predict', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      mess_id: messId,
      timestamp: new Date().toISOString(),
    }),
  });

  const predictions = await response.json();
  displayPredictions(predictions);
}
```

## Integration Points

### 1. Analytics Page
- Call `/predict` API when page loads
- Display current crowd percentage with visual indicator
- Show predicted crowding for next few slots
- Refresh predictions on page refresh (no caching)

### 2. Crowd Dashboard
- Real-time crowd indicator (updates every page load)
- Recommendation badges (Good time / Moderate / Avoid)
- Confidence indicator (based on available historical data)
- Time-based color coding

### 3. QR Scanner Results
- After scan confirmation, show best times to visit this mess
- Use prediction data to recommend quiet hours
- Show how busy it will be in 15/30/45 minutes

## Meal Time Boundaries

The API automatically detects meal type based on current time:

| Meal Type | Start Time | End Time | Predictions Until |
|-----------|-----------|---------|------------------|
| Breakfast | 7:30 AM | 9:30 AM | 9:30 AM |
| Lunch | 12:00 PM | 2:00 PM | 2:00 PM |
| Dinner | 7:30 PM | 9:30 PM | 9:30 PM |

**Outside meal hours:**
- API returns empty predictions array
- Current crowd = 0 (mess closed)
- Recommendation = "Mess closed"

## Error Handling

### Invalid Mess ID
```json
{
  "error": "Invalid mess_id",
  "status": 400
}
```

### No Training Data
```json
{
  "error": "Model not trained yet, try again later",
  "status": 503,
  "predictions": []
}
```

### Firebase Connection Error
```json
{
  "error": "Unable to fetch current crowd data",
  "status": 500,
  "predictions": []
}
```

## Performance Notes

- **Response Time:** ~500ms typical (includes Firebase query + prediction)
- **Cache Strategy:** NO CACHING - always fresh data
- **Update Frequency:** Call on every page load, every screen refresh
- **Rate Limiting:** No per-user limits; backend handles ~1000 requests/minute

## Data Freshness Guarantee

Each call to `/predict` performs:
1. **Real-time query** of current attendance count from Firebase
2. **Fresh prediction** generation using latest model
3. **Zero caching** - guaranteed current data

This means every page refresh shows the actual current crowd.

## Model Training Details

The prediction model:
- **Trains:** Every 15 minutes automatically
- **Learns from:** Past 7 days of attendance data
- **Updates:** `model_data.json` file
- **Pattern size:** 72 unique time intervals (8 per meal × 3 meals × 3 messes)

## Confidence Levels Explained

- **High Confidence:** Historical data available for 4+ days
- **Medium Confidence:** Historical data available for 1-3 days
- **Low Confidence:** No historical data, using trend-based estimate

## Testing the API

### Quick Test (Using curl)
```bash
curl -X POST https://smartmess-backend.appspot.com/predict \
  -H "Content-Type: application/json" \
  -d '{
    "mess_id": "mess1",
    "timestamp": "2025-12-23T13:00:00Z"
  }'
```

### Expected Response (During Lunch)
Should return predictions for lunch hour with reasonable crowd percentages.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Always returns 0 crowd | Check Firebase has actual attendance data in nested structure |
| Predictions empty outside meal hours | This is expected - API only predicts during meal times |
| Confidence always "low" | Model needs more training days, check training logs |
| Response time > 2 seconds | Check Firebase connection and network latency |
| Always same predictions | Verify model is updating every 15 minutes |

## Frontend Best Practices

1. **Always call on page load** - no caching
2. **Handle empty predictions** - show current crowd only
3. **Display confidence** - help users understand prediction reliability
4. **Use recommendations** - show "Good time" / "Moderate" / "Avoid" badges
5. **Real-time updates** - consider polling every 30-60 seconds for live updates
6. **Error handling** - gracefully degrade if API is unavailable

## Contact & Support

For issues or questions about the prediction API:
- Check backend logs: `gcloud logs read`
- Verify Firebase connection: Check serviceAccountKey.json
- Verify model training: Check ml_model/model_data.json timestamp
- Test manually: Use curl command above

---

**API Version:** 1.0  
**Last Updated:** 2025-12-23  
**Status:** Production Ready ✅
