# SmartMess Setup Verification Checklist

Your task: Go through each item and **verify it's correct**. This will help us find the real blocking issue.

---

## 1. Firebase Project Created & Configured

- [ ] Go to [Firebase Console](https://console.firebase.google.com)
- [ ] **Find your project**: Look for "smartmess-project" (or your project name)
- [ ] If NOT found: **CREATE a new Firebase project** named "smartmess-project"
- [ ] In Firebase, go to **Project Settings** → Copy your **Project ID** (e.g., `smartmess-project`)

**Verify:**
```
Your Firebase Project ID: ___________________________
```

---

## 2. Web App Registration in Firebase

- [ ] In Firebase Console, go to **Project Settings** → **Your apps** section
- [ ] Look for a **Web App** entry (should show `</>` icon)
- [ ] If NOT found: Click **"Add app"** → Select **"Web"** → Register it
- [ ] **Important:** Copy the Firebase config (you'll need this)

**Your Firebase Web Config should contain:**
```javascript
{
  apiKey: "AIzaSy...",
  authDomain: "smartmess-project.firebaseapp.com",
  projectId: "smartmess-project",
  storageBucket: "smartmess-project.appspot.com",
  messagingSenderId: "...",
  appId: "1:...:web:...",
}
```

---

## 3. Firestore Database Created

- [ ] In Firebase Console, go to **Firestore Database** (left sidebar)
- [ ] If you see "Create Database" button: **CLICK IT**
- [ ] Choose: **Start in test mode** (important for development)
- [ ] Choose location: **US (us-central1)** (or closest to you)
- [ ] **Wait for it to finish** (2-5 minutes)

**Verify:**
```
Firestore Status: [ ] CREATED AND RUNNING
```

---

## 4. Create Test Data in Firestore

- [ ] In Firestore Console, click **"Create collection"**
- [ ] Collection name: `messes`
- [ ] Click **"Auto ID"** to create first document
- [ ] Add these fields:

```
Field Name      | Type    | Value
----------------|---------|----------------------------------
name            | String  | "Test Mess 1"
capacity        | Number  | 50
latitude        | Number  | 28.7041
longitude       | Number  | 77.1025
imageUrl        | String  | "https://via.placeholder.com/300"
```

- [ ] **Save the document**
- [ ] Create **at least 2 more** test messes with different names

**Verify:**
```
Messes Collection exists: [ ]
Contains at least 1 document: [ ]
```

---

## 5. Check firebase_options.dart File

- [ ] Open: `frontend/lib/firebase_options.dart`
- [ ] Check that `defaultFirebaseOptions` for **Web** has:
  - `projectId: "smartmess-project"` (or your project ID)
  - `apiKey` is not empty
  - `authDomain` matches your Firebase project
  - `storageBucket` is not empty

**If values are WRONG or EMPTY:**
- Run this command to regenerate it:
```bash
cd frontend
flutterfire configure --project=smartmess-project
```

---

## 6. Firebase Authentication - Enable Anonymous Sign-in

- [ ] In Firebase Console, go to **Authentication** (left sidebar)
- [ ] Click **"Get Started"** if you see it
- [ ] Go to **Sign-in method** tab
- [ ] Look for **"Anonymous"** 
- [ ] Click on it and **toggle the switch to ENABLED** (blue)
- [ ] Click **"Save"**

**Verify:**
```
Anonymous Authentication: [ ] ENABLED
```

---

## 7. Firestore Security Rules

- [ ] In Firestore Console, go to **Rules** tab
- [ ] Replace everything with this code:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

- [ ] Click **"Publish"**
- [ ] **Wait for it to deploy** (usually 30 seconds)

**Verify:**
```
Rules Status: [ ] PUBLISHED
```

---

## 8. Internet Connection

- [ ] Open browser (Edge)
- [ ] Go to [google.com](https://google.com) - does it load?
- [ ] Go to [firebase.google.com](https://firebase.google.com) - does it load?

**Verify:**
```
Internet Working: [ ]
```

---

## 9. App Cache Issue (Browser)

- [ ] In your Flutter app running in Edge:
  - Press **F12** (open Developer Tools)
  - Right-click the **Refresh button** → Select **"Empty cache and hard refresh"**
  - Or press **Ctrl + Shift + Delete** to clear browser cache completely

---

## 10. Check Browser Console for Errors

After clearing cache and refreshing:

- [ ] Press **F12** in Edge browser
- [ ] Go to **Console** tab
- [ ] Look for RED ERROR messages
- [ ] **Screenshot or copy the exact error message**
- [ ] Share the error message with the developer

**Expected errors (if any):**
```
If you see messages like:
- "Firebase initialization failed"
- "Network error"
- "Permission denied" 
- "Firestore error"

Copy the EXACT message and report it.
```

---

## Summary: What Should Happen

**After completing all above steps, when you reload the app:**

1. ✅ Splash screen shows "Authenticating..."
2. ✅ After 1-2 seconds, shows a list of messes (your test data)
3. ✅ You can click a mess to view the dashboard

**If this doesn't happen:**
- Check the Console (F12) for the actual error
- Share the error message with the developer

---

## Command to Regenerate Firebase Config (if needed)

If any values in `firebase_options.dart` are wrong:

```bash
cd d:\CodePlayground\Flutter\Projects\SmartMess\code\frontend

# Install flutterfire_cli if you don't have it
dart pub global activate flutterfire_cli

# Regenerate firebase_options.dart
flutterfire configure --project=smartmess-project
```

Then run:
```bash
flutter run -d edge
```

---

## Quick Checklist (Copy & Fill)

```
Firebase Project Exists: [ ]
Web App Registered: [ ]
Firestore Database Created: [ ]
Test Data Added: [ ]
firebase_options.dart Correct: [ ]
Anonymous Auth ENABLED: [ ]
Firestore Rules PUBLISHED: [ ]
Internet Working: [ ]
Browser Cache CLEARED: [ ]
```

**Once ALL boxes are checked ✅, refresh the app and it should work!**
