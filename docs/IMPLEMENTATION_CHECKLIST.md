# SmartMess Implementation Checklist

## PHASE 1: Setup & Infrastructure ✅ MOSTLY DONE

### Your Tasks (User Side)

**Database Setup:**
- [ ] **Create test messes in Firestore**
  ```
  Collection: messes
  Documents:
  - mess_oak_001
    - name: "Oak Mess"
    - messCode: "OAK"
    - capacity: 200
    - managerIds: ["manager_oak_001"]
    - meals: ["breakfast", "lunch", "dinner"]
    - location: {latitude: 28.7041, longitude: 77.1025, address: "..."}
  
  - mess_alder_001
    - name: "Alder Mess"
    - messCode: "ALDER"
    - capacity: 180
    - managerIds: ["manager_alder_001"]
    - meals: ["breakfast", "lunch", "dinner"]
    - location: {latitude: 28.7042, longitude: 77.1026, address: "..."}
  ```

- [ ] **Create test student users**
  ```
  Collection: users
  Documents:
  - user_student_oak_001
    - type: "student"
    - enrollmentId: "OAK_E123001"
    - dateOfBirth: "2005-05-15"
    - name: "Rahul Singh"
    - email: "rahul@college.edu"
    - messId: "mess_oak_001"
    - messName: "Oak Mess"
  
  - user_student_oak_002
    - type: "student"
    - enrollmentId: "OAK_E123002"
    - dateOfBirth: "2004-08-20"
    - name: "Priya Patel"
    - messId: "mess_oak_001"
    - messName: "Oak Mess"
  
  - user_student_alder_001
    - type: "student"
    - enrollmentId: "ALDER_E456001"
    - dateOfBirth: "2005-03-10"
    - name: "Amit Kumar"
    - messId: "mess_alder_001"
    - messName: "Alder Mess"
  ```

- [ ] **Create test manager users**
  ```
  Collection: users
  Documents:
  - user_manager_oak_001
    - type: "manager"
    - managerEmail: "oak_manager@college.edu"
    - managerName: "Alice Oak"
    - assignedMesses: ["mess_oak_001"]
    - adminSince: "2025-12-20T10:00:00Z"
    - (Firebase Auth: oak_manager@college.edu / password123)
  
  - user_manager_alder_001
    - type: "manager"
    - managerEmail: "alder_manager@college.edu"
    - managerName: "Bob Alder"
    - assignedMesses: ["mess_alder_001"]
    - adminSince: "2025-12-20T10:00:00Z"
    - (Firebase Auth: alder_manager@college.edu / password123)
  ```

- [ ] **Create Firebase Auth accounts for managers**
  - Go to Firebase Console → Authentication
  - Create user: `oak_manager@college.edu` / `password123`
  - Create user: `alder_manager@college.edu` / `password123`
  - Link these to the user documents above

**Firestore Security Rules:**
- [ ] Update rules to enforce mess isolation:
  ```firestore
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      
      // Students can only access their own data
      match /users/{userId} {
        allow read: if request.auth.uid == userId;
        allow write: if false;
      }
      
      // Attendance - enforce mess isolation
      match /attendance/{attendanceId} {
        allow read: if request.auth != null && 
          (isStudentInMess() || isManagerOfMess());
        allow create: if request.auth != null;
        allow write: if false;
      }
      
      // Reviews - enforce mess isolation
      match /reviews/{reviewId} {
        allow read: if request.auth != null && 
          (isStudentInMess() || isManagerOfMess());
        allow create: if request.auth != null;
        allow write: if false;
      }
      
      function isStudentInMess() {
        let student = get(/databases/$(database)/documents/users/$(request.auth.uid));
        return resource.data.messId == student.data.messId;
      }
      
      function isManagerOfMess() {
        let manager = get(/databases/$(database)/documents/users/$(request.auth.uid));
        return resource.data.messId in manager.data.assignedMesses;
      }
    }
  }
  ```

---

## PHASE 2: Student Login System ✅ DONE

**What's Implemented:**
- ✅ `StudentAuthService` - Enrollment ID + DOB lookup
- ✅ `StudentLoginScreen` - Beautiful login UI
- ✅ `UnifiedAuthProvider` - Manages auth state
- ✅ Student data persistence (enrollmentId, messId, messName)

**Testing (You need to do this):**
- [ ] Build and deploy: `flutter build web --release`
- [ ] Navigate to `http://localhost:8888`
- [ ] Click "Student Login"
- [ ] Try: `OAK_E123001` + `2005-05-15`
- [ ] Should show: "Authenticating..." → Success → Next screen

**If login fails:**
- Check that student record exists in Firestore with exact enrollmentId
- Check dateOfBirth format: `YYYY-MM-DD`

---

## PHASE 3: Manager Login System ✅ DONE

**What's Implemented:**
- ✅ `ManagerAuthService` - Firebase Email/Password auth
- ✅ `ManagerLoginScreen` - Beautiful login UI
- ✅ Manager mess isolation (can only see assigned messes)

**Testing (You need to do this):**
- [ ] Build and deploy
- [ ] Click link "Are you a manager?"
- [ ] Try: `oak_manager@college.edu` + `password123`
- [ ] Should show: "Authenticating..." → Success → Next screen

**If login fails:**
- Check Firebase Auth user exists with that email
- Check user document in Firestore with `type: "manager"`
- Check `assignedMesses` array has mess IDs

---

## PHASE 4: Student Home Screen 🔄 PENDING

**What needs to be built:**
```
Student Home Screen should show:
┌─────────────────────────────────────────┐
│ Welcome, Rahul Singh!                   │
│ Oak Mess                                 │
├─────────────────────────────────────────┤
│                                          │
│  TODAY'S MEALS                           │
│  ────────────────────                   │
│  🌅 Breakfast (7:30 - 9:30)             │
│     [View] [Mark Attendance]            │
│                                          │
│  🍽️  Lunch (12:00 - 14:00)              │
│     [View] [Mark Attendance]            │
│                                          │
│  🌙 Dinner (19:30 - 21:30)              │
│     [View] [Mark Attendance]            │
│                                          │
├─────────────────────────────────────────┤
│  [Menu]  [Predictions]  [Reviews]       │
│  [Feedback]  [Logout]                   │
└─────────────────────────────────────────┘
```

**Subtasks:**
1. Create `StudentHomeScreen` widget
2. Show current authenticated user info
3. Show their mess name & code
4. Display current meals (Breakfast, Lunch, Dinner)
5. Add buttons for each meal section:
   - View Menu
   - Mark Attendance (QR scan)
   - View Predictions
   - Submit Review
6. Add Logout button

---

## PHASE 5: Menu Display Service 🔄 PENDING

**What needs to be built:**
1. Create `MenuService` to fetch menus from Firestore
2. Create `MenuModel` with fields:
   - messId, date, breakfast, lunch, dinner
3. Create `MenuScreen` to display:
   ```
   TODAY'S MENU - Oak Mess
   ───────────────────────
   
   🌅 BREAKFAST (7:30 - 9:30)
   Main: Aloo Paratha
   Side: Pickle & Yogurt
   Drink: Milk Tea
   
   🍽️  LUNCH (12:00 - 14:00)
   Main: Biryani with Raita
   Side: Cucumber Salad
   Drink: Buttermilk
   
   🌙 DINNER (19:30 - 21:30)
   Main: Paneer Butter Masala
   Side: Roti
   Drink: Water
   ```

---

## PHASE 6: Crowd Prediction Service 🔄 PENDING

**What needs to be built:**
1. Create `PredictionModel` with:
   - messId, mealType, date, intervals (array of 8 predictions)
   - Each interval: timeWindow, predictedCrowd, confidence
2. Create `PredictionService` to fetch predictions
3. Create `PredictionScreen` showing:
   ```
   LUNCH CROWD PREDICTIONS - Oak Mess
   ──────────────────────────────────
   
   12:00-12:15: 45 students 📊 (92% confidence)
   12:15-12:30: 52 students 📊 (88% confidence) [PEAK]
   12:30-12:45: 48 students 📊 (90% confidence)
   12:45-13:00: 38 students 📊 (85% confidence)
   13:00-13:15: 25 students 📊 (82% confidence)
   13:15-13:30: 15 students 📊 (80% confidence)
   13:30-13:45: 8 students  📊 (78% confidence)
   13:45-14:00: 3 students  📊 (75% confidence)
   ```

---

## PHASE 7: QR Code Scanning 🔄 PENDING

**What needs to be built:**
1. Create `QRScannerService` using `mobile_scanner` package
2. Update pubspec.yaml with permissions for camera
3. Create `QRScannerScreen`:
   - Shows camera feed
   - Scans QR code
   - Validates QR (messId, sessionId, interval match)
   - Creates attendance record
4. Handle scanning results:
   - ✅ Valid QR → "Attendance marked!"
   - ❌ Wrong mess → "This QR is for another mess"
   - ❌ Expired → "Time slot ended"
   - ❌ Already scanned → "Already marked for this slot"

---

## PHASE 8: Review/Rating System 🔄 PENDING

**What needs to be built:**
1. Create `ReviewModel`:
   - rating (1-5), categories (taste, hygiene, quantity, presentation)
   - comment, isAnonymous
2. Create `ReviewService` to save/fetch reviews
3. Create `ReviewSubmitScreen`:
   ```
   RATE TODAY'S LUNCH - Oak Mess
   Biryani with Raita
   ─────────────────────────────
   
   Overall Rating: ⭐⭐⭐⭐ 4/5
   
   Taste:        ⭐⭐⭐⭐⭐
   Hygiene:      ⭐⭐⭐⭐⭐
   Quantity:     ⭐⭐⭐
   Presentation: ⭐⭐⭐⭐
   
   Comment (optional):
   [Really good, fresh ingredients]
   
   [ ] Submit Anonymously
   
   [Submit Review]
   ```
4. Show aggregated reviews from other students

---

## PHASE 9: Manager Home Screen 🔄 PENDING

**What needs to be built:**
```
Manager Dashboard - Oak Mess
────────────────────────────

TODAY'S ATTENDANCE
──────────────────
🌅 Breakfast:  156 / 200 (78%)
🍽️  Lunch:     187 / 200 (93%)  ← PEAK
🌙 Dinner:     [Upcoming]

ACTIONS
──────
[Generate QR Codes]
[Mark Attendance (Manual)]
[View Analytics]
[Update Menu]
[Logout]

MANAGER ISOLATION:
Only sees: Oak Mess
Cannot see: Alder Mess data
```

---

## PHASE 10: QR Code Generation (Manager) 🔄 PENDING

**What needs to be built:**
1. Create `QRGeneratorService`:
   - Generate unique QR code per interval
   - Encode: {messId, sessionId, interval, expiresAt}
   - Save to Firestore
2. Create `QRGenerationScreen`:
   ```
   QR CODES FOR TODAY'S LUNCH
   ──────────────────────────
   
   12:00-12:15  [Generate QR] → [QR Image] [Print]
   12:15-12:30  [Generate QR] → [QR Image] [Print]
   12:30-12:45  [Generate QR] → [QR Image] [Print]
   ... (8 total)
   
   [Auto-refresh every 15 min] [Stop]
   ```

---

## PHASE 11: Manual Attendance Marking (Manager) 🔄 PENDING

**What needs to be built:**
1. Create `ManualAttendanceScreen`:
   ```
   MARK ATTENDANCE MANUALLY
   ────────────────────────
   
   Meal: Lunch
   Time Slot: 12:15 - 12:30
   
   Number of Students: [5] ↕️
   
   [Mark as Present]
   
   (Stores as anonymous attendance)
   ```
2. Creates N attendance records with `isAnonymous: true`

---

## PHASE 12: Manager Analytics Dashboard 🔄 PENDING

**What needs to be built:**
```
ANALYTICS - Oak Mess
────────────────────

ATTENDANCE OVER TIME
12:00  ▁
12:15  ████ 45
12:30  █████ 52  ← PEAK
12:45  ████ 48
13:00  ███ 38
13:15  ██ 25
13:30  █ 15
13:45  █ 8

REVIEWS SUMMARY
───────────────
Biryani: 4.3★ (124 reviews)
- Taste: 4.1★
- Hygiene: 4.5★
- Quantity: 3.9★

PREDICTIONS ACCURACY
This week: 94% accurate
```

---

## PHASE 13: ML Model Integration 🔄 PENDING

**Backend (Python):**
1. Collect attendance data daily
2. Train model with 30-day history
3. Generate predictions per interval
4. Store in Firestore
5. Expose via REST API

**Frontend:**
1. Fetch predictions from Firestore
2. Display on student prediction screen
3. Update predictions daily at 8 PM

---

## Timeline & Priority

### Week 1 (URGENT):
- [ ] Set up test data in Firestore (YOUR TASK)
- [ ] Test student login
- [ ] Test manager login
- [ ] Build student home screen (BUILDING NOW)
- [ ] Build manager home screen

### Week 2:
- [ ] Menu display
- [ ] QR code scanning
- [ ] QR code generation
- [ ] Manual attendance marking

### Week 3:
- [ ] Review/rating system
- [ ] Analytics dashboard
- [ ] Mess isolation enforcement

### Week 4:
- [ ] ML model training
- [ ] Predictions display
- [ ] Manager predictions dashboard

---

## Testing Checklist

**Login Tests:**
- [ ] Student login with valid credentials
- [ ] Student login with invalid enrollment ID
- [ ] Student login with wrong DOB
- [ ] Manager login with valid credentials
- [ ] Manager login with invalid email
- [ ] Manager cannot see other manager's mess data

**Mess Isolation Tests:**
- [ ] OAK student cannot see ALDER data
- [ ] ALDER student cannot see OAK data
- [ ] OAK manager cannot see ALDER data
- [ ] OAK manager can only mark attendance for OAK

**Data Tests:**
- [ ] Reviews are mess-specific
- [ ] Attendance is mess-specific
- [ ] Predictions are mess-specific
- [ ] Sessions are mess-specific

---

## Next Immediate Steps

1. ✅ Code is ready to build
2. **YOUR TASK**: Set up test data in Firestore (follow section at top)
3. **MY TASK**: Build student home & manager home screens
4. **TEST**: Login with your test users
5. **BUILD**: `flutter build web --release` each time

Ready? Let me know when test data is set up!
