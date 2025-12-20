# SmartMess Database Schema

## Collections Overview

```
Firestore Database Structure:
├── users/                          (Student & Manager accounts)
├── messes/                         (Mess locations)
├── sessions/                       (Meal sessions: breakfast, lunch, dinner)
├── attendance/                     (Student attendance records)
├── reviews/                        (Student reviews/feedback)
├── menus/                          (Dish menus per mess)
├── predictions/                    (Crowd predictions per interval)
├── qr_codes/                       (Generated QR codes for attendance)
└── analytics/                      (Aggregated data for managers)
```

---

## 1. Users Collection

### Document Structure: `users/{userId}`

```json
{
  "type": "student|manager",
  "createdAt": "2025-12-20T10:30:00Z",
  
  // STUDENT-SPECIFIC FIELDS
  "enrollmentId": "OAK_E123456",        // Unique within college (OAK_E123456, ALDER_E654321)
  "dateOfBirth": "2005-05-15",          // Format: YYYY-MM-DD
  "name": "John Doe",
  "email": "john@college.edu",
  "messId": "mess_oak_001",             // Which mess student is allocated to
  "messName": "Oak Mess",               // Denormalized for quick display
  
  // MANAGER-SPECIFIC FIELDS
  "managerEmail": "manager@college.edu",
  "managerName": "Alice Manager",
  "assignedMesses": ["mess_oak_001", "mess_alder_002"],  // Manager handles these messes
  "adminSince": "2025-12-20T10:30:00Z"
}
```

**Key Change:** 
- Students are tied to ONE mess (`messId`)
- Managers can manage multiple messes (`assignedMesses`)
- Enrollment IDs are prefixed with mess name (e.g., `OAK_E123456`)


---

## 2. Messes Collection

### Document Structure: `messes/{messId}`

```json
{
  "name": "Oak Mess",
  "messCode": "OAK",                   // Unique code (OAK, ALDER, BIRCH, etc)
  "location": {
    "latitude": 28.7041,
    "longitude": 77.1025,
    "address": "College Campus - North Wing"
  },
  "capacity": 200,
  "managerIds": ["user_456", "user_789"],  // Managers who run this mess
  "meals": ["breakfast", "lunch", "dinner"],
  "createdAt": "2025-12-20T10:30:00Z"
}
```

**Key Point:** Each mess has a unique code (OAK, ALDER, BIRCH) used for:
- Enrollment ID prefixes (OAK_E123456)
- Grouping students and data
- Isolating reviews and attendance per mess

---

## 3. Sessions Collection

### Document Structure: `sessions/{messId}_{date}_{mealType}`

Sessions are now organized by mess, so each mess has its own timeline:

```json
{
  "messId": "mess_oak_001",
  "messName": "Oak Mess",
  "date": "2025-12-20",                // Format: YYYY-MM-DD
  "mealType": "lunch",                 // breakfast, lunch, or dinner
  "startTime": "12:00",                // HH:MM format
  "endTime": "14:00",                  // HH:MM format
  "expectedDish": "Biryani with Raita", 
  "status": "active|completed|cancelled",
  "createdAt": "2025-12-20T11:30:00Z",
  
  // Timeslots for 15-minute intervals
  "timeslots": [
    {
      "interval": 1,
      "startTime": "12:00",
      "endTime": "12:15",
      "prediction": 45,                // Predicted crowd count for OAK ONLY
      "actualAttendance": 42
    },
    // ... 8 total intervals
  ]
}
```

**Critical:** Sessions are per-mess. Oak Mess lunch and Alder Mess lunch are completely separate.

---

## 4. Attendance Collection

### Document Structure: `attendance/{attendanceId}`

```json
{
  "messId": "mess_oak_001",
  "messName": "Oak Mess",              // Denormalized for filtering
  "sessionId": "mess_oak_001_2025-12-20_lunch",
  "studentId": "user_123",             // NULL if anonymous (manager marked)
  "enrollmentId": "OAK_E123456",       // Store enrollment for auditing
  "timeslotInterval": 2,               // Which 15-min interval (1-8)
  "markedAt": "2025-12-20T12:18:00Z",
  "markedBy": "qr_scan|manual",        // How it was marked
  "isAnonymous": false,                // True if manager manually marked
  "qrCodeId": "qr_abc123"              // Reference if scanned
}
```

**Mess Isolation:** Each attendance record is tagged with messId, ensuring students from different messes don't affect each other's data.

---

## 5. Reviews Collection

### Document Structure: `reviews/{reviewId}`

```json
{
  "messId": "mess_oak_001",
  "messName": "Oak Mess",              // Ensure reviews are mess-specific
  "sessionId": "mess_oak_001_2025-12-20_lunch",
  "studentId": "user_123",
  "enrollmentId": "OAK_E123456",
  "dishName": "Biryani with Raita",
  "rating": 4,                         // 1-5 stars
  "comment": "Really good, fresh ingredients",
  "categories": {
    "taste": 4,
    "hygiene": 5,
    "quantity": 3,
    "presentation": 4
  },
  "createdAt": "2025-12-20T14:15:00Z",
  "isAnonymous": true                  // Student can choose anonymity
}
```

**Mess Isolation:** Students from OAK mess cannot see or affect reviews from ALDER mess.

---

## 6. Menus Collection

### Document Structure: `menus/{messId}_{date}`

Menus are organized per mess:

```json
{
  "messId": "mess_oak_001",
  "messName": "Oak Mess",
  "date": "2025-12-20",                // Format: YYYY-MM-DD
  "meals": {
    "breakfast": {
      "mainDish": "Aloo Paratha",
      "sideDish": "Pickle & Yogurt",
      "beverage": "Milk Tea"
    },
    "lunch": {
      "mainDish": "Biryani with Raita",
      "sideDish": "Cucumber Salad",
      "beverage": "Buttermilk"
    },
    "dinner": {
      "mainDish": "Paneer Butter Masala",
      "sideDish": "Roti",
      "beverage": "Water"
    }
  },
  "createdAt": "2025-12-20T08:00:00Z",
  "createdBy": "user_456"               // Manager ID
}
```

**Note:** Oak Mess menu is completely separate from Alder Mess menu.

---

## 7. Predictions Collection

### Document Structure: `predictions/{predictionId}`

```json
{
  "messId": "mess_001",
  "sessionId": "session_20251220_lunch",
  "mealType": "lunch",
  "date": "2025-12-20",
  
  "predictions": [
    {
      "interval": 1,
      "timeWindow": "12:00-12:15",
      "predictedCrowd": 45,
      "confidence": 0.92,               // 0-1 (high confidence)
      "basedOnHistoricalDays": 30,
      "generatedAt": "2025-12-20T11:50:00Z"
    },
    {
      "interval": 2,
      "timeWindow": "12:15-12:30",
      "predictedCrowd": 52,
      "confidence": 0.88,
      "basedOnHistoricalDays": 30,
      "generatedAt": "2025-12-20T11:50:00Z"
    }
    // ... 8 intervals total
  ],
  "generatedAt": "2025-12-20T11:50:00Z"
}
```

---

## 8. QR Codes Collection

### Document Structure: `qr_codes/{qrId}`

```json
{
  "messId": "mess_001",
  "sessionId": "session_20251220_lunch",
  "timeslotInterval": 2,               // Which 15-min slot
  "qrData": "smartmess_qr_abc123xyz",  // Unique QR code string
  "generatedAt": "2025-12-20T12:10:00Z",
  "generatedBy": "user_456",           // Manager ID
  "expiresAt": "2025-12-20T12:30:00Z", // Expires after timeslot ends
  "scansCount": 23,                    // How many times scanned
  "isActive": true,
  "metadata": {
    "expectedDish": "Biryani with Raita",
    "capacity": 200,
    "interval": 2
  }
}
```

---

## 9. Analytics Collection

### Document Structure: `analytics/{messId}_daily_{date}`

Real-time aggregated stats for manager dashboard:

```json
{
  "messId": "mess_001",
  "date": "2025-12-20",
  
  "breakfast": {
    "totalAttendance": 156,
    "qrScans": 145,
    "manualMarks": 11,
    "avgRating": 4.1,
    "reviewCount": 89,
    "topDish": "Aloo Paratha"
  },
  "lunch": {
    "totalAttendance": 187,
    "qrScans": 178,
    "manualMarks": 9,
    "avgRating": 4.3,
    "reviewCount": 124,
    "topDish": "Biryani with Raita"
  },
  "dinner": {
    "totalAttendance": null,
    "qrScans": null,
    "manualMarks": null,
    "avgRating": null,
    "reviewCount": null,
    "topDish": null
  },
  
  "peakTimeslots": {
    "breakfast": 2,  // Interval 2 had most attendance
    "lunch": 4,
    "dinner": null
  },
  
  "updatedAt": "2025-12-20T15:00:00Z"
}
```

---

## Firestore Security Rules

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users can read/write their own data
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow write: if request.auth.uid == userId;
    }
    
    // Public mess data
    match /messes/{messId} {
      allow read: if true;
      allow write: if false; // Only backend can write
    }
    
    // Sessions visible to all authenticated users
    match /sessions/{sessionId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
    
    // Attendance records
    match /attendance/{attendanceId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null; // Students/Managers mark attendance
      allow update, delete: if false;
    }
    
    // Reviews - public read, authenticated write
    match /reviews/{reviewId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.studentId;
    }
    
    // Menus public
    match /menus/{menuId} {
      allow read: if true;
      allow write: if false;
    }
    
    // QR Codes - managers can write, authenticated can read
    match /qr_codes/{qrId} {
      allow read: if request.auth != null;
      allow write: if false; // Backend generates
    }
    
    // Predictions public
    match /predictions/{predictionId} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

---

## Data Flow Diagram

```
┌─────────────────┐
│   STUDENT       │
└────────┬────────┘
         │
         ├─→ Scans QR Code (Attendance)
         │         ↓
         │    [QR Code Validation]
         │         ↓
         │    [Create Attendance Record]
         │
         ├─→ Gives Review/Rating
         │         ↓
         │    [Create Review Record]
         │         ↓
         │    [Update Analytics]
         │
         └─→ Views Menu & Predictions


┌─────────────────┐
│   MANAGER       │
└────────┬────────┘
         │
         ├─→ Generates QR Code
         │         ↓
         │    [Create QR Code Record]
         │
         ├─→ Marks Attendance Manually
         │         ↓
         │    [Create Anonymous Attendance]
         │
         ├─→ Views Dashboard
         │         ↓
         │    [Read Analytics]
         │    [Read Reviews/Ratings]
         │    [View Predictions]
         │
         └─→ Updates Menu
                  ↓
            [Create Menu Record]
```

---

## Backup & Data Retention

- **Attendance Records**: Keep forever (for historical analysis)
- **Reviews**: Keep forever (reputation data)
- **QR Codes**: Delete after 1 week (cleanup old codes)
- **Predictions**: Keep for 3 months (ML training data)
- **Sessions**: Archive after 6 months

---

## Performance Considerations

### Indexes to Create:
1. `attendance` - `(messId, sessionId, markedAt)`
2. `reviews` - `(messId, mealType, createdAt DESC)`
3. `sessions` - `(messId, date DESC)`
4. `qr_codes` - `(messId, expiresAt)`

### Caching Strategy:
- Cache analytics data in memory (updates every 5 min)
- Cache predictions for 1 hour
- Cache menus for 24 hours

