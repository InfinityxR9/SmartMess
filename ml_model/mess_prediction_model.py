#!/usr/bin/env python3
"""
Mess-specific prediction model that loads trained TensorFlow models
Generates predictions for a specific mess only
"""

import os
import json
from datetime import datetime, timedelta
import numpy as np
import joblib
import tensorflow as tf

class MessPredictionModel:
    """
    Loads and uses mess-specific trained models
    Ensures predictions are mess-isolated
    """
    
    def __init__(self, mess_id):
        self.mess_id = mess_id
        self.model = None
        self.scaler = None
        self.metadata = {}
        
        # Use absolute paths for model files
        ml_model_dir = os.path.dirname(os.path.abspath(__file__))
        models_dir = os.path.join(ml_model_dir, 'models')
        
        self.model_path = os.path.join(models_dir, f'{mess_id}_model.keras')
        self.scaler_path = os.path.join(models_dir, f'{mess_id}_scaler.pkl')
        self.metadata_path = os.path.join(models_dir, f'{mess_id}_metadata.json')
        
        # Load model and scaler
        self._load_model()
    
    def _load_model(self):
        """Load trained model and scaler from disk"""
        try:
            if os.path.exists(self.model_path):
                self.model = tf.keras.models.load_model(self.model_path)
                print(f"[OK] Loaded model for {self.mess_id}")
            else:
                print(f"[WARN] Model not found for {self.mess_id}: {self.model_path}")
                return False
            
            if os.path.exists(self.scaler_path):
                self.scaler = joblib.load(self.scaler_path)
                print(f"[OK] Loaded scaler for {self.mess_id}")
            else:
                print(f"[WARN] Scaler not found for {self.mess_id}")
                return False
            
            if os.path.exists(self.metadata_path):
                with open(self.metadata_path, 'r') as f:
                    self.metadata = json.load(f)
                print(f"[OK] Loaded metadata for {self.mess_id}")
            
            return True
            
        except Exception as e:
            print(f"[ERROR] Error loading model for {self.mess_id}: {e}")
            return False
    
    def get_meal_type(self, hour, minute=0):
        """
        Get meal type based on hour and minute
        Breakfast: 7:30-9:30 (inclusive start, exclusive end), 
        Lunch: 12:00-14:00 (inclusive start, exclusive end),
        Dinner: 19:30-21:30 (inclusive start, exclusive end)
        """
        if 7 < hour < 9 or (hour == 7 and minute >= 30) or (hour == 9 and minute < 30):
            return 'breakfast', 0
        elif 12 <= hour < 14 or (hour == 14 and minute == 0):
            return 'lunch', 1
        elif 19 < hour < 21 or (hour == 19 and minute >= 30) or (hour == 21 and minute < 30):
            return 'dinner', 2
        else:
            return None, -1
    
    def predict_next_slots_15min(self, current_time, current_count, capacity, db=None):
        """
        Generate predictions for next 15-minute slots
        Returns predictions only for this mess
        """
        predictions = []
        
        if self.model is None:
            return []
        
        # Get current meal type
        meal_type, meal_code = self.get_meal_type(current_time.hour, current_time.minute)
        
        if meal_type is None:
            # Outside meal hours
            return []
        
        # Meal time ranges (correct times)
        meal_times = {
            'breakfast': (7, 30, 9, 30),  # 7:30 to 9:30
            'lunch': (12, 0, 14, 0),      # 12:00 to 14:00
            'dinner': (19, 30, 21, 30)    # 19:30 to 21:30
        }
        
        meal_start_hour, meal_start_min, meal_end_hour, meal_end_min = meal_times[meal_type]
        meal_end_minutes = meal_end_hour * 60 + meal_end_min
        
        # Generate predictions for upcoming 15-minute slots
        slot_num = 0
        temp_time = current_time.replace(minute=(current_time.minute // 15) * 15, second=0, microsecond=0)
        
        while temp_time.hour * 60 + temp_time.minute < meal_end_minutes and slot_num < 8:
            # Move to next 15-minute interval
            temp_time = temp_time + timedelta(minutes=15)
            temp_minutes = temp_time.hour * 60 + temp_time.minute
            
            if temp_minutes >= meal_end_minutes:
                break
            
            try:
                # Create feature vector: [hour, day_of_week, meal_type]
                hour = temp_time.hour
                day_of_week = temp_time.weekday()
                
                features = np.array([[hour, day_of_week, meal_code]], dtype=np.float32)
                
                # Scale features
                features_scaled = self.scaler.transform(features)
                
                # Predict
                predicted_count = self.model.predict(features_scaled, verbose=0)[0][0]
                predicted_count = max(0, int(predicted_count))
                
                # Add some randomness based on trend
                trend_factor = 1.0 + (slot_num * 0.02)  # Slight increase over time
                predicted_count = int(predicted_count * trend_factor)
                predicted_count = min(predicted_count, capacity)
                
                crowd_percentage = (predicted_count / capacity) * 100
                
                time_slot = temp_time.strftime('%I:%M %p')
                
                predictions.append({
                    'time_slot': time_slot,
                    'time_24h': temp_time.strftime('%H:%M'),
                    'predicted_crowd': predicted_count,
                    'capacity': capacity,
                    'crowd_percentage': round(crowd_percentage, 1),
                    'recommendation': 'Avoid' if crowd_percentage > 70 else 'Moderate' if crowd_percentage > 40 else 'Good time',
                    'confidence': 'high'
                })
                
            except Exception as e:
                print(f"[WARN] Prediction error for {self.mess_id} at {temp_time}: {e}")
                continue
            
            slot_num += 1
        
        return predictions
    
    def get_model_info(self):
        """Return information about the loaded model"""
        return {
            'mess_id': self.mess_id,
            'model_loaded': self.model is not None,
            'metadata': self.metadata,
            'model_path': self.model_path
        }


def create_or_load_mess_model(mess_id):
    """
    Factory function to create or load mess-specific model
    """
    model = MessPredictionModel(mess_id)
    
    if model.model is None:
        print(f"[WARN] No trained model for {mess_id}. Run: python train_tensorflow.py {mess_id}")
        return None
    
    return model


if __name__ == "__main__":
    # Test
    import sys
    mess_id = sys.argv[1] if len(sys.argv) > 1 else 'alder'
    
    print(f"Testing prediction model for {mess_id}...")
    model = create_or_load_mess_model(mess_id)
    
    if model:
        print(f"[OK] Model loaded for {mess_id}")
        print(f"  Info: {model.get_model_info()}")
        
        # Test prediction
        now = datetime.now()
        preds = model.predict_next_slots_15min(now, 25, 100)
        
        if preds:
            print(f"\n[OK] Generated {len(preds)} predictions for {mess_id}:")
            for pred in preds[:3]:
                print(f"  - {pred['time_slot']}: {pred['predicted_crowd']}/{pred['capacity']} ({pred['crowd_percentage']}%)")
        else:
            print(f"[INFO] No predictions (likely outside meal hours)")
