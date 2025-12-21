Perfect — **Flutter Web website** + **AI prediction as PRIMARY goal** changes the plan. Below is a **crisp 5-day MVP roadmap**, **2-person split**, **primary aim first**, **secondary aim later**, and **beginner learning list** (no code).

---

# MVP (what you will actually ship)

## ✅ Primary (must be done by Day 3)

1. **Crowd input** (QR scan on web + fallback manual)
2. **Store scans** (real-time DB)
3. **AI prediction** → “Best time to eat” (next low-crowd slot)
4. **Crowd dashboard** (current crowd + predicted best time)

## ✅ Secondary (Day 4–5)

5. **Menu of the day**
6. **Feedback (1–5) + real-time average**

## ✅ Minimal Maps usage (to satisfy “Maps API”)

7. A simple **Map page** with mess marker(s) (even one marker is enough)

---

# Tech Stack (Beginner-safe, Google stack)

* **Flutter Web** (UI)
* **Firebase Auth (Anonymous)** (easy login)
* **Cloud Firestore** (real-time data)
* **TensorFlow (Python)** for training
* **Model Serving on GCP**: **Cloud Run** (simple REST API for prediction)
* **Maps API**: Google Map embed / Flutter web map plugin (minimal page)

> Why Cloud Run: You know Python; serving prediction via REST is easier than trying to run TFLite inside Flutter Web.

---

# Firestore (fixed schema — keep it simple)

* `messes` → `{name, capacity, lat, lng}`
* `users` → `{homeMessId}`
* `scans` → `{uid, messId, ts}`
* `menus` → `{messId, date, items[]}`
* `rating_summary` → `{count, sum, avg}`

---

# What beginners must learn (only what you need)

## Flutter Web

* Widgets basics + layout
* **Navigation** (pages)
* **State** (setState / simple provider)
* **HTTP calls** (calling Cloud Run API)
* **Web build + deploy** (Firebase Hosting)

## Firebase

* Firebase project setup
* **Anonymous Auth**
* Firestore: collections/docs
* **Real-time listeners**
* **Timestamp queries** (last 10 min)
* **Transactions** (for rating avg)

## AI (TensorFlow)

* Dataset creation (time buckets)
* Simple regression model (no deep learning hype)
* Export model artifact
* Basic evaluation (MAE / simple error)

## GCP

* **Cloud Run** basics (deploy a Python API)
* CORS basics (so Flutter web can call API)
* API endpoints concept (`/predict`)

## Maps API (minimal)

* Create API key
* Show map with mess marker(s)

---

# 5-Day MVP Roadmap (2 people split)

## ✅ Day 1 — Setup + Data Pipeline Base (Primary Aim starts)

### Learn (key terms)

* Flutter Web project setup
* Firebase Auth (Anonymous)
* Firestore read/write
* Firebase Hosting basics

### Build (deliverable)

* Flutter Web pages (skeleton):

  * Home (select mess)
  * Scan/Input page
  * Crowd + Prediction page
* Firebase:

  * Anonymous login
  * Store `homeMessId` in `users`
* Seed Firestore:

  * Add `messes` (capacity + location)

### Split

* **Person A (Frontend):** Flutter Web setup + page skeleton + navigation
* **Person B (Backend/Data):** Firebase project + Auth + Firestore schema + seed messes

**Day 1 output:** Website runs, Firebase connected, mess selection stored.

---

## ✅ Day 2 — Crowd Input (QR on Web) + Live Crowd Calculation (Primary)

### Learn

* QR scanning on web (camera permissions) **OR** fallback manual input
* Firestore real-time listeners
* Timestamp filtering (“last 10 minutes”)

### Build

* **Crowd input method (MVP)**

  * Preferred: QR scan → get `messId`
  * Fallback: “I entered mess” button / manual mess select (if QR web camera acts up)
* Log scans to Firestore: `scans`
* Live crowd metric:

  * **scans in last 10 min / capacity**
  * Show Low/Med/High badge
* Basic “current crowd dashboard” page

### Split

* **Person A:** QR/input UI + validation (Allowed/Not Allowed)
* **Person B:** Firestore scan logging + real-time crowd query

**Day 2 output:** Crowd shown live from scans.

---

## ✅ Day 3 — AI Prediction (PRIMARY GOAL) + Integration (Primary completes)

### Learn

* “Time bucket” dataset (15-min intervals)
* Simple regression / small NN in TensorFlow
* Cloud Run deployment concept
* REST API call from Flutter Web
* CORS concept

### Build (minimum AI that counts)

1. **Create dataset**

   * Convert scans into counts per **15-min bucket**
   * Features (simple):

     * `hour`, `minute_bucket`, `day_of_week` (optional)
   * Target:

     * predicted crowd ratio / predicted crowd count

2. **Train simple model**

   * Regression model (keep it lightweight)
   * Save model artifact

3. **Deploy prediction API (Cloud Run)**

   * Endpoint: `/predict`
   * Input: `messId + current time`
   * Output: predicted crowd for next few buckets + “best time slot”

4. **Integrate in Flutter Web**

   * Call API
   * Display:

     * “Best time to eat: ____”
     * “Predicted crowd: ____”
   * Keep current crowd + predicted best slot on same page

### Split

* **Person A:** Flutter UI for prediction results + API integration page
* **Person B:** Dataset + TensorFlow training + Cloud Run predict API

**Day 3 output:** Working AI prediction shown in demo (primary aim achieved).

---

## ✅ Day 4 — Secondary Aim 1: Menu + Minimal Maps API

### Learn

* Firestore document per day strategy (messId_date)
* Basic map embedding / markers (minimal)

### Build

* **Menu page**

  * Read today’s menu from Firestore
* **Maps page (minimal requirement)**

  * Show map + mess marker(s)
  * Optional: show crowd label on marker click

### Split

* **Person A:** Menu UI + Map page UI
* **Person B:** Firestore menu read + Maps API key setup + seed menu docs

**Day 4 output:** Menu works + Maps API used.

---

## ✅ Day 5 — Secondary Aim 2: Feedback + Real-time Avg + Submission Pack

### Learn

* Firestore transaction
* Demo recording flow
* Writing a clean README

### Build

* **Feedback page**

  * Rating 1–5 submit
* **Real-time average**

  * Update `rating_summary` using transaction
  * Display avg live
* **Polish MVP**

  * Loading states
  * Empty states (no scans/menu yet)
* **Submission assets**

  * GitHub repo with README
  * Working demo (recorded)
  * Tech stack + defined solution text

### Split

* **Person A:** Feedback UI + polish + demo flow practice
* **Person B:** rating_summary transaction + README + final deployment (Firebase Hosting)

**Day 5 output:** Full MVP ready + submission-ready.

---

# Minimal Demo Flow (2 minutes, MVP-friendly)

1. Select mess
2. QR/manual input → scan logged
3. Crowd updates live
4. AI predicts best time slot
5. Show menu
6. Submit rating → average updates
7. Show map page (marker)

---

# Important MVP Rule (so you don’t get stuck)

If QR scan on Flutter Web becomes messy due to camera permissions:
✅ Keep **manual “I entered Mess A”** button as fallback
(Still MVP-valid; you can mention QR as planned/partially working.)

---

If you tell me **team size exactly = 2** confirmed and your **preferred AI style**:

* **(A)** “predict crowd next hour” or
* **(B)** “recommend best time slot”
  …I’ll convert Day 3 into an even tighter checklist (inputs/outputs + what pages show).