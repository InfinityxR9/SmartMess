import os
import sys
import threading
from flask import Flask, request, jsonify
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import numpy as np
import json

# Add ml_model to path for TensorFlow model imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'ml_model'))
from prediction_model_tf import PredictionService

app = Flask(__name__)

# Configure CORS properly for all origins
CORS(app, resources={
    r"/*": {
        "origins": ["*"],
        "methods": ["GET", "POST", "OPTIONS", "DELETE", "PUT"],
        "allow_headers": ["Content-Type", "Authorization"]
    }
})

# Add after-request handler for CORS headers
@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS, DELETE, PUT'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
    return response

# Initialize Firebase
try:
    # Prefer bundled service account; fall back to ADC if needed
    service_account_path = os.path.join(os.path.dirname(__file__), 'serviceAccountKey.json')
    if os.path.exists(service_account_path):
        cred = credentials.Certificate(service_account_path)
    elif os.path.exists('serviceAccountKey.json'):
        cred = credentials.Certificate('serviceAccountKey.json')
    else:
        cred = credentials.ApplicationDefault()
    
    firebase_admin.initialize_app(cred)
    db = firestore.client()
except Exception as e:
    print(f"Warning: Firebase initialization failed: {e}")
    db = None

# Initialize TensorFlow prediction service (mess-specific models)
prediction_service = PredictionService()
FIRESTORE_AVAILABLE = True
_TRAINING_IN_PROGRESS = set()

def _disable_firestore_if_needed(error):
    global FIRESTORE_AVAILABLE
    if not FIRESTORE_AVAILABLE:
        return
    message = str(error).lower()
    tokens = [
        'invalid_grant',
        'access_token_expired',
        'invalid authentication credentials',
        'unauthenticated',
        'permission denied',
        'token must be',
        'jwt',
        'metadata',
        'oauth',
        '401',
    ]
    if any(token in message for token in tokens):
        FIRESTORE_AVAILABLE = False
        print("[WARN] Firestore disabled due to credential error. Falling back to dummy data.")

def _start_background_training(
    mess_id,
    meal_type,
    days_back,
    minutes_back,
    current_time,
    dev_mode,
    force_train,
):
    key = f"{mess_id}:{meal_type}"
    if key in _TRAINING_IN_PROGRESS:
        return

    _TRAINING_IN_PROGRESS.add(key)

    def _runner():
        try:
            train_mess_model(
                mess_id=mess_id,
                meal_type=meal_type,
                days_back=days_back,
                minutes_back=minutes_back,
                current_time=current_time,
                dev_mode=dev_mode,
                force_train=force_train,
            )
        finally:
            _TRAINING_IN_PROGRESS.discard(key)

    thread = threading.Thread(target=_runner, daemon=True)
    thread.start()

def _has_recent_model(mess_id, max_age_minutes=60):
    """Check if a recent trained model exists for this mess."""
    metadata_path = os.path.join(
        os.path.dirname(__file__), '..', 'ml_model', 'models', f'{mess_id}_metadata.json'
    )
    if not os.path.exists(metadata_path):
        return False
    try:
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
        trained_at = metadata.get('trained_at')
        if not trained_at:
            return False
        trained_time = datetime.fromisoformat(trained_at)
        return datetime.now() - trained_time < timedelta(minutes=max_age_minutes)
    except Exception:
        return False

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'}), 200

def get_meal_type_exact(hour, minute):
    """Get exact meal type based on precise time windows"""
    # Breakfast: 7:30-9:30, Lunch: 12:00-14:00, Dinner: 19:30-21:30 (exclusive end times)
    if 7 < hour < 9 or (hour == 7 and minute >= 30) or (hour == 9 and minute < 30):
        return 'breakfast'
    elif 12 <= hour < 14 or (hour == 14 and minute == 0):
        return 'lunch'
    elif 19 < hour < 21 or (hour == 19 and minute >= 30) or (hour == 21 and minute < 30):
        return 'dinner'
    return None

MEAL_WINDOWS = {
    'breakfast': (7, 30, 9, 30),
    'lunch': (12, 0, 14, 0),
    'dinner': (19, 30, 21, 30),
}

def normalize_meal_type(meal_type):
    if not meal_type:
        return None
    normalized = str(meal_type).strip().lower()
    return normalized if normalized in MEAL_WINDOWS else None

def parse_capacity(value):
    try:
        if value is None:
            return None
        if isinstance(value, bool):
            return None
        capacity = int(value)
        return capacity if capacity > 0 else None
    except Exception:
        return None

def _parse_marked_at(value):
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    if hasattr(value, 'to_datetime'):
        try:
            return value.to_datetime()
        except Exception:
            return None
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace('Z', '+00:00'))
        except Exception:
            return None
    return None

def get_slot_window(current_time, meal_type):
    window = MEAL_WINDOWS.get(meal_type)
    if not window:
        return None, None
    start_h, start_m, end_h, end_m = window
    slot_start = current_time.replace(hour=start_h, minute=start_m, second=0, microsecond=0)
    slot_end = current_time.replace(hour=end_h, minute=end_m, second=0, microsecond=0)
    return slot_start, slot_end

def load_attendance_records(mess_id, meal_type, days_back=30):
    """Load attendance records for a mess and specific meal slot over past days."""
    if not db or not FIRESTORE_AVAILABLE:
        return []
    records = []
    now = datetime.now()

    for day_offset in range(days_back):
        date_str = (now - timedelta(days=day_offset)).strftime('%Y-%m-%d')
        try:
            date_collection = db.collection('attendance').document(mess_id).collection(date_str)
            if meal_type:
                meal_doc = date_collection.document(meal_type)
                students_ref = meal_doc.collection('students')
                students = students_ref.stream()
                for student_doc in students:
                    data = student_doc.to_dict() or {}
                    marked_at = data.get('markedAt')
                    if hasattr(marked_at, 'isoformat'):
                        marked_at = marked_at.isoformat()
                    records.append({
                        'enrollmentId': data.get('enrollmentId') or student_doc.id,
                        'studentName': data.get('studentName', 'Anonymous'),
                        'markedAt': marked_at,
                        'markedBy': data.get('markedBy', 'unknown'),
                        'messId': mess_id,
                        'meal': meal_type,
                        'date': date_str
                    })
            else:
                for meal_doc in date_collection.stream():
                    students_ref = meal_doc.reference.collection('students')
                    students = students_ref.stream()
                    for student_doc in students:
                        data = student_doc.to_dict() or {}
                        marked_at = data.get('markedAt')
                        if hasattr(marked_at, 'isoformat'):
                            marked_at = marked_at.isoformat()
                        records.append({
                            'enrollmentId': data.get('enrollmentId') or student_doc.id,
                            'studentName': data.get('studentName', 'Anonymous'),
                            'markedAt': marked_at,
                            'markedBy': data.get('markedBy', 'unknown'),
                            'messId': mess_id,
                            'meal': meal_doc.id,
                            'date': date_str
                        })
        except Exception as e:
            _disable_firestore_if_needed(e)
            continue

    return records

def load_recent_attendance_records(mess_id, meal_type, minutes_back=15, current_time=None):
    """Load attendance records from the last N minutes for today's slot."""
    if not db or not FIRESTORE_AVAILABLE or not meal_type:
        return []
    if minutes_back <= 0:
        return []
    now = current_time or datetime.now()
    window_start = now - timedelta(minutes=minutes_back)
    date_str = now.strftime('%Y-%m-%d')
    records = []

    try:
        students_ref = (
            db.collection('attendance')
            .document(mess_id)
            .collection(date_str)
            .document(meal_type)
            .collection('students')
        )
        students = students_ref.stream()
        for student_doc in students:
            data = student_doc.to_dict() or {}
            marked_at_raw = data.get('markedAt')
            marked_at_dt = _parse_marked_at(marked_at_raw)
            if not marked_at_dt:
                continue
            if marked_at_dt.tzinfo is not None:
                marked_at_dt = marked_at_dt.astimezone(tz=None).replace(tzinfo=None)
            if marked_at_dt < window_start or marked_at_dt > now:
                continue
            records.append({
                'enrollmentId': data.get('enrollmentId') or student_doc.id,
                'studentName': data.get('studentName', 'Anonymous'),
                'markedAt': marked_at_dt.isoformat(),
                'markedBy': data.get('markedBy', 'unknown'),
                'messId': mess_id,
                'meal': meal_type,
                'date': date_str
            })
    except Exception as e:
        _disable_firestore_if_needed(e)

    return records

def train_mess_model(
    mess_id,
    meal_type,
    days_back=30,
    minutes_back=None,
    current_time=None,
    dev_mode=False,
    force_train=True,
):
    training_info = {
        'trained': False,
        'records': 0,
        'usedDummy': False,
        'skippedRecent': False,
    }
    if not meal_type:
        return training_info

    try:
        if minutes_back is None and not force_train and _has_recent_model(mess_id, max_age_minutes=60):
            training_info['skippedRecent'] = True
            return training_info

        attendance_records = []
        if db and FIRESTORE_AVAILABLE:
            if minutes_back is not None:
                attendance_records = load_recent_attendance_records(
                    mess_id=mess_id,
                    meal_type=meal_type,
                    minutes_back=minutes_back,
                    current_time=current_time,
                )
                training_info['windowMinutes'] = minutes_back
                if not attendance_records:
                    attendance_records = load_attendance_records(
                        mess_id=mess_id,
                        meal_type=meal_type,
                        days_back=days_back,
                    )
                    if attendance_records:
                        training_info['fallbackDays'] = days_back
            else:
                attendance_records = load_attendance_records(
                    mess_id=mess_id,
                    meal_type=meal_type,
                    days_back=days_back
                )
            training_info['records'] = len(attendance_records)

        if not attendance_records and dev_mode and minutes_back is None:
            from train_tensorflow import generate_dummy_attendance_data
            attendance_records = generate_dummy_attendance_data(mess_id, days=7)
            training_info['records'] = len(attendance_records)
            training_info['usedDummy'] = True

        if attendance_records:
            from train_tensorflow import MessCrowdRegressor
            regressor = MessCrowdRegressor(mess_id)
            training_info['trained'] = regressor.train(attendance_records)
            if training_info['trained']:
                prediction_service.models_cache.pop(mess_id, None)
                print(f"[OK] Trained model for {mess_id} ({meal_type}) with {len(attendance_records)} records")
            else:
                print(f"[WARN] Training skipped for {mess_id} due to insufficient data")
        else:
            print(f"[WARN] No historical data for {mess_id} ({meal_type}); using existing model")
    except Exception as e:
        _disable_firestore_if_needed(e)
        print(f"[WARN] Training failed for {mess_id}: {e}")

    return training_info

@app.route('/predict', methods=['POST', 'OPTIONS'])
def predict():
    """
    Real-time crowd prediction with slot-aware training
    Trains model on recent historical data for the selected slot
    Uses mess-specific TensorFlow models for isolation
    Expected input: {'messId': 'mess_id', 'devMode': True/False, 'slot': 'breakfast|lunch|dinner', 'minutesBack': 15}
    Returns: Predictions for current and next 15-minute slots
    
    Data Structure: attendance/<messId>/<date>/<meal>/students
    Ensures all predictions are mess-isolated using separate trained models
    """
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.get_json() or {}
        mess_id = data.get('messId')
        dev_mode = data.get('devMode', False)  # Allow predictions outside meal times in dev mode
        requested_slot = normalize_meal_type(data.get('slot') or data.get('mealType'))
        force_train = bool(data.get('forceTrain', False))
        auto_train = bool(data.get('autoTrain', True))
        async_train = bool(data.get('asyncTrain', True))
        try:
            days_back = max(1, int(data.get('daysBack', 30)))
        except Exception:
            days_back = 30
        try:
            minutes_back = data.get('minutesBack')
            minutes_back = int(minutes_back) if minutes_back is not None else None
            if minutes_back is not None and minutes_back <= 0:
                minutes_back = None
        except Exception:
            minutes_back = None
        try:
            minutes_back = data.get('minutesBack')
            minutes_back = int(minutes_back) if minutes_back is not None else None
            if minutes_back is not None and minutes_back <= 0:
                minutes_back = None
        except Exception:
            minutes_back = None
        
        if not mess_id:
            return jsonify({'error': 'messId is required'}), 400
        if (data.get('slot') or data.get('mealType')) and not requested_slot:
            return jsonify({'error': 'Invalid slot. Use breakfast, lunch, or dinner.'}), 400
        
        # Get current time and calculate 15-minute slot
        current_time = datetime.now()
        hour = current_time.hour
        minute = current_time.minute
        
        # Get exact meal type using precise windows
        meal_type = requested_slot or get_meal_type_exact(hour, minute)
        
        # Check if outside meal hours
        if not meal_type and not dev_mode and not requested_slot:
            return jsonify({
                'warning': 'Outside meal hours',
                'messId': mess_id,
                'currentTime': current_time.isoformat(),
                'predictions': []
            }), 200
        
        # If outside meal hours in dev mode, use nearest meal
        if not meal_type and dev_mode:
            if hour < 12:
                meal_type = 'breakfast'
            elif hour < 19:
                meal_type = 'lunch'
            else:
                meal_type = 'dinner'

        # If a slot was requested, ensure we predict within that window
        if requested_slot:
            meal_type = requested_slot
            slot_start, slot_end = get_slot_window(current_time, meal_type)
            if slot_start and slot_end and not (slot_start <= current_time <= slot_end):
                current_time = slot_start

        date_str = current_time.strftime('%Y-%m-%d')
        
        # Get current attendance count (optionally limited to recent minutes)
        current_count = 0
        
        if db and FIRESTORE_AVAILABLE:
            try:
                if minutes_back is not None:
                    recent_records = load_recent_attendance_records(
                        mess_id=mess_id,
                        meal_type=meal_type,
                        minutes_back=minutes_back,
                        current_time=current_time,
                    )
                    current_count = len(recent_records)
                else:
                    students_ref = (
                        db.collection('attendance')
                        .document(mess_id)
                        .collection(date_str)
                        .document(meal_type)
                        .collection('students')
                    )
                    students = students_ref.stream()
                    current_count = sum(1 for _ in students)
            except Exception as e:
                _disable_firestore_if_needed(e)
                print(f"[WARN] Could not get current attendance: {e}")
                current_count = 0
        
        # Get mess capacity (require override to avoid Firestore auth delays)
        capacity_override = parse_capacity(data.get('capacity'))
        capacity = capacity_override if capacity_override is not None else 100

        training_info = {'trained': False, 'records': 0, 'usedDummy': False, 'skippedRecent': False}
        should_train = auto_train and meal_type and (
            minutes_back is not None or force_train or not _has_recent_model(mess_id)
        )
        if should_train:
            if async_train:
                _start_background_training(
                    mess_id=mess_id,
                    meal_type=meal_type,
                    days_back=days_back,
                    minutes_back=minutes_back,
                    current_time=current_time,
                    dev_mode=dev_mode,
                    force_train=force_train,
                )
                training_info['queued'] = True
            else:
                training_info = train_mess_model(
                    mess_id=mess_id,
                    meal_type=meal_type,
                    days_back=days_back,
                    minutes_back=minutes_back,
                    current_time=current_time,
                    dev_mode=dev_mode,
                    force_train=force_train,
                )
        
        # Use mess-specific TensorFlow model for predictions
        result = prediction_service.predict_next_slots(
            mess_id=mess_id,
            current_time=current_time,
            current_count=current_count,
            capacity=capacity
        )
        
        # Check for model loading errors
        if 'error' in result:
            return jsonify({
                'warning': result['error'],
                'messId': mess_id,
                'predictions': [],
                'training': training_info,
                'message': f'Model not yet trained for {mess_id}. Run: python train_tensorflow.py {mess_id}'
            }), 200
        
        predictions = result.get('predictions') or []
        best_slot = None
        if predictions:
            best_slot = min(
                predictions,
                key=lambda p: p.get('crowd_percentage', p.get('predicted_crowd', 0)),
            )

        result['meal_type'] = meal_type
        result['training'] = training_info
        if best_slot:
            result['best_slot'] = best_slot
        result['slot_minute'] = (current_time.minute // 15) * 15
        return jsonify(result), 200
        
    except Exception as e:
        print(f"[ERROR] predict: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/train', methods=['POST'])
def train_model():
    """
    Endpoint to train mess-specific TensorFlow models
    POST body: {'messId': 'mess_id', 'slot': 'breakfast|lunch|dinner', 'daysBack': 30, 'minutesBack': 15}
    """
    try:
        data = request.get_json() or {}
        mess_id = data.get('messId')
        requested_slot = normalize_meal_type(data.get('slot') or data.get('mealType'))
        force_train = bool(data.get('forceTrain', True))
        dev_mode = bool(data.get('devMode', False))
        async_train = bool(data.get('asyncTrain', True))
        try:
            days_back = max(1, int(data.get('daysBack', 30)))
        except Exception:
            days_back = 30
        try:
            minutes_back = data.get('minutesBack')
            minutes_back = int(minutes_back) if minutes_back is not None else None
            if minutes_back is not None and minutes_back <= 0:
                minutes_back = None
        except Exception:
            minutes_back = None
        
        if not mess_id:
            return jsonify({
                'error': 'messId is required'
            }), 400

        current_time = datetime.now()
        meal_type = requested_slot or get_meal_type_exact(current_time.hour, current_time.minute)

        if not meal_type and dev_mode:
            hour = current_time.hour
            if hour < 12:
                meal_type = 'breakfast'
            elif hour < 19:
                meal_type = 'lunch'
            else:
                meal_type = 'dinner'

        if not meal_type:
            return jsonify({
                'messId': mess_id,
                'warning': 'Outside meal hours. Provide slot to train.',
                'training': {'trained': False, 'records': 0}
            }), 200

        training_info = {'trained': False, 'records': 0}
        should_train = minutes_back is not None or force_train or not _has_recent_model(mess_id)
        if async_train and should_train:
            _start_background_training(
                mess_id=mess_id,
                meal_type=meal_type,
                days_back=days_back,
                minutes_back=minutes_back,
                current_time=current_time,
                dev_mode=dev_mode,
                force_train=force_train,
            )
            training_info['queued'] = True
        else:
            training_info = train_mess_model(
                mess_id=mess_id,
                meal_type=meal_type,
                days_back=days_back,
                minutes_back=minutes_back,
                current_time=current_time,
                dev_mode=dev_mode,
                force_train=force_train,
            )

        model = prediction_service.get_prediction_model(mess_id)
        model_info = model.get_model_info() if model else {'trained': False}

        return jsonify({
            'messId': mess_id,
            'mealType': meal_type,
            'training': training_info,
            'modelInfo': model_info
        }), 200
            
    except Exception as e:
        print(f"Error in train: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/manager-info', methods=['GET'])
def manager_info():
    """Get manager information for a mess"""
    try:
        mess_id = request.args.get('messId')
        
        if not mess_id:
            return jsonify({'error': 'messId required'}), 400

        if not db or not FIRESTORE_AVAILABLE:
            return jsonify({
                'messId': mess_id,
                'managerName': 'Not Set',
                'managerEmail': 'Not Set',
                'messName': mess_id,
                'capacity': 100,
                'warning': 'Firestore unavailable'
            }), 200
        
        try:
            # Get manager info from messes collection
            mess_doc = db.collection('messes').document(mess_id).get()
            if mess_doc.exists:
                mess_data = mess_doc.to_dict()
                return jsonify({
                    'messId': mess_id,
                    'managerName': mess_data.get('managerName', 'Not Set'),
                    'managerEmail': mess_data.get('managerEmail', 'Not Set'),
                    'messName': mess_data.get('name', mess_id),
                    'capacity': mess_data.get('capacity', 100)
                }), 200
            else:
                return jsonify({'error': 'Mess not found'}), 404
        except Exception as e:
            _disable_firestore_if_needed(e)
            print(f"[ERROR] Getting manager info: {e}")
            return jsonify({'error': str(e)}), 500
            
    except Exception as e:
        print(f"[ERROR] manager-info: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/analytics', methods=['GET', 'OPTIONS'])
def analytics():
    """
    Get analytics data for a mess
    Available to both managers and students
    Shows attendance and reviews for specific date/slot
    """
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        mess_id = request.args.get('messId')
        date_param = request.args.get('date')
        slot_param = request.args.get('slot')
        
        if not mess_id:
            return jsonify({'error': 'messId required'}), 400
        
        if slot_param:
            slot_param = normalize_meal_type(slot_param)
            if not slot_param:
                return jsonify({'error': 'Invalid slot. Use breakfast, lunch, or dinner.'}), 400

        # Default to today and current slot if not specified
        if not date_param:
            current_time = datetime.now()
            date_param = current_time.strftime('%Y-%m-%d')

        if not slot_param:
            current_time = datetime.now()
            slot_param = get_meal_type_exact(current_time.hour, current_time.minute)

            if not slot_param:
                return jsonify({
                    'messId': mess_id,
                    'date': date_param,
                    'slot': '',
                    'attendance': [],
                    'totalAttendance': 0,
                    'crowdPercentage': 0,
                    'reviews': [],
                    'reviewCount': 0,
                    'averageRating': 0,
                    'warning': 'Outside meal hours. Provide slot to view analytics.'
                }), 200

        if not db or not FIRESTORE_AVAILABLE:
            return jsonify({
                'messId': mess_id,
                'date': date_param,
                'slot': slot_param,
                'attendance': [],
                'totalAttendance': 0,
                'crowdPercentage': 0,
                'reviews': [],
                'reviewCount': 0,
                'averageRating': 0,
                'warning': 'Firestore unavailable'
            }), 200
        
        try:
            # Get mess capacity
            mess_doc = db.collection('messes').document(mess_id).get()
            capacity = mess_doc.get('capacity', 100) if mess_doc.exists else 100
            
            # Get attendance for this date and slot
            attendance_ref = db.collection('attendance').document(mess_id).collection(date_param).document(slot_param).collection('students')
            attendance_docs = attendance_ref.stream()
            
            attendance_list = []
            for doc in attendance_docs:
                data = doc.to_dict()
                attendance_list.append({
                    'enrollmentId': data.get('enrollmentId', 'Anonymous'),
                    'studentName': data.get('studentName', 'Anonymous'),
                    'markedAt': data.get('markedAt', ''),
                    'markedBy': data.get('markedBy', 'unknown')
                })
            
            total_attendance = len(attendance_list)
            crowd_percentage = round((total_attendance / capacity) * 100, 1) if capacity > 0 else 0
            
            # Get reviews for this date and slot
            reviews_ref = db.collection('reviews').document(mess_id).collection(date_param).document(slot_param).collection('items')
            reviews_docs = reviews_ref.stream()
            
            reviews_list = []
            total_rating = 0
            for doc in reviews_docs:
                data = doc.to_dict()
                reviews_list.append({
                    'studentName': 'Anonymous',
                    'rating': data.get('rating', 0),
                    'comment': data.get('comment', ''),
                    'submittedAt': data.get('submittedAt', '')
                })
                total_rating += data.get('rating', 0)
            
            avg_rating = total_rating / len(reviews_list) if reviews_list else 0
            
            return jsonify({
                'messId': mess_id,
                'date': date_param,
                'slot': slot_param,
                'capacity': capacity,
                'attendance': attendance_list,
                'totalAttendance': total_attendance,
                'crowdPercentage': crowd_percentage,
                'reviews': reviews_list,
                'reviewCount': len(reviews_list),
                'averageRating': round(avg_rating, 1)
            }), 200
            
        except Exception as e:
            _disable_firestore_if_needed(e)
            print(f"[WARN] Getting analytics: {e}")
            return jsonify({
                'messId': mess_id,
                'date': date_param,
                'slot': slot_param,
                'attendance': [],
                'totalAttendance': 0,
                'crowdPercentage': 0,
                'reviews': [],
                'reviewCount': 0,
                'averageRating': 0,
                'warning': 'Could not load analytics'
            }), 200
            
    except Exception as e:
        print(f"[ERROR] analytics: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/reviews', methods=['GET', 'POST', 'OPTIONS'])
def reviews():
    """
    Get or submit reviews for a mess during current meal slot
    Reviews are only visible during the meal slot they were submitted in
    Database structure: reviews/<messId>/<date>/<slot>/items/<Id>
    """
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        mess_id = request.args.get('messId') or (request.get_json() or {}).get('messId')
        date_param = request.args.get('date')  # Allow date override for manager viewing
        slot_param = request.args.get('slot')  # Allow slot override for manager viewing
        if slot_param:
            slot_param = normalize_meal_type(slot_param)
            if not slot_param:
                return jsonify({'error': 'Invalid slot. Use breakfast, lunch, or dinner.'}), 400
        
        if not mess_id:
            return jsonify({'error': 'messId required'}), 400

        if not db or not FIRESTORE_AVAILABLE:
            if request.method == 'POST':
                return jsonify({'error': 'Firestore unavailable'}), 503
            return jsonify({
                'messId': mess_id,
                'slot': slot_param or '',
                'date': date_param or datetime.now().strftime('%Y-%m-%d'),
                'reviews': [],
                'warning': 'Firestore unavailable'
            }), 200
        
        if request.method == 'POST':
            # Submit a review for current meal slot
            data = request.get_json()
            current_time = datetime.now()
            hour = current_time.hour
            minute = current_time.minute
            
            # Get current meal type - must be within meal window to submit
            meal_type = get_meal_type_exact(hour, minute)
            if not meal_type:
                return jsonify({'error': 'Can only submit reviews during meal times'}), 403
            
            date_str = current_time.strftime('%Y-%m-%d')
            
            try:
                # Store review in: reviews/<messId>/<date>/<slot>/items/<reviewId>
                review_data = {
                    'studentName': 'Anonymous',
                    'rating': int(data.get('rating', 0)),
                    'comment': data.get('comment', ''),
                    'submittedAt': datetime.now().isoformat(),
                    'slot': meal_type,
                    'date': date_str,
                    'messId': mess_id
                }
                
                review_ref = db.collection('reviews').document(mess_id).collection(date_str).document(meal_type).collection('items').document()
                review_ref.set(review_data)
                
                print(f"[OK] Review submitted for {mess_id} {date_str} {meal_type}")
                
                return jsonify({
                    'status': 'submitted',
                    'messId': mess_id,
                    'slot': meal_type,
                    'date': date_str
                }), 201
            except Exception as e:
                _disable_firestore_if_needed(e)
                print(f"[ERROR] Submitting review: {e}")
                return jsonify({'error': f'Database error: {str(e)}'}), 500
        
        else:  # GET
            # Get reviews for specific date/slot or current slot
            if slot_param:
                # Manager viewing specific slot (with optional date)
                date_str = date_param or datetime.now().strftime('%Y-%m-%d')
                meal_type = slot_param
            else:
                # Student viewing current slot
                current_time = datetime.now()
                hour = current_time.hour
                minute = current_time.minute
                meal_type = get_meal_type_exact(hour, minute)
                date_str = current_time.strftime('%Y-%m-%d')
                
                if not meal_type:
                    return jsonify({
                        'messId': mess_id,
                        'warning': 'Outside meal hours',
                        'reviews': []
                    }), 200
            
            try:
                reviews_list = []
                reviews_ref = db.collection('reviews').document(mess_id).collection(date_str).document(meal_type).collection('items')
                reviews = reviews_ref.stream()
                
                for review in reviews:
                    review_data = review.to_dict() or {}
                    review_data.pop('studentId', None)
                    review_data['studentName'] = 'Anonymous'
                    reviews_list.append(review_data)
                
                return jsonify({
                    'messId': mess_id,
                    'slot': meal_type,
                    'date': date_str,
                    'reviews': reviews_list,
                    'count': len(reviews_list)
                }), 200
            except Exception as e:
                _disable_firestore_if_needed(e)
                print(f"[WARN] Getting reviews: {e}")
                return jsonify({
                    'messId': mess_id,
                    'slot': meal_type,
                    'date': date_str,
                    'reviews': [],
                    'warning': 'Could not load reviews'
                }), 200
                
    except Exception as e:
        print(f"[ERROR] reviews: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/attendance', methods=['GET', 'OPTIONS'])
def get_attendance():
    """
    Get attendance for specific date and slot
    Database structure: attendance/<messId>/<date>/<slot>/students
    """
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        mess_id = request.args.get('messId')
        date_param = request.args.get('date')
        slot_param = request.args.get('slot')
        
        if not mess_id or not date_param or not slot_param:
            return jsonify({'error': 'messId, date, and slot required'}), 400

        if not db or not FIRESTORE_AVAILABLE:
            return jsonify({
                'messId': mess_id,
                'date': date_param,
                'slot': slot_param,
                'attendance': [],
                'count': 0,
                'warning': 'Firestore unavailable'
            }), 200
        
        attendance_list = []
        try:
            attendance_ref = db.collection('attendance').document(mess_id).collection(date_param).document(slot_param).collection('students')
            students = attendance_ref.stream()
            
            for student in students:
                student_data = student.to_dict()
                attendance_list.append(student_data)
            
            return jsonify({
                'messId': mess_id,
                'date': date_param,
                'slot': slot_param,
                'attendance': attendance_list,
                'count': len(attendance_list)
            }), 200
        except Exception as e:
            _disable_firestore_if_needed(e)
            print(f"[WARN] Getting attendance: {e}")
            return jsonify({
                'messId': mess_id,
                'date': date_param,
                'slot': slot_param,
                'attendance': [],
                'count': 0,
                'warning': 'Could not load attendance'
            }), 200
            
    except Exception as e:
        print(f"[ERROR] get_attendance: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
