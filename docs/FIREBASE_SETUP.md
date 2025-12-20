# SmartMess Firebase Setup Guide

## Prerequisites

- Google account
- Basic knowledge of Firebase
- 15-20 minutes

## Step-by-Step Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `smartmess-project`
4. Enable Google Analytics (optional)
5. Click "Create project"

### 2. Create Web App

1. In Firebase Console, click the web icon `</>`
2. Register app name: `SmartMess Web`
3. Check "Also set up Firebase Hosting for this app"
4. Click "Register app"
5. Copy the Firebase config (you'll need this)

### 3. Configure Firebase Options

Update `frontend/lib/firebase_options.dart`:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_WEB_API_KEY',                    // From config
  appId: 'YOUR_APP_ID',                          // From config
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID', // From config
  projectId: 'smartmess-project',
  authDomain: 'smartmess-project.firebaseapp.com',
  storageBucket: 'smartmess-project.appspot.com',
);
```

### 4. Enable Anonymous Authentication

1. Go to Firebase Console → Authentication
2. Click "Get Started"
3. Click "Anonymous" provider
4. Toggle "Enable"
5. Click "Save"

### 5. Create Firestore Database

1. Go to Firebase Console → Firestore Database
2. Click "Create database"
3. Choose region: `us-central1` (or closest to you)
4. Choose "Start in test mode" (development only)
5. Click "Create"

### 6. Set Firestore Security Rules

In Firestore Console, go to "Rules" tab and replace with:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all authenticated users
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 7. Create Collections and Add Sample Data

#### Collection: `messes`

Add documents with this structure:

```json
{
  "name": "Main Mess",
  "capacity": 100,
  "latitude": 28.5355,
  "longitude": 77.3910,
  "imageUrl": null
}
```

#### Create Other Collections

The following collections will be created automatically when data is added:
- `users` - User home mess preferences
- `scans` - Crowd entry logs
- `menus` - Daily menus
- `ratings` - User ratings
- `rating_summary` - Aggregated ratings

### 8. Create Service Account for Backend

1. Go to Firebase Console → Project Settings
2. Click "Service Accounts" tab
3. Click "Generate New Private Key"
4. Save as `serviceAccountKey.json`
5. Place in `backend/` folder

### 9. Enable Required APIs

In Google Cloud Console:

```bash
gcloud services enable \
  firestore.googleapis.com \
  cloudrun.googleapis.com \
  cloudbuild.googleapis.com \
  container.googleapis.com
```

### 10. Test Connection

```bash
cd frontend
flutter run -d chrome
```

You should see:
- Anonymous login succeed
- Firebase connection establish
- Messes load from Firestore

## Firestore Data Structure

### Document: messes/{messId}

```
id: "mess_1"
name: "North Mess"
capacity: 100
latitude: 28.5355
longitude: 77.3910
imageUrl: null (optional)
```

### Document: users/{uid}

```
homeMessId: "mess_1"
```

### Document: scans/{scanId}

```
uid: "user_123"
messId: "mess_1"
ts: Timestamp(2024-01-15 12:30:00)
```

### Document: menus/{menuId}

```
messId: "mess_1"
date: Timestamp(2024-01-15 00:00:00)
items: [
  { name: "Rice", description: "Basmati Rice" },
  { name: "Dal", description: "Masoor Dal" }
]
```

### Document: ratings/{ratingId}

```
uid: "user_123"
messId: "mess_1"
score: 4
comment: "Good food"
ts: Timestamp(2024-01-15 13:45:00)
```

### Document: rating_summary/{messId}

```
messId: "mess_1"
count: 45
sum: 180
avg: 4.0
```

## Sample Data Import Script

Create `frontend/scripts/seed_firestore.js`:

```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function seedDatabase() {
  const messes = [
    {
      id: 'mess_1',
      data: {
        name: 'North Mess',
        capacity: 100,
        latitude: 28.5355,
        longitude: 77.3910
      }
    },
    {
      id: 'mess_2',
      data: {
        name: 'South Mess',
        capacity: 80,
        latitude: 28.5310,
        longitude: 77.3920
      }
    },
    {
      id: 'mess_3',
      data: {
        name: 'West Mess',
        capacity: 120,
        latitude: 28.5345,
        longitude: 77.3880
      }
    }
  ];

  try {
    for (const mess of messes) {
      await db.collection('messes').doc(mess.id).set(mess.data);
      console.log(`Created mess: ${mess.data.name}`);
    }

    // Add sample menu
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    await db.collection('menus').add({
      messId: 'mess_1',
      date: admin.firestore.Timestamp.fromDate(today),
      items: [
        { name: 'Rice', description: 'Basmati Rice' },
        { name: 'Dal', description: 'Masoor Dal' },
        { name: 'Vegetables', description: 'Mixed Vegetables' },
        { name: 'Roti', description: 'Wheat Roti' }
      ]
    });

    console.log('Database seeding completed!');
    process.exit(0);
  } catch (error) {
    console.error('Error seeding database:', error);
    process.exit(1);
  }
}

seedDatabase();
```

Run with:
```bash
npm install firebase-admin
node seed_firestore.js
```

## Backup and Restore

### Export Data

```bash
gcloud firestore export gs://YOUR_BUCKET/backup-$(date +%s)
```

### Import Data

```bash
gcloud firestore import gs://YOUR_BUCKET/backup-TIMESTAMP
```

## Troubleshooting

### "Permission Denied" Error

**Solution**: Check Firestore security rules

```firestore
// Temporary (development only)
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

### Collections Not Appearing

**Solution**: Collections are created when first document is added

```dart
await db.collection('scans').add({
  'uid': userId,
  'messId': messId,
  'ts': Timestamp.now(),
});
```

### Authentication Not Working

**Steps**:
1. Ensure Anonymous Auth is enabled
2. Check security rules allow `request.auth != null`
3. Clear browser cache and refresh

### Quota Exceeded

**Solutions**:
- Upgrade to paid plan
- Optimize queries with indexes
- Implement caching layer

## Best Practices

1. **Security**: Never expose service account key in frontend
2. **Indexing**: Create composite indexes for complex queries
3. **Caching**: Cache predictions for 5 minutes
4. **Pagination**: Limit documents per query to 10-20
5. **Real-time**: Use `.limit(1)` for real-time listeners

## Next Steps

1. Configure Firestore rules for production
2. Set up authentication for mess staff
3. Create admin panel for data management
4. Set up automated backups
5. Monitor Firestore usage and costs

---

**Firebase Setup Complete!** ✅

Your SmartMess app is ready to connect to Firebase.
