#!/usr/bin/env python3
"""
TensorFlow-based regression model for mess crowd prediction
Trains on mess-specific attendance data from Firebase
"""

import os
import sys
import json
from datetime import datetime, timedelta
import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import joblib

class MessCrowdRegressor:
    """Simple regression model for predicting crowd using TensorFlow"""
    
    def __init__(self, mess_id):
        self.mess_id = mess_id
        self.model = None
        self.scaler = None
        models_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'models')
        self.model_path = os.path.join(models_dir, f'{mess_id}_model.keras')
        self.scaler_path = os.path.join(models_dir, f'{mess_id}_scaler.pkl')
        self.metadata_path = os.path.join(models_dir, f'{mess_id}_metadata.json')
        
        # Create models directory if it doesn't exist
        os.makedirs(models_dir, exist_ok=True)
        
    def create_model(self, input_dim):
        """Create a simple regression neural network"""
        model = keras.Sequential([
            layers.Dense(32, activation='relu', input_shape=(input_dim,)),
            layers.Dropout(0.2),
            layers.Dense(16, activation='relu'),
            layers.Dropout(0.2),
            layers.Dense(8, activation='relu'),
            layers.Dense(1)  # Output: predicted crowd count
        ])
        
        model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=0.001),
            loss='mse',
            metrics=['mae']
        )
        
        return model
    
    def prepare_data(self, attendance_records):
        """
        Prepare training data from attendance records
        Creates features: hour, day_of_week, meal_type (encoded), historical_count
        Target: crowd_count
        """
        features = []
        targets = []
        
        for record in attendance_records:
            try:
                # Parse timestamp
                marked_at = record.get('markedAt')
                if isinstance(marked_at, str):
                    dt = datetime.fromisoformat(marked_at.replace('Z', '+00:00'))
                else:
                    continue
                
                # Extract features
                hour = dt.hour
                day_of_week = dt.weekday()
                
                # Meal type encoding (breakfast=0, lunch=1, dinner=2)
                # Breakfast: 7:30-9:30 (exclusive end), Lunch: 12:00-14:00 (exclusive end), Dinner: 19:30-21:30 (exclusive end)
                meal_type = -1  # Default (not during meal time)
                if 7 < hour < 9 or (hour == 7 and dt.minute >= 30) or (hour == 9 and dt.minute < 30):
                    meal_type = 0  # Breakfast (7:30-9:30)
                elif 12 <= hour < 14 or (hour == 14 and dt.minute == 0):
                    meal_type = 1  # Lunch (12:00-14:00)
                elif 19 < hour < 21 or (hour == 19 and dt.minute >= 30) or (hour == 21 and dt.minute < 30):
                    meal_type = 2  # Dinner (19:30-21:30)
                
                # Create feature vector
                feature_vector = [hour, day_of_week, meal_type]
                features.append(feature_vector)
                targets.append(1)  # Each record = 1 student
                
            except Exception as e:
                continue
        
        if len(features) < 5:
            print(f"[WARN] Insufficient data for {self.mess_id}: {len(features)} records")
            return None, None
        
        X = np.array(features, dtype=np.float32)
        y = np.array(targets, dtype=np.float32)
        
        # Normalize features
        from sklearn.preprocessing import StandardScaler
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)
        
        return X_scaled, y, scaler
    
    def train(self, attendance_records):
        """Train the model on mess-specific attendance data"""
        print(f"\n[{self.mess_id}] Preparing training data...")
        
        result = self.prepare_data(attendance_records)
        if result[0] is None:
            return False
        
        X_scaled, y, scaler = result
        
        print(f"[{self.mess_id}] Training with {len(X_scaled)} records...")
        
        # Create and train model
        input_dim = X_scaled.shape[1]
        self.model = self.create_model(input_dim)
        self.scaler = scaler
        
        # Train with small batch and few epochs for quick training
        history = self.model.fit(
            X_scaled, y,
            epochs=20,
            batch_size=4,
            validation_split=0.2,
            verbose=0
        )
        
        # Save model and scaler
        self.model.save(self.model_path)
        joblib.dump(scaler, self.scaler_path)
        
        # Save metadata
        metadata = {
            'mess_id': self.mess_id,
            'trained_at': datetime.now().isoformat(),
            'training_samples': len(X_scaled),
            'input_features': ['hour', 'day_of_week', 'meal_type'],
            'final_loss': float(history.history['loss'][-1]),
            'final_mae': float(history.history['mae'][-1])
        }
        
        with open(self.metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        print(f"[OK] [{self.mess_id}] Model trained and saved")
        print(f"  Loss: {history.history['loss'][-1]:.4f}")
        print(f"  MAE: {history.history['mae'][-1]:.4f}")
        
        return True
    
    def predict(self, hour, day_of_week, meal_type):
        """Predict crowd for given time"""
        if self.model is None:
            return None
        
        # Create feature vector
        features = np.array([[hour, day_of_week, meal_type]], dtype=np.float32)
        
        # Scale features
        features_scaled = self.scaler.transform(features)
        
        # Predict
        prediction = self.model.predict(features_scaled, verbose=0)[0][0]
        
        # Ensure positive count
        return max(0, int(prediction))

def load_firebase_data(mess_id, days_back=7):
    """
    Load attendance data from Firebase for specific mess
    Path: attendance/{mess_id}/{date}/{meal}/students
    """
    try:
        # Initialize Firebase
        if os.path.exists('serviceAccountKey.json'):
            cred = credentials.Certificate('serviceAccountKey.json')
        elif os.path.exists('../backend/serviceAccountKey.json'):
            cred = credentials.Certificate('../backend/serviceAccountKey.json')
        else:
            print(f"[ERROR] Firebase credentials not found")
            return []
        
        # Initialize Firebase app if not already done
        try:
            firebase_admin.initialize_app(cred)
        except ValueError:
            pass  # App already initialized
        
        db = firestore.client()
        attendance_records = []
        start_date = datetime.now() - timedelta(days=days_back)
        
        try:
            # Query mess-specific data: attendance/{mess_id}/{date}/{meal}/students
            print(f"[QUERY] Querying Firebase for {mess_id}...")
            mess_ref = db.collection('attendance').document(mess_id)
            
            # Get all dates for this mess
            # Note: Firestore doesn't support wildcards, so we need to iterate
            # Try common date formats from now backwards
            collected_records = 0
            
            for day_offset in range(days_back):
                check_date = datetime.now() - timedelta(days=day_offset)
                date_str = check_date.strftime('%Y-%m-%d')
                
                try:
                    # Try to access the date document
                    date_ref = mess_ref.collection(date_str)
                    
                    # Get all meals for this date
                    meals = date_ref.stream()
                    
                    for meal_doc in meals:
                        meal_type = meal_doc.id
                        
                        try:
                            # Get students collection for this meal
                            students_ref = meal_doc.reference.collection('students')
                            students = students_ref.stream()
                            
                            for student_doc in students:
                                student_data = student_doc.to_dict() or {}
                                
                                # Extract record info
                                enrollment_id = student_doc.id
                                marked_at = student_data.get('markedAt')
                                student_name = student_data.get('studentName', 'Unknown')
                                marked_by = student_data.get('markedBy', 'unknown')
                                
                                attendance_records.append({
                                    'enrollmentId': enrollment_id,
                                    'markedAt': marked_at,
                                    'studentName': student_name,
                                    'markedBy': marked_by,
                                    'messId': mess_id,
                                    'meal': meal_type,
                                    'date': date_str
                                })
                                collected_records += 1
                        except Exception as e:
                            # Collection might not exist
                            continue
                
                except Exception as e:
                    # Date collection might not exist
                    continue
            
            print(f"[OK] Loaded {len(attendance_records)} attendance records for {mess_id}")
            return attendance_records
            
        except Exception as e:
            print(f"[ERROR] Error querying attendance: {e}")
            import traceback
            traceback.print_exc()
            return []
            
    except Exception as e:
        print(f"[ERROR] Firebase error: {e}")
        import traceback
        traceback.print_exc()
        return []

def generate_dummy_attendance_data(mess_id, days=7, records_per_day=40):
    """
    Generate dummy attendance data for testing/development
    Simulates realistic attendance patterns
    """
    print(f"[INFO] Generating dummy data for {mess_id}...")
    
    records = []
    now = datetime.now()
    
    meal_times = {
        'breakfast': (7, 30, 9, 30),     # 7:30-9:30
        'lunch': (12, 0, 14, 0),         # 12:00-14:00
        'dinner': (19, 30, 21, 30)       # 19:30-21:30
    }
    
    for day_offset in range(days):
        current_date = now - timedelta(days=day_offset)
        date_str = current_date.strftime('%Y-%m-%d')
        
        for meal_name, (start_h, start_m, end_h, end_m) in meal_times.items():
            # Generate students for this meal
            num_students = np.random.randint(10, records_per_day)
            
            for student_num in range(num_students):
                # Random time within meal window
                minutes_into_meal = np.random.randint(0, (end_h - start_h) * 60 + (end_m - start_m))
                
                student_hour = start_h + (start_m + minutes_into_meal) // 60
                student_minute = (start_m + minutes_into_meal) % 60
                
                student_time = current_date.replace(
                    hour=student_hour,
                    minute=student_minute,
                    second=np.random.randint(0, 60),
                    microsecond=0
                )
                
                records.append({
                    'enrollmentId': f'STUDENT_{day_offset}_{meal_name}_{student_num}',
                    'markedAt': student_time.isoformat(),
                    'studentName': f'Student {day_offset}_{student_num}',
                    'markedBy': 'manual' if np.random.random() > 0.7 else 'qr',
                    'messId': mess_id,
                    'meal': meal_name,
                    'date': date_str
                })
    
    print(f"[OK] Generated {len(records)} dummy records for {mess_id}")
    return records

def main():
    """Main training pipeline"""
    print("=" * 70)
    print("SmartMess TensorFlow Mess-Specific Crowd Prediction Model Training")
    print("=" * 70)
    
    # Get mess ID from command line or use default
    mess_id = sys.argv[1] if len(sys.argv) > 1 else 'alder'
    
    print(f"[TARGET] Training model for mess: {mess_id}")
    
    # Step 1: Load data from Firebase
    print(f"\n[STEP 1/3] Loading attendance data for {mess_id}...")
    attendance_records = load_firebase_data(mess_id, days_back=30)
    
    # If no Firebase data, generate dummy data
    if not attendance_records:
        print(f"[WARN] No Firebase data found for {mess_id}")
        print(f"[INFO] Expected path: attendance/{mess_id}/{{date}}/{{meal}}/students")
        attendance_records = generate_dummy_attendance_data(mess_id, days=7)
    
    if not attendance_records:
        print(f"[ERROR] No training data available")
        return 1
    
    # Step 2: Train model
    print(f"\n[STEP 2/3] Training regression model for {mess_id}...")
    regressor = MessCrowdRegressor(mess_id)
    
    success = regressor.train(attendance_records)
    
    if success:
        print("\n" + "=" * 70)
        print(f"[OK] Training completed successfully for {mess_id}!")
        print(f"  Model saved: {regressor.model_path}")
        print(f"  Scaler saved: {regressor.scaler_path}")
        print(f"  Metadata saved: {regressor.metadata_path}")
        print("=" * 70)
        return 0
    else:
        print("\n" + "=" * 70)
        print(f"[ERROR] Training failed for {mess_id}")
        print("=" * 70)
        return 1

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
