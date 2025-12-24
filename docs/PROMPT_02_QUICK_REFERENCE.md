# Quick Reference - PROMPT_02 Changes

## What's New

### 🔴 CRITICAL: Review System Changed
- **Old**: Reviews visible anytime, stored flat
- **New**: Reviews only visible during their meal slot
  - Breakfast reviews (7:30-9:30) only visible then
  - Lunch reviews (12:00-14:00) only visible then  
  - Dinner reviews (19:30-21:30) only visible then
  - Database: `reviews/{messId}/{date}/{meal}/items`

### 🟠 IMPORTANT: Predictions Now 15-Min Slot Based
- **Old**: Single prediction per meal
- **New**: Refreshes every 15 minutes during meal
  - 12:15 (first prediction with 12:00-12:15 data)
  - 12:30 (second prediction with 12:15-12:30 data)
  - Continues every 15 min...
- **Models**: Trained on-the-spot for each slot with real 15-min data

### 🟡 NEW API Endpoints
1. `/manager-info?messId=alder` → Get manager name & email
2. `/reviews` → POST/GET reviews with meal slot filtering
3. Enhanced `/predict` → 15-min slots + dev mode

### 🟢 Fixed Issues
- ✓ Camera permissions on mobile web
- ✓ 0% predictions despite data (now uses real slot data)
- ✓ Firestore blocking errors (backend handles more)
- ✓ Mess data isolation (no cross-contamination)

---

## Testing in Dev

### See Predictions Anytime
```json
POST /predict
{
  "messId": "alder",
  "devMode": true  // ← This allows predictions outside meal hours
}
```

### See Current Meal Type
- 07:30-09:30: breakfast
- 12:00-14:00: lunch
- 19:30-21:30: dinner
- Outside: empty (no predictions unless devMode=true)

### Test Reviews
- Only submit during meal times
- Only visible during that same meal time
- Tomorrow's reviews aren't visible today

---

## What Needs Frontend Integration

### Still To Do
1. **Manager Info Display**
   - Call `/manager-info?messId={messId}`
   - Show in student profile
   - Show in manager profile

2. **Menu System**
   - Complete menu creation UI
   - Add menu display in student UI
   - Hook to backend endpoints

3. **Update Rating Screen**
   - Already updated ReviewService ✓
   - Rating screen will auto-work ✓
   - No further changes needed

---

## Database Schema Changes

### Old Reviews Structure
```
reviews/
├── {messId}/
│   └── meal_reviews/
│       └── documents with mealType field
```

### New Reviews Structure  
```
reviews/
├── {messId}/
│   └── {date}/ (e.g., "2025-12-24")
│       ├── breakfast/
│       │   └── items/
│       │       └── {reviewId}
│       ├── lunch/
│       │   └── items/
│       │       └── {reviewId}
│       └── dinner/
│           └── items/
│               └── {reviewId}
```

---

## Code Examples

### Get Manager Info
```dart
final response = await http.get(
  Uri.parse('http://localhost:8080/manager-info?messId=alder')
);
final data = jsonDecode(response.body);
print(data['managerName']); // "John Doe"
print(data['managerEmail']); // "john@example.com"
```

### Get Reviews (Auto-Hides if Wrong Time)
```dart
// At 13:00 (lunch)
final reviews = await reviewService.getMealReviews(
  messId: 'alder',
  mealType: 'lunch'  // ✓ Will return reviews
);

// At 14:15 (outside meals)
final reviews = await reviewService.getMealReviews(
  messId: 'alder',
  mealType: 'breakfast'  // ✗ Will return empty list
);
```

### Get Predictions with 15-Min Data
```dart
final response = await http.post(
  Uri.parse('http://localhost:8080/predict'),
  body: jsonEncode({
    'messId': 'alder',
    'devMode': false  // true = see predictions anytime
  })
);
final data = jsonDecode(response.body);
print(data['slot_minute']); // 0, 15, 30, or 45
print(data['meal_type']); // breakfast, lunch, or dinner
```

---

## Important Notes

### Meal Windows Are EXACT
- 7:30 is IN breakfast, 9:30 is OUT
- 12:00 is IN lunch, 14:01 is OUT
- 19:30 is IN dinner, 21:30 is OUT

### Predictions Need Data
- If no attendance records in 15-min slot → uses pre-trained fallback
- More data = better predictions
- Real-time training happens each request

### Review Visibility
- Reviews are ONE-TIME visible
- Breakfast reviews disappear after breakfast ends
- No "archive" of old reviews
- Fresh slate each day

### Dev Mode for Testing
- Set `devMode: true` to bypass meal time checks
- Useful for testing outside business hours
- Should be disabled in production

---

## Troubleshooting

### Predictions Still 0%
- Check meal time windows are correct (7:30-9:30, etc.)
- Verify attendance data exists for current 15-min slot
- Try with test data marking 10+ students
- Check mess isolation (using right messId)

### Reviews Not Submitting
- Verify time is within meal hours (check exact boundaries)
- Check network to backend is working
- Try FireStorefall-back by checking Firestore directly
- Verify request format matches new API

### QR Camera Not Working
- Ensure permission_handler added to pubspec.yaml
- Run `flutter pub get`
- Check permission is granted (Android/iOS settings)
- On web, allow camera in browser

---

## What's Working

✅ ML Model - Trained with correct meal times  
✅ 15-min slot predictions - Implemented  
✅ Spot model training - Real-time data only  
✅ Review slot filtering - Only shows right times  
✅ Manager info endpoints - Ready to display  
✅ Camera permissions - Request flow added  
✅ Mess data isolation - No cross-contamination  
✅ Dev mode predictions - For testing anytime  

---

**Implementation Date**: December 24, 2025  
**Status**: Complete and Ready for Integration
