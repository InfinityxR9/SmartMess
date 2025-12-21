import os
import sys
import json
from datetime import datetime, timedelta
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
from crowd_predictor import MessCrowdPredictor

def load_firebase_data(days_back=30):
    """Load scan data from Firebase"""
    try:
        # Initialize Firebase
        if os.path.exists('serviceAccountKey.json'):
            cred = credentials.Certificate('serviceAccountKey.json')
        else:
            cred = credentials.ApplicationDefault()
        
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        
        # Fetch scans from the past N days
        start_date = datetime.now() - timedelta(days=days_back)
        scans = []
        
        docs = db.collection('scans').where('ts', '>=', start_date).stream()
        
        for doc in docs:
            data = doc.to_dict()
            scans.append({
                'ts': data['ts'],
                'messId': data.get('messId'),
                'uid': data.get('uid'),
            })
        
        return scans
        
    except Exception as e:
        print(f"Error loading Firebase data: {e}")
        return []

def main():
    print("=== Mess Crowd Prediction Model Training ===")
    print("Using Simple Linear Regression")
    print()
    
    # Load data
    print("Loading data from Firebase...")
    scans = load_firebase_data(days_back=30)
    
    if not scans:
        print("✗ No training data found.")
        print("Note: Make sure your Firebase project has scan data in the 'scans' collection")
        print("Model will be trained with default parameters when data becomes available.")
        return
    
    print(f"✓ Loaded {len(scans)} scan records")
    print()
    
    # Train model
    print("Training Linear Regression model...")
    predictor = MessCrowdPredictor()
    
    success = predictor.train(scans)
    
    if success:
        print("✓ Training completed successfully!")
        print("✓ Model saved")
        print()
        print("Sample Predictions for today:")
        predictions = predictor.predict_next_slots()
        for pred in predictions:
            print(f"  {pred['time_slot']} - Predicted: {pred['predicted_crowd']} people")
    else:
        print("✗ Training failed. Not enough data.")

if __name__ == '__main__':
    main()
