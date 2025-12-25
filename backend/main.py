import os
import sys
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
    # Try to load from environment variable or credentials file
    if os.path.exists('serviceAccountKey.json'):
        cred = credentials.Certificate('serviceAccountKey.json')
    else:
        # Use Application Default Credentials
        cred = credentials.ApplicationDefault()
    
    firebase_admin.initialize_app(cred)
    db = firestore.client()
except Exception as e:
    print(f"Warning: Firebase initialization failed: {e}")
    db = None

# Initialize TensorFlow prediction service (mess-specific models)
prediction_service = PredictionService()

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

@app.route('/predict', methods=['POST', 'OPTIONS'])
def predict():
    """
    Real-time crowd prediction with 15-minute slot-based training
    Trains model on the spot using data from the current 15-min slot only
    Uses mess-specific TensorFlow models for isolation
    Expected input: {'messId': 'mess_id', 'devMode': True/False}
    Returns: Predictions for current and next 15-minute slots
    
    Data Structure: attendance/<messId>/<date>/<meal>/students
    Ensures all predictions are mess-isolated using separate trained models
    """
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.get_json()
        mess_id = data.get('messId')
        dev_mode = data.get('devMode', False)  # Allow predictions outside meal times in dev mode
        
        if not mess_id:
            return jsonify({'error': 'messId is required'}), 400
        
        # Get current time and calculate 15-minute slot
        current_time = datetime.now()
        date_str = current_time.strftime('%Y-%m-%d')
        hour = current_time.hour
        minute = current_time.minute
        
        # Get exact meal type using precise windows
        meal_type = get_meal_type_exact(hour, minute)
        
        # Check if outside meal hours
        if not meal_type and not dev_mode:
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
        
        # Get current attendance count for the 15-minute slot
        current_count = 0
        
        if db:
            try:
                students_ref = db.collection(f'attendance/{mess_id}/{date_str}/{meal_type}/students')
                students = students_ref.stream()
                current_count = sum(1 for _ in students)
            except Exception as e:
                print(f"[WARN] Could not get current attendance: {e}")
                current_count = 0
        
        # Get mess capacity
        capacity = 100  # Default
        if db:
            try:
                mess_doc = db.collection('messes').document(mess_id).get()
                if mess_doc.exists:
                    capacity = mess_doc.get('capacity', 100)
            except Exception as e:
                print(f"[WARN] Could not get mess capacity: {e}")
        
        # Train model on the spot using current 15-minute slot data
        try:
            from train_tensorflow import TensorFlowMessModel
            spot_model = TensorFlowMessModel(mess_id)
            
            # Load attendance data for ONLY this 15-minute slot
            attendance_records = []
            if db:
                try:
                    # Round to nearest 15-minute interval
                    slot_minute = (minute // 15) * 15
                    slot_start = current_time.replace(minute=slot_minute, second=0, microsecond=0)
                    slot_end = slot_start + timedelta(minutes=15)
                    
                    students_ref = db.collection(f'attendance/{mess_id}/{date_str}/{meal_type}/students')
                    students = students_ref.stream()
                    
                    for student in students:
                        try:
                            data = student.to_dict()
                            marked_at = data.get('markedAt')
                            if isinstance(marked_at, str):
                                marked_at = datetime.fromisoformat(marked_at.replace('Z', '+00:00'))
                            
                            # Only include records from current 15-min slot
                            if slot_start <= marked_at < slot_end:
                                attendance_records.append({
                                    'enrollmentId': data.get('enrollmentId'),
                                    'studentName': data.get('studentName', 'Anonymous'),
                                    'markedAt': marked_at,
                                    'markedBy': data.get('markedBy', 'unknown'),
                                    'messId': mess_id,
                                    'meal': meal_type,
                                    'date': date_str
                                })
                        except:
                            continue
                    
                    print(f"[OK] Loaded {len(attendance_records)} records for {mess_id} slot {slot_minute}-{slot_minute+15}")
                except Exception as e:
                    print(f"[WARN] Error loading 15-min slot data: {e}")
            
            # Train spot model if we have data
            if attendance_records:
                spot_model.train(attendance_records)
                print(f"[OK] Trained spot model for {mess_id} with {len(attendance_records)} records")
            else:
                print(f"[WARN] No data for {mess_id} in current 15-min slot, using pre-trained model")
        except Exception as e:
            print(f"[WARN] Spot training failed: {e}")
        
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
                'error': result['error'],
                'messId': mess_id,
                'message': f'Model not yet trained for {mess_id}. Run: python train_tensorflow.py {mess_id}'
            }), 400
        
        result['meal_type'] = meal_type
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
    For each mess, run: python train_tensorflow.py {mess_id}
    
    POST body: {'messId': 'mess_id'}
    This endpoint is informational - actual training is done via ml_model/train_tensorflow.py
    """
    try:
        data = request.get_json() or {}
        mess_id = data.get('messId')
        
        if not mess_id:
            return jsonify({
                'error': 'messId is required',
                'instructions': 'To train a model, run: python train_tensorflow.py {mess_id}',
                'example': 'python train_tensorflow.py alder',
                'note': 'Model will be saved to: ml_model/models/{mess_id}_*.keras/pkl/json'
            }), 400
        
        # Try to load existing model to verify it's trained
        model = prediction_service.get_prediction_model(mess_id)
        
        if model:
            model_info = model.get_model_info()
            return jsonify({
                'message': f'Model already trained for {mess_id}',
                'messId': mess_id,
                'modelInfo': model_info
            }), 200
        else:
            return jsonify({
                'message': f'No trained model for {mess_id}',
                'messId': mess_id,
                'instructions': f'Run: python train_tensorflow.py {mess_id}',
                'location': 'ml_model/train_tensorflow.py'
            }), 404
            
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
        
        if not mess_id or not db:
            return jsonify({'error': 'messId required and database not available'}), 400
        
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
        
        if not mess_id or not db:
            return jsonify({'error': 'messId required'}), 400
        
        # Default to today and current slot if not specified
        if not date_param or not slot_param:
            current_time = datetime.now()
            date_param = current_time.strftime('%Y-%m-%d')
            hour = current_time.hour
            minute = current_time.minute
            slot_param = get_meal_type_exact(hour, minute)
            
            if not slot_param:
                slot_param = 'lunch'  # Default slot
        
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
                    'studentName': data.get('studentName', 'Anonymous'),
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
        
        if not mess_id or not db:
            return jsonify({'error': 'messId required'}), 400
        
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
                    'studentId': data.get('studentId'),
                    'studentName': data.get('studentName', 'Anonymous'),
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
                print(f"[ERROR] Submitting review: {e}")
                return jsonify({'error': f'Database error: {str(e)}'}), 500
        
        else:  # GET
            # Get reviews for specific date/slot or current slot
            if date_param and slot_param:
                # Manager viewing specific date/slot
                date_str = date_param
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
                    review_data = review.to_dict()
                    reviews_list.append(review_data)
                
                return jsonify({
                    'messId': mess_id,
                    'slot': meal_type,
                    'date': date_str,
                    'reviews': reviews_list,
                    'count': len(reviews_list)
                }), 200
            except Exception as e:
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
        
        if not mess_id or not date_param or not slot_param or not db:
            return jsonify({'error': 'messId, date, and slot required'}), 400
        
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
