# SmartMess Feature Testing Guide

## Build Status ✅
- **Build Result**: SUCCESS
- **Command**: `flutter build web --release`
- **Wasm Warnings**: Informational only (Firebase web packages), does not prevent functionality
- **Web Server**: Running at `http://localhost:50061`

## Fixed Issues ✅

### 1. signOutManager Undefined Error
- **File**: `lib/providers/unified_auth_provider.dart`
- **Fix**: Changed `signOutManager()` → `signOut()`
- **Reason**: ManagerAuthService implements `signOut()` method

### 2. IconData Type Errors
- **File**: `lib/screens/qr_generator_screen.dart`
- **Fix**: Wrapped `Icons.refresh` and `Icons.people` with `Icon()` widget
- **Reason**: ElevatedButton.icon expects Widget, not IconData

### 3. Missing Parameters in crowd_dashboard_screen
- **File**: `lib/screens/crowd_dashboard_screen.dart`
- **Fix**: Created `_buildScanPage()` that shows meal type selector before QRScannerScreen
- **Reason**: QRScannerScreen requires mealType parameter

## System Features to Test

### Student Features

#### 1. Student Login
1. Navigate to app at `http://localhost:50061`
2. Click "Student Login"
3. Credentials format: Enrollment ID + Date of Birth
   - Example: `E001` + `1/15/2005`
4. Expected: Redirect to home screen with student name and mess info

#### 2. Mark Attendance via QR
**Flow**: Home Screen → Mark Attendance → Select Breakfast/Lunch/Dinner → QR Scanner
1. On home screen, click "Mark Attendance"
2. Select meal type (Breakfast/Lunch/Dinner)
3. Opens camera with QR scanner
4. Expected results:
   - ✅ Valid QR: Green overlay, "Attendance Marked" message, auto-close
   - ❌ Invalid QR: Red overlay, "Invalid QR" message
   - ❌ Already marked: Red overlay, "Already marked for this meal" message
   - ❌ Expired QR: Red overlay, "QR code expired" message

**Duplicate Prevention**:
- Scan same QR twice for same meal
- Second attempt should show "Already marked for this meal"
- Verify: Student cannot mark attendance twice for same meal/date

#### 3. Menu Display
**Flow**: Crowd Dashboard → Menu Tab
1. Tap "Crowd Dashboard" or navigate to crowd screen
2. Tap "Menu" tab in bottom navigation
3. Expected: Display breakfast, lunch, dinner items for current day

#### 4. View Ratings
**Flow**: Crowd Dashboard → Rating Tab
1. Tap "Rating" tab in bottom navigation
2. Expected: Shows meal rating form and rating statistics

### Manager Features

#### 1. Manager Login
1. Click "Manager Login"
2. Credentials format: Email + Password
   - Example: `oak@admin` + `password123`
3. Expected: Redirect to home screen with mess management options

#### 2. Generate QR Code
**Flow**: Home Screen → Generate QR → Select Breakfast/Lunch/Dinner
1. On home screen, click "Generate QR"
2. Select meal type (Breakfast/Lunch/Dinner)
3. Expected: 
   - QR code displayed
   - Shows meal info (type, date, expiry time - 15 mins)
   - "Regenerate" button for new QR codes
   - "View Attendance" button (placeholder)

**QR Code Details**:
- Format: JSON payload
- Expires in: 15 minutes
- Contains: messId, mealType, qrCodeId (UUID), generatedAt, expiresAt

#### 3. Manual Attendance Marking
- **Status**: Placeholder in current implementation
- **Functionality**: Managers can manually add students to attendance list
- **When**: If student cannot scan or has technical issues

#### 4. View Attendance
- **Status**: Button placeholder in QRGeneratorScreen
- **Expected**: Shows list of students marked for selected meal

### Attendance System Logic

#### Database Structure
```
Firestore Collections:
- attendance/{messId}/{dateStr}/{mealType}/students/{studentId}/
  → {enrollmentId, studentName, markedAt, markedBy}
  
- qr_codes/{messId}/{dateStr}/{mealType}/
  → {qrCodeId, messId, mealType, date, generatedAt, expiresAt, generatedBy, scannedCount}
```

#### Duplicate Prevention
- Implemented in `AttendanceService.isAlreadyMarked()`
- Checks if doc exists in Firestore
- Returns false if already marked (prevents second marking)
- Returns true if not marked yet (allows first marking)

## Testing Checklist

### Core Functionality
- [ ] Student login works
- [ ] Manager login works
- [ ] QR code generation works (15-min expiry)
- [ ] QR code scanning works
- [ ] Attendance marked to Firestore
- [ ] Duplicate prevention blocks second marking
- [ ] Logout works for both user types

### UI/UX
- [ ] Meal selector displays correctly
- [ ] QR scanner shows camera feed (on mobile)
- [ ] Success/failure messages display
- [ ] Color feedback (green for success, red for errors)
- [ ] Auto-navigation after marking

### Data Isolation
- [ ] OAK students see OAK mess
- [ ] ALDER students see ALDER mess
- [ ] Manager only sees their mess
- [ ] Attendance data is per-mess, per-date, per-meal

### Error Handling
- [ ] Invalid QR code shows error
- [ ] Expired QR code shows error
- [ ] Already marked shows error
- [ ] Network error handling
- [ ] Firestore permission errors

## Known Limitations & TODOs

### Not Yet Implemented
1. **Manual Attendance Marking UI** - Button placeholder exists
2. **Attendance View/Analytics** - Button placeholder exists
3. **Review/Rating System** - UI exists but not fully integrated
4. **Menu Management** - Display only, no manager creation UI
5. **Predictions Dashboard** - ML model integration pending
6. **Analytics Dashboard** - Crowd analytics pending

### Deprecation Warnings
- `withOpacity()` deprecated in new Flutter - should use `.withValues()` instead
- Not blocking functionality, only lint warnings

### Print Statements
- Many debug `print()` statements left in code
- Should be removed for production
- Currently for debugging purposes only

## Commands Reference

### Start Web Server
```bash
cd frontend
Push-Location frontend
flutter run -d web-server
```

### Build for Production
```bash
flutter build web --release
```

### Run Analysis
```bash
flutter analyze
```

### Get Dependencies
```bash
flutter pub get
```

## Success Criteria

For "all features should be working perfectly":

✅ **QR Scanning by Students**: Complete
- Code: QRScannerScreen with mobile_scanner integration
- Logic: AttendanceService.markAttendanceViaQR()
- Testing: Ready to test in app

✅ **QR Generation by Managers**: Complete
- Code: QRGeneratorScreen with UUID generation
- Logic: AttendanceService.generateQRCode()
- Database: Firestore qr_codes collection
- Testing: Ready to test in app

✅ **Duplicate Prevention**: Complete
- Code: AttendanceService.isAlreadyMarked()
- Logic: Checks Firestore doc existence
- Testing: Scan same QR twice, verify 2nd fails

✅ **Manual Marking at Manager End**: Partial
- Code: AttendanceService.markAttendanceManually() exists
- UI: Placeholder button ready for integration
- Testing: Service ready, needs UI implementation

✅ **Attendance Data Persistence**: Complete
- Database: Firestore structure designed
- Service: Full CRUD operations implemented
- Testing: Check Firestore console for created attendance records

## Next Steps After Testing

1. **Fix Remaining UI Issues** if any
2. **Implement Manual Marking UI** (high priority)
3. **Implement Attendance View** (medium priority)
4. **Integrate Review/Rating** fully (medium priority)
5. **Add Menu Management** for managers (low priority)
6. **Remove Debug Print Statements** (cleanup)
7. **Fix Deprecation Warnings** (lint cleanup)
8. **Deploy to Production** (Firebase Hosting)
