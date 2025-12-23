import os
import sys
import json
from datetime import datetime, timedelta
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
from crowd_predictor import MessCrowdPredictor

def load_firebase_data(days_back=30):
    """Load attendance data from Firebase nested structure: attendance/<messId>/<date>/<meal>/students"""
    try:
        # Initialize Firebase
        if os.path.exists('serviceAccountKey.json'):
            cred = credentials.Certificate('serviceAccountKey.json')
        elif os.path.exists('../backend/serviceAccountKey.json'):
            cred = credentials.Certificate('../backend/serviceAccountKey.json')
        else:
            # Try to use Application Default Credentials
            cred = credentials.ApplicationDefault()
        
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
                dates = db.collection('attendance').document(mess_id).collections()
                
                for date_ref in dates:
                    date_str = date_ref.id
                    
                    try:
                        # Parse date to check if within range
                        doc_date = datetime.strptime(date_str, '%Y-%m-%d')
                        if doc_date < start_date:
                            continue
                    except:
                        continue
                    
                    # Get meal types for this date
                    meals = db.collection(f'attendance/{mess_id}/{date_str}').stream()
                    
                    for meal_doc in meals:
                        meal_type = meal_doc.id  # breakfast, lunch, or dinner
                        meal_data = meal_doc.to_dict() or {}
                        
                        # Get students for this meal
                        try:
                            students_ref = db.collection(f'attendance/{mess_id}/{date_str}/{meal_type}')
                            students = students_ref.stream()
                            
                            for student_doc in students:
                                attendance_records.append({
                                    'messId': mess_id,
                                    'date': date_str,
                                    'meal': meal_type,
                                    'studentId': student_doc.id,
                                    'timestamp': f"{date_str} {meal_type}",  # For training
                                    'ts': doc_date  # For filtering
                                })
                        except Exception as student_error:
                            # If no students subcollection, try to get count from meal doc
                            if 'count' in meal_data:
                                for i in range(meal_data['count']):
                                    attendance_records.append({
                                        'messId': mess_id,
                                        'date': date_str,
                                        'meal': meal_type,
                                        'studentId': f'student_{i}',
                                        'timestamp': f"{date_str} {meal_type}",
                                        'ts': doc_date
                                    })
                
        except Exception as e:
            print(f"Warning: Could not query attendance structure: {e}")
            print("Make sure your Firebase has attendance/<messId>/<date>/<meal>/students structure")
        
        return attendance_records
        
    except Exception as e:
        print(f"Error loading Firebase data: {e}")
        print("\nFirebase Structure Expected:")
        print("  attendance/")
        print("    ├── mess_001/")
        print("    │   └── 2025-12-23/")
        print("    │       ├── breakfast/")
        print("    │       │   └── students/")
        print("    │       │       ├── student_1")
        print("    │       │       └── student_2")
        print("    │       ├── lunch/")
        print("    │       └── dinner/")
        print("\nTo set up credentials:")
        print("1. Download serviceAccountKey.json from Firebase Console")
        print("2. Place it in the ml_model/ or backend/ directory")
        return []

def generate_dummy_data(num_records=100):
    """Generate dummy attendance data for testing"""
    print("Generating dummy attendance data for testing...")
    dummy_data = []
    
    now = datetime.now()
    mess_ids = ['mess_001', 'mess_002', 'mess_003']
    
    # Generate data for past 7 days, focused on meal times
    for day_offset in range(7):
        current_date = now - timedelta(days=day_offset)
        
        # Breakfast: 7:30-9:30 (more crowded towards 8:00-8:30)
        for hour in range(7, 9):
            for minute in [15, 30, 45]:
                count = 8 + int(10 * (0.7 if hour == 8 else 0.3))  # More at 8am
                for _ in range(count):
                    dummy_data.append({
                        'ts': current_date.replace(hour=hour, minute=minute),
                        'messId': mess_ids[len(dummy_data) % len(mess_ids)],
                        'uid': f'student_{len(dummy_data)}',
                    })
        
        # Lunch: 12:00-14:00 (peak at 12:30-13:00)
        for hour in [12, 13]:
            for minute in [0, 30]:
                count = 15 + int(15 * (0.8 if hour == 12 else 0.6))
                for _ in range(count):
                    dummy_data.append({
                        'ts': current_date.replace(hour=hour, minute=minute),
                        'messId': mess_ids[len(dummy_data) % len(mess_ids)],
                        'uid': f'student_{len(dummy_data)}',
                    })
        
        # Dinner: 19:30-21:30 (moderate crowd)
        for hour in [19, 20]:
            for minute in [30, 45]:
                count = 10 + int(12 * (0.5 if hour == 20 else 0.7))
                for _ in range(count):
                    dummy_data.append({
                        'ts': current_date.replace(hour=hour, minute=minute),
                        'messId': mess_ids[len(dummy_data) % len(mess_ids)],
                        'uid': f'student_{len(dummy_data)}',
                    })
    
    print(f"Generated {len(dummy_data)} dummy records")
    return dummy_data

def main():
    print("=" * 50)
    print("Mess Crowd Prediction Model Training")
    print("=" * 50)
    print()
    
    # Load data from Firebase
    print("Loading attendance data from Firebase...")
    attendance_data = load_firebase_data(days_back=30)
    
    # If no Firebase data, use dummy data for demonstration
    if not attendance_data:
        print("✗ No attendance data found in Firebase")
        print()
        use_dummy = input("Generate dummy data for testing? (y/n): ").lower().strip()
        if use_dummy == 'y':
            attendance_data = generate_dummy_data(num_records=100)
        else:
            print()
            print("Note: Make sure your Firebase project has attendance data in the 'attendance' collection")
            print("Model will be trained with default parameters when data becomes available.")
            return
    
    print(f"✓ Loaded {len(attendance_data)} attendance records")
    print()
    
    # Train model
    print("Training Linear Regression model...")
    predictor = MessCrowdPredictor()
    
    success = predictor.train(attendance_data)
    
    if success:
        print()
        print("✓ Training completed successfully!")
        print("✓ Model saved to crowd_model.h5")
        print()
        print("Sample Predictions for today:")
        predictions = predictor.predict_next_slots()
        for pred in predictions:
            print(f"  {pred['time_slot']} - Predicted: {pred['predicted_crowd']} people ({pred['crowd_percentage']}%)")
    else:
        print("✗ Training failed. Insufficient data.")
    
    print()
    print("To use the trained model:")
    print("1. Copy crowd_model.h5 and scaler.pkl to the backend/ directory")
    print("2. Ensure train.py is called periodically (e.g., via cron job)")
    print("3. Or configure auto-training via Cloud Scheduler")

if __name__ == '__main__':
    main()
