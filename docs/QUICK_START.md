# SMARTMESS - Quick Start Guide

## Running the Application

### 1. Start the Backend Server
```bash
cd backend
python main.py
```
**Expected Output**:
```
 * Serving Flask app 'main'
 * Debug mode: off
 * Running on http://127.0.0.1:8080
```

### 2. Start the Frontend Server (in separate terminal)
```bash
cd frontend
flutter run -d chrome --web-port=8888
```
**Expected Output**:
```
✓ Built build/web
✓ built successfully!
Launching lib/main.dart on Chrome in debug mode...
✓ Chrome is connected to the Dart VM service at http://127.0.0.1:54321/
```

### 3. Access the Application
- **Frontend**: http://localhost:8888
- **Backend**: http://localhost:8080
- **Health Check**: http://localhost:8080/health

---

## Quick Test Procedures

### Test 1: Menu Display ✅
```
1. Open http://localhost:8888
2. Select "Alder" mess
3. Tap "View Menu" button
4. Should navigate to menu screen and display items
```
**Expected**: Menu items appear without errors

### Test 2: Predictions (Dev Mode) ✅
```
1. Open prediction screen
2. Check console (F12) for CORS errors
3. Should show crowd % for current 15-min slot
4. Works outside meal times (dev mode enabled)
```
**Expected**: 
```json
{
  "messId": "alder",
  "meal_type": "lunch",
  "slot_minute": 0,
  "predictions": [...]
}
```

### Test 3: Reviews ✅
```
At LUNCH TIME ONLY (12:00-14:00):
1. Open review screen
2. Submit a review (e.g., "Good meal")
3. Scroll down to see reviews
4. Rating appears

At DINNER TIME (19:30-21:30):
1. Reopen review screen
2. Lunch reviews SHOULD NOT appear
3. Only dinner reviews visible
```
**Expected**: Reviews isolated by meal time

### Test 4: QR Scanner (Web) ✅
```
1. Open on mobile browser or desktop with camera
2. Tap "Mark Attendance" → "Scan QR"
3. Browser asks for camera permission
4. Grant permission
5. Camera feed appears
6. Can scan QR codes
```
**Expected**: Camera works without permission_handler errors

### Test 5: CORS Check ✅
```bash
curl -X OPTIONS http://localhost:8080/reviews \
  -H "Origin: http://localhost:8888" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type"
```
**Expected**:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS, DELETE, PUT
Access-Control-Allow-Headers: Content-Type, Authorization
```

---

## Run Full Integration Test

```bash
python test_complete_integration.py
```

**Tests Performed**:
- ✅ Backend health
- ✅ CORS preflight
- ✅ Prediction endpoint
- ✅ Reviews endpoint
- ✅ Manager info endpoint
- ✅ Time slot isolation
- ✅ Mess model isolation

**Expected Output**:
```
============================================================
TEST SUMMARY
============================================================
Passed: 7/7

✅ ALL TESTS PASSED!
```

---

## Key Endpoints Reference

### Backend API (http://localhost:8080)

#### Health Check
```
GET /health
```

#### Get Predictions
```
POST /predict
{
  "messId": "alder",
  "devMode": true
}
```

#### Get/Submit Reviews
```
GET /reviews?messId=alder
POST /reviews?messId=alder
{
  "messId": "alder",
  "mealType": "lunch",
  "rating": 5,
  "comment": "Excellent meal",
  "studentId": "ABC123",
  "studentName": "John"
}
```

#### Manager Info
```
GET /manager-info?messId=alder
```

---

## Debugging

### Check Backend is Running
```bash
curl http://localhost:8080/health
```

### Check Frontend Network Requests (Browser Console)
```javascript
// Open DevTools (F12)
// Go to Console tab
// Should see successful API responses
```

### View Prediction Model Info
```bash
ls -la ml_model/models/
# Should show:
# alder_model.keras
# oak_model.keras
# pine_model.keras
```

### Check Review Database Structure
```
Firebase Console → Firestore
reviews/
├── alder/
│   ├── 2025-01-15/
│   │   ├── breakfast/
│   │   ├── lunch/
│   │   └── dinner/
```

### Enable Detailed Logging
Edit `frontend/lib/services/prediction_service.dart`:
```dart
print('[Prediction] Request: messId=$messId, devMode=true');
print('[Prediction] Response: ${response.statusCode}');
```

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| CORS error in console | Restart backend server |
| Menu shows "coming soon" | Ensure MenuScreen import is present |
| Camera not working | Check browser camera permissions |
| Predictions 0% | Ensure models trained, check devMode |
| Reviews across meals | Verify meal time windows (7:30-9:30, etc) |
| QR scan fails | Ensure backend is running |

---

## File Structure

```
SMARTMESS/
├── backend/
│   ├── main.py                    # Flask backend with CORS ✅
│   ├── requirements.txt
│   └── serviceAccountKey.json
│
├── frontend/
│   ├── lib/
│   │   ├── screens/
│   │   │   ├── home_screen.dart   # Menu navigation fixed ✅
│   │   │   ├── qr_scanner_screen.dart  # Web-compatible ✅
│   │   │   └── menu_screen.dart   # Display menu items
│   │   │
│   │   ├── services/
│   │   │   ├── prediction_service.dart  # Dev mode enabled ✅
│   │   │   ├── review_service.dart      # Time slot filtering ✅
│   │   │   └── ...
│   │   │
│   │   └── main.dart
│   └── pubspec.yaml
│
├── ml_model/
│   ├── models/
│   │   ├── alder_model.keras
│   │   ├── oak_model.keras
│   │   └── pine_model.keras
│   └── ...
│
├── test_complete_integration.py    # Full integration test ✅
├── FIXES_COMPLETE.md               # Detailed fix documentation ✅
└── README.md
```

---

## Next Steps

1. **Start Servers**: Run backend and frontend
2. **Run Tests**: Execute `test_complete_integration.py`
3. **Manual Testing**: Follow test procedures above
4. **Verify Features**: Check menu, predictions, reviews, QR
5. **Check Console**: Ensure no errors in browser console

All fixes are complete and ready for testing! 🚀
