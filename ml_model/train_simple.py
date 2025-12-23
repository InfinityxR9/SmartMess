#!/usr/bin/env python3
"""
Simplified training script that uses only the JSON-based prediction model.
No TensorFlow dependency - works with nested Firebase structure.
"""

import os
import sys
import json
from datetime import datetime, timedelta

# Add backend to path for importing prediction model
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'backend'))

import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# Import the simple prediction model (no TensorFlow dependency)
from prediction_model import PredictionModel

def load_firebase_data(days_back=30):
    """Load attendance data from Firebase nested structure: attendance/<messId>/<date>/<meal>/students"""
    try:
        # Initialize Firebase
        if os.path.exists('serviceAccountKey.json'):
            cred = credentials.Certificate('serviceAccountKey.json')
        elif os.path.exists('../backend/serviceAccountKey.json'):
            cred = credentials.Certificate('../backend/serviceAccountKey.json')
        else:
            print("✗ Firebase credentials not found")
            return []
        
        # Check if Firebase app is already initialized
        try:
            firebase_admin.initialize_app(cred)
        except ValueError:
            # App already initialized
            pass
        
        db = firestore.client()
        attendance_records = []
        start_date = datetime.now() - timedelta(days=days_back)
        
        try:
            # Query structure: attendance/<messId>/<date>/<breakfast|lunch|dinner>/students
            # Get all messes
            messes = db.collection('attendance').stream()
            
            for mess_doc in messes:
                mess_id = mess_doc.id
                
                # Get dates for this mess
                dates = mess_doc.reference.collection('date').stream()
                
                for date_doc in dates:
                    date_str = date_doc.id
                    
                    # Parse date
                    try:
                        doc_date = datetime.strptime(date_str, '%Y-%m-%d')
                        if doc_date < start_date:
                            continue
                    except ValueError:
                        continue
                    
                    # Get meal types (breakfast, lunch, dinner)
                    meals = date_doc.reference.collection('meals').stream()
                    
                    for meal_doc in meals:
                        meal_type = meal_doc.id
                        
                        # Get students for this meal
                        students_ref = meal_doc.reference.collection('students')
                        students = students_ref.stream()
                        
                        student_count = 0
                        for student_doc in students:
                            student_count += 1
                            student_data = student_doc.to_dict() or {}
                            
                            # Get timestamp from student data or use current
                            timestamp_str = student_data.get('timestamp', datetime.now().isoformat())
                            
                            try:
                                if isinstance(timestamp_str, str):
                                    ts = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00')).timestamp()
                                else:
                                    ts = timestamp_str.timestamp()
                            except:
                                ts = datetime.now().timestamp()
                            
                            attendance_records.append({
                                'messId': mess_id,
                                'date': date_str,
                                'meal': meal_type,
                                'studentId': student_doc.id,
                                'timestamp': timestamp_str,
                                'ts': ts
                            })
                        
                        # Also record aggregate count per meal
                        if student_count > 0:
                            attendance_records.append({
                                'messId': mess_id,
                                'date': date_str,
                                'meal': meal_type,
                                'studentId': f'__count__{student_count}',
                                'timestamp': datetime.now().isoformat(),
                                'ts': datetime.now().timestamp(),
                                'count': student_count
                            })
            
            print(f"✓ Loaded {len(attendance_records)} attendance records from Firebase")
            return attendance_records
            
        except Exception as e:
            print(f"✗ Error querying attendance collection: {e}")
            return []
            
    except Exception as e:
        print(f"✗ Firebase initialization error: {e}")
        return []

def generate_dummy_data():
    """Generate dummy training data for demonstration"""
    print("⚠ No real Firebase data found, generating dummy data for demonstration...")
    
    dummy_records = []
    now = datetime.now()
    
    # Create 30 days of dummy attendance data
    for day_offset in range(30):
        date = now - timedelta(days=day_offset)
        date_str = date.strftime('%Y-%m-%d')
        
        # Breakfast (7:30-9:30): ~30-50 students per 15min
        # Lunch (12:00-14:00): ~40-80 students per 15min
        # Dinner (19:30-21:30): ~20-40 students per 15min
        
        meals_data = {
            'breakfast': {'count': 40, 'hour': 8, 'min': 30},
            'lunch': {'count': 60, 'hour': 13, 'min': 0},
            'dinner': {'count': 30, 'hour': 20, 'min': 30}
        }
        
        for mess_id in ['mess1', 'mess2', 'mess3']:
            for meal_type, meal_info in meals_data.items():
                # Simulate students distributed across the meal time
                for student_num in range(meal_info['count']):
                    min_offset = (student_num % 8) * 15  # Spread across 2-hour window (0-105 min)
                    
                    student_time = date.replace(
                        hour=meal_info['hour'],
                        minute=0,
                        second=0
                    )
                    # Add minutes carefully
                    student_time = student_time + timedelta(minutes=meal_info['min'] + min_offset)
                    
                    dummy_records.append({
                        'messId': mess_id,
                        'date': date_str,
                        'meal': meal_type,
                        'studentId': f'student_{student_num}_{meal_type}',
                        'timestamp': student_time.isoformat(),
                        'ts': student_time.timestamp()
                    })
    
    print(f"✓ Generated {len(dummy_records)} dummy training records")
    return dummy_records

def train_model(attendance_records):
    """Train the prediction model with historical attendance data"""
    if not attendance_records:
        print("✗ No training data available")
        return False
    
    print(f"📊 Training model with {len(attendance_records)} records...")
    
    # Initialize the model
    model = PredictionModel()
    
    # Train with attendance data
    success = model.train(attendance_records)
    
    if success:
        print("✓ Model training completed successfully")
        print(f"  - Learned patterns for {len(model.historical_data.get('time_interval_averages', {}))} time intervals")
        return True
    else:
        print("✗ Model training failed")
        return False

def main():
    """Main training pipeline"""
    print("=" * 60)
    print("SmartMess ML Model Training (Simplified - No TensorFlow)")
    print("=" * 60)
    
    # Step 1: Load data from Firebase
    print("\n[1/2] Loading attendance data from Firebase...")
    attendance_records = load_firebase_data(days_back=30)
    
    # If no data, generate dummy data
    if not attendance_records:
        print("\n⚠ No real Firebase data found, generating dummy data for demonstration...")
        attendance_records = generate_dummy_data()
    
    if not attendance_records:
        print("\n✗ Failed to load training data. Exiting.")
        sys.exit(1)
    
    # Step 2: Train model
    print("\n[2/2] Training prediction model...")
    success = train_model(attendance_records)
    
    if success:
        print("\n" + "=" * 60)
        print("✓ Training pipeline completed successfully!")
        print("=" * 60)
        return 0
    else:
        print("\n" + "=" * 60)
        print("✗ Training pipeline failed")
        print("=" * 60)
        return 1

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
