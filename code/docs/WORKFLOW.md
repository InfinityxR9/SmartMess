# SmartMess Application Workflow

## User Types & Access Levels

### 1. Students
- **Login**: Enrollment ID + Date of Birth (no Firebase Auth needed)
- **Access**: Personal attendance, reviews, menu viewing, predictions
- **Actions**: Mark attendance (via QR), Submit reviews, View analytics

### 2. Managers
- **Login**: Email + Password (Firebase Auth)
- **Access**: Full mess management, QR generation, attendance tracking, analytics
- **Actions**: Generate QR codes, Mark attendance manually, View detailed analytics

---

## Complete User Workflows

### Workflow 1: Student Marking Attendance (QR Scan)

```
1. Student opens app
   ↓
2. Authenticates with Enrollment ID + DOB
   ↓
3. Selects meal (Breakfast/Lunch/Dinner)
   ↓
4. App shows current time window (e.g., "12:00-14:00" for lunch)
   ↓
5. Student scans QR code (provided by manager on physical display)
   ↓
6. App validates QR code:
   - Check if QR is active
   - Check if current time is within session
   - Check if time interval matches QR's interval
   ↓
7. On validation success:
   - Create attendance record (with studentId, anonymous=false)
   - Show "✓ Attendance Marked"
   - Increment QR scan count
   ↓
8. Student can now:
   - View current menu
   - See crowd predictions
   - Provide review/rating
```

### Workflow 2: Manager Manually Marking Attendance

```
1. Manager logs in with Email + Password
   ↓
2. Manager goes to "Attendance" section
   ↓
3. Selects meal and time interval (e.g., "Lunch, 12:15-12:30")
   ↓
4. Manager clicks "Mark Attendance Manually"
   ↓
5. Manager selects number of students (dropdown or counter)
   ↓
6. Clicks "Confirm"
   ↓
7. System creates attendance records:
   - studentId: NULL (anonymous)
   - isAnonymous: true
   - markedBy: "manual"
   - Repeats N times (if multiple students)
   ↓
8. Manager sees confirmation:
   "✓ 5 students marked (anonymous)"
```

### Workflow 3: Student Providing Review

```
1. Student opens app (logged in)
   ↓
2. After meal ends (post 2-hour window), review option appears
   ↓
3. Student clicks "Rate Today's Lunch"
   ↓
4. Shows review form:
   - Overall rating (1-5 stars)
   - Category ratings: Taste, Hygiene, Quantity, Presentation
   - Comment (optional)
   - Option to submit anonymously
   ↓
5. Student submits review
   ↓
6. System:
   - Creates review record (with studentId or anonymous)
   - Updates analytics aggregation
   - Updates average/median in dish data
   ↓
7. Student sees confirmation + previous reviews for same dish
```

### Workflow 4: Manager Generating QR Code

```
1. Manager logs in
   ↓
2. Goes to "QR Management" or "Today's QR Codes"
   ↓
3. For each meal:
   a. Selects meal type (Breakfast/Lunch/Dinner)
   b. System shows 8 time intervals (15-min each)
   c. For each interval:
      - Manager clicks "Generate QR"
      - System creates unique QR code
      - Displays QR on screen (large, scannable)
      - Manager prints/displays on physical poster
      ↓
4. QR Code contains encoded data:
   {
     "messId": "mess_001",
     "sessionId": "session_20251220_lunch",
     "interval": 2,
     "qrId": "qr_abc123",
     "expiresAt": 1703088600
   }
   ↓
5. QR expires after timeslot ends
   (automatic cleanup, not scanned after 12:30 if interval was 12:15-12:30)
```

### Workflow 5: Viewing Crowd Predictions

```
STUDENT VIEW:
1. Student clicks "Crowd Prediction" or sees it on home screen
2. Shows current meal's intervals:
   - 12:00-12:15: 45 students (predicted)
   - 12:15-12:30: 52 students (predicted)
   - 12:30-12:45: 48 students (predicted)
   - ... (8 intervals total)
3. Student can decide when to go based on predictions
   (fewer people = shorter wait time)


MANAGER VIEW:
1. Manager clicks "Dashboard" → "Predictions"
2. Shows:
   - Today's predictions for all meals
   - Historical accuracy (how close predictions were)
   - Trend analysis
   - AI confidence scores
3. Manager can adjust menu quantities based on predictions
```

### Workflow 6: Viewing Analytics Dashboard (Manager)

```
Manager opens Dashboard:

┌─────────────────────────────────────────┐
│      TODAY'S ATTENDANCE SUMMARY          │
├─────────────────────────────────────────┤
│                                          │
│ Breakfast:   156 students (7:30-9:30)   │
│   - QR Scans: 145                       │
│   - Manual: 11                          │
│   - Avg Rating: 4.1★ (89 reviews)       │
│   - Peak Time: 8:15-8:30                │
│                                          │
│ Lunch:       187 students (12:00-14:00) │
│   - QR Scans: 178                       │
│   - Manual: 9                           │
│   - Avg Rating: 4.3★ (124 reviews)      │
│   - Peak Time: 12:30-12:45              │
│                                          │
│ Dinner:      [Active] (in progress)     │
│   - Current attendance: 92              │
│   - QR Scans: 87                        │
│   - Manual: 5                           │
│                                          │
└─────────────────────────────────────────┘

Detailed Reviews:

┌─────────────────────────────────────────┐
│ BIRYANI WITH RAITA (Lunch)              │
├─────────────────────────────────────────┤
│ Overall: 4.3★ (124 reviews)             │
│                                          │
│ Category Breakdown:                      │
│ - Taste:        4.1★                    │
│ - Hygiene:      4.5★ (excellent!)       │
│ - Quantity:     3.9★                    │
│ - Presentation: 4.0★                    │
│                                          │
│ Rating Distribution:                     │
│ ★★★★★ 60 reviews (48%)                 │
│ ★★★★  52 reviews (42%)                 │
│ ★★★   10 reviews (8%)                  │
│ ★★    2 reviews (2%)                   │
│                                          │
│ Top Comments:                            │
│ - "Fresh ingredients, loved it!"        │
│ - "Could have more raita"               │
│                                          │
└─────────────────────────────────────────┘
```

---

## Data Collection Timeline

### Example: Lunch Session (12:00 - 14:00)

```
TIME        INTERVAL    PREDICTION   ACTUAL        REVIEWS   QR CODE
──────────────────────────────────────────────────────────────────────
11:50       -           45 (12:00)   -             -         Generate QR #1
12:00-12:15 Interval 1  45           42 scanned    -         Active
12:15-12:30 Interval 2  52           49 scanned    [reviews  Active
                                                    coming]   
12:30-12:45 Interval 3  48           45 scanned    ✓10       Active
12:45-13:00 Interval 4  38           40 scanned    ✓15       Active
13:00-13:15 Interval 5  25           28 scanned    ✓8        Active
13:15-13:30 Interval 6  15           14 scanned    ✓5        Active
13:30-13:45 Interval 7  8            9 scanned     ✓3        Expired
13:45-14:00 Interval 8  3            2 scanned     ✓1        Expired

TOTAL ATTENDANCE: 229 students
TOTAL REVIEWS: 42 (out of 229)
PREDICTION ACCURACY: 96% average
```

---

## ML Model Integration Timeline

### Prediction Generation (Evening)

```
6:00 PM: System runs ML model
         Input: Last 30 days of attendance data
         ↓
         Predicts next day's intervals
         ↓
         Stores in predictions collection
         ↓
         (Available to all users at 10 PM)

Morning: Student sees predictions
         (helps them decide when to come)

Real-time: Actual attendance collected
          Compared against predictions
          Accuracy tracked for model improvement
```

---

## QR Code Generation Flow

### Manager's Perspective

```
Manager Action:
1. Lunch Time: 12:00 - 14:00
2. 8 intervals of 15 minutes each

Manager generates QR codes:
┌─────────────────────────────────┐
│ LUNCH - 12:00 - 12:15          │
│ [QR CODE IMAGE]                 │
│ Scan to mark attendance          │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ LUNCH - 12:15 - 12:30          │
│ [QR CODE IMAGE]                 │
│ Scan to mark attendance          │
└─────────────────────────────────┘

... (repeat 6 more times)

Manager refreshes QR codes every 15 minutes
OR
Manager uses auto-refresh feature
```

---

## Deployment & Running the App

### Current Setup (Development)

```
Since flutter run -d edge has issues with hot reload:

OPTION 1: Build & Serve (Recommended)
─────────────────────────────────────
1. Make code changes in VS Code
2. Run: flutter build web --release
3. The build takes 1-2 minutes
4. App is in: build/web/
5. Serve with: python -m http.server 8888 (in build/web/)
6. Access: http://localhost:8888

OPTION 2: Use flutter run with patience
──────────────────────────────────────
flutter run -d edge
(works but sometimes hot reload fails, requires full restart)

OPTION 3: Production Deployment
───────────────────────────────
1. flutter build web --release
2. Deploy to:
   - Google Firebase Hosting
   - Netlify
   - Vercel
   - Or any static web server
```

### Recommended Development Workflow

```bash
# Terminal 1: Backend (Python)
cd backend
python main.py
# Runs on port 8080

# Terminal 2: ML Server (optional)
cd ml_model
python -m flask run --port 5000
# Runs on port 5000 (for future ML API)

# Terminal 3: Frontend (Flutter)
cd frontend
flutter build web --release
cd build/web
python -m http.server 8888
# Access at http://localhost:8888

# Open 3 browsers:
# Browser 1: http://localhost:8888 (Production build)
# Browser 2: For testing manager features
# Browser 3: For testing student features
```

### For Production Deployment

We should use **Firebase Hosting** since we're already using Firestore:

```bash
# One-time setup:
npm install -g firebase-tools
firebase login
cd frontend
firebase init
# Select: Hosting
# Public directory: build/web
# Configure as SPA: Yes

# To deploy:
flutter build web --release
firebase deploy --only hosting
```

Then your app is live at: `https://smartmess-project.web.app`

---

## Next Steps

1. ✅ Database schema finalized (see DATABASE_SCHEMA.md)
2. ⏳ Implement student login (Enrollment ID + DOB)
3. ⏳ Implement manager login (Firebase Auth)
4. ⏳ Create QR code generation feature
5. ⏳ Add attendance marking (QR + Manual)
6. ⏳ Build review system
7. ⏳ Create prediction system (15-min intervals)
8. ⏳ Build manager dashboard
9. ⏳ Deploy to Firebase Hosting

