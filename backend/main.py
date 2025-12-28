import os
import sys
from datetime import datetime, timedelta, time

from flask import Flask, request, jsonify
from flask_cors import CORS

# ------------------------------------------------------------
# App init
# ------------------------------------------------------------

app = Flask(__name__)

CORS(
    app,
    resources={r"/*": {
        "origins": [
            "https://smartmess-project.web.app",
            "https://smartmess-project.firebaseapp.com",
            "http://localhost:5173",
            "http://localhost:3000",
            "http://127.0.0.1:5173",
            "http://127.0.0.1:3000",
        ],
        "methods": ["GET", "POST", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"],
    }},
)

# ------------------------------------------------------------
# Optional ML import (NON-FATAL)
# ------------------------------------------------------------

PredictionService = None
try:
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "ml_model"))
    from prediction_model_tf import PredictionService  # type: ignore
except Exception as e:
    print("[WARN] PredictionService unavailable:", e)

# ------------------------------------------------------------
# Constants
# ------------------------------------------------------------

MEAL_WINDOWS = {
    "breakfast": (time(7, 30), time(9, 30)),
    "lunch": (time(12, 0), time(14, 0)),
    "dinner": (time(19, 30), time(21, 30)),
}

SLOT_MINUTES = 15

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

def round_up_to_next_slot(dt: datetime) -> datetime:
    minute = (dt.minute // SLOT_MINUTES) * SLOT_MINUTES
    slot = dt.replace(minute=minute, second=0, microsecond=0)
    if slot <= dt:
        slot += timedelta(minutes=SLOT_MINUTES)
    return slot


def generate_slots_for_meal(meal_type: str, slots=5):
    if meal_type not in MEAL_WINDOWS:
        return []

    now = datetime.now()
    start_t, end_t = MEAL_WINDOWS[meal_type]

    today_start = now.replace(
        hour=start_t.hour, minute=start_t.minute, second=0, microsecond=0
    )
    today_end = now.replace(
        hour=end_t.hour, minute=end_t.minute, second=0, microsecond=0
    )

    if now > today_end:
        return []

    cursor = max(round_up_to_next_slot(now), today_start)

    results = []
    while cursor < today_end and len(results) < slots:
        results.append(cursor)
        cursor += timedelta(minutes=SLOT_MINUTES)

    return results


def generate_fallback_predictions(meal_type, capacity=100):
    slots = generate_slots_for_meal(meal_type)

    predictions = []
    base_pct = {
        "breakfast": 25,
        "lunch": 40,
        "dinner": 45,
    }.get(meal_type, 20)

    for idx, t in enumerate(slots):
        pct = min(90, base_pct + idx * 6)

        predictions.append({
            "time_slot": t.strftime("%I:%M %p"),
            "time_24h": t.strftime("%H:%M"),
            "predicted_crowd": int(capacity * pct / 100),
            "crowd_percentage": float(pct),
            "capacity": capacity,
            "confidence": "low",
            "recommendation": (
                "Good time"
                if pct < 40 else
                "Moderate crowd"
                if pct < 70 else
                "Avoid if possible"
            )
        })

    return predictions


# ------------------------------------------------------------
# Health
# ------------------------------------------------------------

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat(),
    })

# ------------------------------------------------------------
# Predict
# ------------------------------------------------------------

@app.route("/predict", methods=["POST", "OPTIONS"])
def predict():
    if request.method == "OPTIONS":
        return "", 204

    try:
        payload = request.get_json(force=True, silent=True) or {}

        mess_id = payload.get("messId", "alder")
        meal_type = payload.get("mealType", "lunch")
        capacity = int(payload.get("capacity", 100))

        # ----------------------------------------------------
        # Try ML first
        # ----------------------------------------------------
        if PredictionService is not None:
            try:
                service = PredictionService(mess_id)
                result = service.predict_next_slots(meal_type=meal_type)

                if result and result.get("predictions"):
                    return jsonify({
                        "source": "ml-model",
                        "fallback": False,
                        **result,
                    })
            except Exception as e:
                print("[WARN] ML prediction failed:", e)

        # ----------------------------------------------------
        # Fallback (meal-aware)
        # ----------------------------------------------------
        predictions = generate_fallback_predictions(meal_type, capacity)

        return jsonify({
            "source": "fallback",
            "fallback": True,
            "messId": mess_id,
            "mealType": meal_type,
            "capacity": capacity,
            "current_crowd": 0,
            "current_percentage": 0.0,
            "predictions": predictions,
            "timestamp": datetime.utcnow().isoformat(),
        })

    except Exception as e:
        return jsonify({
            "error": "prediction_failed",
            "details": str(e),
        }), 500


# ------------------------------------------------------------
# Entry
# ------------------------------------------------------------

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
