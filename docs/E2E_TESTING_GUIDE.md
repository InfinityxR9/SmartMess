# End-to-End Testing Guide for SmartMess

This guide covers testing all major features of the SmartMess application.

## Table of Contents
1. [Setup](#setup)
2. [Student Testing Flows](#student-testing-flows)
3. [Manager Testing Flows](#manager-testing-flows)
4. [Security Testing](#security-testing)
5. [Integration Testing](#integration-testing)
6. [Common Issues](#common-issues)

---

## Setup

### Prerequisites
- Flutter development environment setup
- Firebase project configured with:
  - Authentication (Email/Password enabled)
  - Firestore database
  - Test data created (see below)
- Backend server running (optional, for ML predictions)

### Test Data Setup

#### Create Test Messes in Firestore

**Collection: `messes`**
```
mess_001:
  id: "mess_001"
  name: "Mess A"
  location: "Block 1"

mess_002:
  id: "mess_002"
  name: "Mess B"
  location: "Block 2"
```

#### Create Test Users

**Student User:**
- Email: `student@test.com`
- Password: `Test@123`
- Profile: (will be created during first login)

**Manager User (Mess A):**
- Email: `manager_a@test.com`
- Password: `Manager@123`
- Profile: (will be created during first manager login)

**Manager User (Mess B):**
- Email: `manager_b@test.com`
- Password: `Manager@123`
- Profile: (will be created during first manager login)

---

## Student Testing Flows

### Test 1: Student Login & Mess Selection

**Steps:**
1. Launch the app
2. Tap "Student Login"
3. Enter email: `student@test.com`
4. Enter password: `Test@123`
5. Tap "Login"

**Expected Result:**
- Login succeeds
- Splash screen shows briefly
- User is navigated to mess selection screen
- Messes "Mess A" and "Mess B" are displayed

**Test Points:**
- ✅ Email validation works
- ✅ Password validation works
- ✅ Error messages appear for invalid credentials
- ✅ Messes load from Firestore

---

### Test 2: QR Code Scanning & Attendance Marking

**Prerequisites:**
- Student is logged in and has selected a mess
- Manager has generated a QR code for a meal type

**Steps:**
1. From home screen, tap "Mark Attendance"
2. Select meal type (Breakfast/Lunch/Dinner)
3. Camera opens
4. Point camera at QR code
5. System processes QR code

**Expected Result:**
- Camera permission dialog appears (first time only)
- Camera preview shows
- Overlay displays "Point camera at QR code"
- Upon scanning:
  - Success message appears with student name and enrollment ID
  - Attendance is marked in Firestore
  - Screen auto-closes after 2 seconds

**Security Test Points:**
- ✅ Student cannot mark attendance for another mess (error message shown)
- ✅ Student cannot mark same meal twice (if already marked)
- ✅ QR code is expired after 15 minutes (should fail gracefully)

**Test Edge Cases:**
- Invalid QR code → Error message: "Invalid QR code format"
- Wrong mess QR code → Error message: "This QR code is for a different mess!"
- Network error → Error message with retry button

---

### Test 3: Submit Review/Rating

**Steps:**
1. From home screen, tap "Submit Review"
2. Select meal type from dropdown (Breakfast/Lunch/Dinner)
3. Adjust rating slider (1-5 stars)
4. Enter feedback in text field
5. Tap "Submit Feedback"

**Expected Result:**
- Meal type selector works
- Rating slider responds to input
- Comment field accepts text
- Success message appears: "✓ Thank you for your feedback!"
- Form clears after submission
- Review is stored in Firestore as anonymous

**Test Points:**
- ✅ Cannot submit without comment
- ✅ Rating defaults to 3
- ✅ Anonymous flag is set in Firestore (no studentId)
- ✅ Multiple reviews can be submitted

**Verify in Firestore:**
```
/reviews/{messId}/meal_reviews/{reviewId}
- rating: 4
- comment: "Great meal"
- mealType: "breakfast"
- anonymous: true
- submittedAt: "2024-01-15T10:30:00Z"
```

---

### Test 4: Crowd Predictions

**Steps:**
1. From home screen, tap "Predictions"
2. Observe crowd prediction screen

**Expected Result:**
- Screen loads with info about AI predictions
- "Best Time" card shows recommended time slot
- All time slots displayed with:
  - Time slot name
  - Expected crowd number
  - Crowd level (Low/Medium/High/Very High)
  - Progress bar showing crowd percentage
  - Sentiment icon matching crowd level

**Backend Integration:**
- If backend is running: Predictions load from ML model
- If backend is offline: Graceful error message shown
- Predictions update in real-time

**Test Points:**
- ✅ Best slot is correctly identified
- ✅ Color coding matches crowd level
- ✅ Progress bar fills correctly
- ✅ Error handling when backend is unavailable

---

### Test 5: Crowd Dashboard

**Steps:**
1. From home screen, tap "Crowd Dashboard"
2. Observe live crowd information

**Expected Result:**
- Real-time crowd data displayed
- Today's attendance summary shown
- Meal-wise attendance counts visible
- Total attendance calculated correctly

---

## Manager Testing Flows

### Test 6: Manager Login & Setup

**Steps:**
1. Launch app, tap "Manager Login"
2. Enter email: `manager_a@test.com`
3. Enter password: `Manager@123`
4. Tap "Login"

**Expected Result:**
- Manager is authenticated
- Redirected to manager home screen
- Manager actions displayed:
  - Generate QR
  - Mark Attendance
  - Create Menu
  - Analytics

---

### Test 7: QR Code Generation

**Steps:**
1. From manager home, tap "Generate QR"
2. Select meal type (Breakfast/Lunch/Dinner)
3. View QR code

**Expected Result:**
- QR code is generated and displayed
- QR code contains encrypted meal/time information
- QR code expires in 15 minutes
- Can generate multiple QR codes for same meal

**Verify QR Code Data:**
- Should contain: `messId`, `mealType`, `timestamp`, `expiryTime`
- QR code should be scannable by student scanner

---

### Test 8: Manual Attendance Marking

**Steps:**
1. From manager home, tap "Mark Attendance"
2. Select meal type
3. Enter student enrollment ID
4. Tap "Mark Attendance"

**Expected Result:**
- Student attendance is recorded
- Message shows "Marked successfully"
- Attendance appears in analytics

---

### Test 9: Analytics Dashboard

**Steps:**
1. From manager home, tap "Analytics"
2. Observe attendance and review data

**Expected Result:**
- Today's attendance summary displayed
- Meal-wise attendance counts shown
- Total attendance calculated
- **Crowd Predictions** section shows:
  - ML model predictions for each time slot
  - Crowd levels with color coding
  - Progress bars showing crowd percentage
- **Meal Reviews** section shows:
  - Anonymous reviews from students
  - Star ratings for each review
  - Review comments
  - Meal type indicator

**Manager-Specific Tests:**
- ✅ Only manager's own mess data is shown
- ✅ Cannot see other mess analytics
- ✅ Reviews show as "Anonymous feedback"
- ✅ No student identification visible in reviews

---

## Security Testing

### Test 10: Mess Isolation

**Objective:** Verify students cannot mark attendance outside their assigned mess

**Steps:**
1. Login as student, select "Mess A"
2. Manager of "Mess B" generates QR code
3. Try to scan Mess B's QR code in Mess A

**Expected Result:**
- Scan processing shows
- Error message appears: "ERROR: This QR code is for a different mess! You cannot mark attendance here."
- No attendance recorded
- Firestore shows security log entry

**Verify Security Log:**
```
/security_logs/{messId}/{studentId}
- type: "MESS_MISMATCH_ATTEMPT"
- attemptedMessId: "mess_002"
- timestamp: "2024-01-15T10:45:00Z"
- description: "[QR Scanner] SECURITY: Mess mismatch attempt"
```

---

### Test 11: Anonymous Review Verification

**Objective:** Confirm reviews have no student identification

**Steps:**
1. Student submits a review
2. Check Firestore `/reviews/{messId}/meal_reviews/{reviewId}`

**Expected Result:**
- Review document has NO `studentId` field
- `anonymous: true` flag is set
- Manager cannot identify reviewer

---

### Test 12: Manager Constraint Verification

**Objective:** Ensure one manager per mess

**Steps:**
1. Login as `manager_a@test.com` (manager of Mess A)
2. Verify they can only:
   - Generate QR for Mess A
   - See Mess A analytics
   - View Mess A reviews

**Expected Result:**
- Manager can only manage their assigned mess
- Cannot generate QR for other messes
- Cannot view other mess analytics

---

## Integration Testing

### Test 13: Complete Attendance Flow

**Steps:**
1. Manager generates QR code for breakfast
2. Student scans QR code
3. Attendance marked successfully
4. Manager views analytics
5. Attendance count increased

**Expected Result:**
- All steps complete successfully
- Data synced in real-time
- Analytics updated immediately

---

### Test 14: Complete Review Flow

**Steps:**
1. Student marks attendance for lunch
2. Student navigates to Submit Review
3. Student rates lunch as 5 stars
4. Student adds comment
5. Manager views analytics
6. Review visible in "Meal Reviews" section

**Expected Result:**
- Review stored anonymously
- Manager sees review in analytics
- Cannot identify reviewer

---

### Test 15: Prediction Accuracy

**Objective:** Verify ML predictions are integrated and working

**Steps:**
1. Manager views Analytics
2. Check "Crowd Predictions" section
3. Student views Predictions screen
4. Compare predicted vs actual crowd

**Expected Result:**
- Predictions load from backend
- Display reasonable crowd estimates
- Color coding matches predictions
- Both manager and student see same predictions

---

## Common Issues

### Issue: Firebase Authentication Fails

**Cause:** Firebase project not configured or keys incorrect
**Solution:**
- Verify `google-services.json` (Android) in place
- Verify `GoogleService-Info.plist` (iOS) in place
- Check Firebase console has Authentication enabled
- Recreate test users if needed

---

### Issue: QR Scanner Not Working

**Cause:** Camera permissions not granted or no camera available
**Solution:**
- Grant camera permissions when prompted
- Use physical device for testing (emulators have limited camera support)
- Check `CAMERA_PERMISSIONS.md` for configuration

---

### Issue: Predictions Not Loading

**Cause:** Backend ML server offline
**Solution:**
- Ensure backend is running on `http://localhost:8080`
- Check prediction_service.py is running
- Verify network connectivity
- App should gracefully handle offline backend

---

### Issue: Firestore Rules Blocking Access

**Cause:** Security rules too restrictive
**Solution:**
- For development: Use test rules allowing authenticated access
- Verify user is authenticated before Firestore operations
- Check Firestore security rules in console

---

### Issue: QR Code Scanning Too Slow

**Cause:** Mobile device performance or lighting
**Solution:**
- Ensure good lighting on QR code
- Close other apps to free memory
- Update mobile_scanner to latest version
- Try different camera angles

---

## Test Checklist

- [ ] Student login works
- [ ] Mess selection works
- [ ] QR scanning marks attendance correctly
- [ ] Attendance not marked twice for same meal
- [ ] Mess isolation security works (student blocked from other mess)
- [ ] Reviews submitted anonymously
- [ ] Manager can view analytics
- [ ] Manager can see reviews without student names
- [ ] Predictions load and display correctly
- [ ] Manager can generate QR codes
- [ ] Manual attendance marking works
- [ ] All error messages display appropriately
- [ ] Firestore data structure is correct
- [ ] No security vulnerabilities identified

---

## End-to-End Test Scenarios

### Scenario 1: Full Day Simulation

1. Morning: Manager generates breakfast QR
2. Morning: Multiple students mark breakfast attendance
3. Mid-day: Students submit reviews for breakfast
4. Mid-day: Manager checks analytics for breakfast attendance
5. Afternoon: Manager generates lunch QR
6. Afternoon: Students mark lunch attendance
7. Afternoon: Manager views ML predictions for evening

### Scenario 2: Cross-Mess Testing

1. Two managers (different messes) both logged in
2. Both generate QR codes simultaneously
3. Students scan codes from respective messes
4. Verify each sees only their own mess data
5. Verify analytics isolated by mess

### Scenario 3: Error Recovery

1. Student scans invalid QR code → handles gracefully
2. Student scans expired QR code → shows error
3. Network error during submission → shows retry
4. Backend offline during predictions → graceful fallback

---

## Performance Testing

- Analytics screen loads in < 2 seconds
- QR scanning responds in < 1 second
- Firestore queries return in < 500ms
- ML predictions API responds in < 5 seconds

---

**Last Updated:** 2024-01-15
**App Version:** 1.0.0
**Test Coverage:** End-to-End, Security, Integration
