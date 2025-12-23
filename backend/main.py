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
CORS(app)

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

@app.route('/predict', methods=['POST', 'OPTIONS'])
def predict():
    """
    Real-time crowd prediction for a specific mess during meal time
    Uses mess-specific TensorFlow models for isolation
    Expected input: {'messId': 'mess_id'}
    Returns: Current crowd and predictions for next 15-minute slots
    
    Data Structure: attendance/<messId>/<date>/<meal>/students
    Ensures all predictions are mess-isolated using separate trained models
    """
    if request.method == 'OPTIONS':
        return '', 200
    
    try:
        data = request.get_json()
        mess_id = data.get('messId')
        
        if not mess_id:
            return jsonify({'error': 'messId is required'}), 400
        
        # Get current time
        current_time = datetime.now()
        date_str = current_time.strftime('%Y-%m-%d')
        
        # Get current attendance count from nested structure
        current_count = 0
        meal_type = None
        
        if db:
            try:
                # Determine current meal type for Firebase query
                hour = current_time.hour
                if 7 <= hour < 10:
                    meal_type = 'breakfast'
                elif 11 <= hour < 15:
                    meal_type = 'lunch'
                elif 18 <= hour < 22:
                    meal_type = 'dinner'
                
                # Query current attendance only if during meal hours
                if meal_type:
                    students_ref = db.collection(f'attendance/{mess_id}/{date_str}/{meal_type}/students')
                    students = students_ref.stream()
                    current_count = sum(1 for _ in students)
            except Exception as e:
                print(f"Warning: Could not get current attendance: {e}")
                current_count = 0
        
        # Get mess capacity
        capacity = 100  # Default
        if db:
            try:
                mess_doc = db.collection('messes').document(mess_id).get()
                if mess_doc.exists:
                    capacity = mess_doc.get('capacity', 100)
            except:
                pass
        
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
        
        return jsonify(result), 200
        
    except Exception as e:
        print(f"Error in predict: {e}")
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

@app.route('/model-info', methods=['GET'])
def model_info():
    """Get information about trained models"""
    try:
        mess_id = request.args.get('messId')
        
        if not mess_id:
            return jsonify({
                'error': 'messId parameter required',
                'usage': '/model-info?messId=alder'
            }), 400
        
        info = prediction_service.get_model_info(mess_id)
        
        if 'error' in info:
            return jsonify(info), 404
        
        return jsonify(info), 200
        
    except Exception as e:
        print(f"Error in model-info: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
