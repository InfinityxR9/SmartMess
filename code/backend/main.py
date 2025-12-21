import os
from flask import Flask, request, jsonify
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import numpy as np
import json
from prediction_model import PredictionModel

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

# Initialize prediction model
model = PredictionModel()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'}), 200

@app.route('/predict', methods=['POST'])
def predict():
    """
    Predict crowd for a given mess
    Expected input: {'messId': 'mess_id'}
    """
    try:
        data = request.get_json()
        mess_id = data.get('messId')
        
        if not mess_id:
            return jsonify({'error': 'messId is required'}), 400
        
        # Fetch recent scans for this mess
        ten_minutes_ago = datetime.now() - timedelta(minutes=10)
        
        if db:
            scans_query = db.collection('scans').where(
                'messId', '==', mess_id
            ).where(
                'ts', '>=', ten_minutes_ago
            ).stream()
            
            current_count = sum(1 for _ in scans_query)
        else:
            current_count = 0
        
        # Get mess capacity
        if db:
            mess_doc = db.collection('messes').document(mess_id).get()
            capacity = mess_doc.get('capacity') if mess_doc.exists else 100
        else:
            capacity = 100
        
        # Generate predictions for next few time slots
        predictions = model.predict_next_slots(mess_id, current_count, capacity)
        
        # Find best time slot
        best_slot = min(predictions, key=lambda x: x['crowd_percentage'])
        
        return jsonify({
            'messId': mess_id,
            'current_crowd': current_count,
            'predictions': predictions,
            'best_slot': best_slot,
        }), 200
        
    except Exception as e:
        print(f"Error in predict: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/train', methods=['POST'])
def train_model():
    """
    Endpoint to retrain the model with latest data
    This should be called periodically
    """
    try:
        if db:
            # Fetch all scans from the past 30 days
            thirty_days_ago = datetime.now() - timedelta(days=30)
            scans = db.collection('scans').where(
                'ts', '>=', thirty_days_ago
            ).stream()
            
            scan_data = []
            for scan in scans:
                scan_doc = scan.to_dict()
                scan_data.append({
                    'messId': scan_doc.get('messId'),
                    'timestamp': scan_doc.get('ts').strftime('%Y-%m-%d %H:%M:%S') if scan_doc.get('ts') else None,
                })
            
            # Train the model
            if scan_data:
                model.train(scan_data)
                return jsonify({'message': 'Model trained successfully', 'samples': len(scan_data)}), 200
            else:
                return jsonify({'message': 'No training data available'}), 200
        else:
            return jsonify({'error': 'Firebase not initialized'}), 500
            
    except Exception as e:
        print(f"Error in train: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
