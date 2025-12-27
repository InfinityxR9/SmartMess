#!/usr/bin/env python3
"""
Updated prediction_model.py for backend
Loads mess-specific TensorFlow models trained by train_tensorflow.py
Supports mess isolation for predictions
"""

import os
import sys
import json
from datetime import datetime, timedelta
import numpy as np

def _resolve_ml_model_dir():
    env_path = os.environ.get('ML_MODEL_DIR')
    candidates = []
    if env_path:
        candidates.append(env_path)
    base_dir = os.path.dirname(os.path.abspath(__file__))
    candidates.extend([
        os.path.join(base_dir, '..', 'ml_model'),
        os.path.join(base_dir, 'ml_model'),
        os.path.join(os.getcwd(), 'ml_model'),
        '/ml_model',
    ])
    for path in candidates:
        if path and os.path.isdir(path):
            return os.path.abspath(path)
    return None

# Add ml_model to path to import mess_prediction_model
_ML_MODEL_DIR = _resolve_ml_model_dir()
if _ML_MODEL_DIR:
    sys.path.insert(0, _ML_MODEL_DIR)
else:
    print('[WARN] ml_model directory not found. Predictions may be unavailable.')

from mess_prediction_model import MessPredictionModel, create_or_load_mess_model

class PredictionService:
    """
    Service for getting mess-specific crowd predictions
    Loads the appropriate trained model for each mess
    """
    
    def __init__(self):
        self.models_cache = {}

    def _fallback_predictions(self, current_time, current_count, capacity):
        """Generate simple fallback predictions when no model is available."""
        # Determine meal window
        def meal_type_for(dt):
            hour = dt.hour
            minute = dt.minute
            if 7 < hour < 9 or (hour == 7 and minute >= 30) or (hour == 9 and minute < 30):
                return 'breakfast'
            if 12 <= hour < 14 or (hour == 14 and minute == 0):
                return 'lunch'
            if 19 < hour < 21 or (hour == 19 and minute >= 30) or (hour == 21 and minute < 30):
                return 'dinner'
            return None

        meal_type = meal_type_for(current_time)
        if meal_type is None:
            return []

        meal_times = {
            'breakfast': (7, 30, 9, 30),
            'lunch': (12, 0, 14, 0),
            'dinner': (19, 30, 21, 30),
        }

        start_h, start_m, end_h, end_m = meal_times[meal_type]
        meal_end_minutes = end_h * 60 + end_m

        predictions = []
        temp_time = current_time.replace(minute=(current_time.minute // 15) * 15, second=0, microsecond=0)

        baseline = max(current_count, int(capacity * 0.15))
        growth_step = max(1, int(capacity * 0.04))

        slot_num = 0
        while temp_time.hour * 60 + temp_time.minute < meal_end_minutes and slot_num < 8:
            temp_time = temp_time + timedelta(minutes=15)
            if temp_time.hour * 60 + temp_time.minute >= meal_end_minutes:
                break

            predicted_count = min(capacity, baseline + (slot_num + 1) * growth_step)
            crowd_percentage = (predicted_count / capacity) * 100 if capacity else 0

            predictions.append({
                'time_slot': temp_time.strftime('%I:%M %p'),
                'time_24h': temp_time.strftime('%H:%M'),
                'predicted_crowd': int(predicted_count),
                'capacity': capacity,
                'crowd_percentage': round(crowd_percentage, 1),
                'recommendation': 'Avoid' if crowd_percentage > 70 else 'Moderate' if crowd_percentage > 40 else 'Good time',
                'confidence': 'low'
            })
            slot_num += 1

        return predictions

    def get_prediction_model(self, mess_id):
        """
        Get or load the prediction model for a specific mess
        Caches loaded models in memory
        """
        if mess_id not in self.models_cache:
            model = create_or_load_mess_model(mess_id)
            if model:
                self.models_cache[mess_id] = model
            else:
                return None
        
        return self.models_cache[mess_id]
    
    def predict_next_slots(self, mess_id, current_time, current_count, capacity):
        """
        Generate predictions for the next 15-minute slots for a specific mess
        Ensures predictions are mess-isolated
        """
        # Get mess-specific model
        model = self.get_prediction_model(mess_id)
        
        if model is None:
            predictions = self._fallback_predictions(
                current_time=current_time,
                current_count=current_count,
                capacity=capacity
            )
            return {
                'messId': mess_id,
                'timestamp': datetime.now().isoformat(),
                'date': current_time.strftime('%Y-%m-%d'),
                'mealType': 'none',
                'current_crowd': current_count,
                'capacity': capacity,
                'current_percentage': round((current_count / capacity) * 100, 1) if capacity else 0,
                'predictions': predictions,
                'model_info': {'fallback': True, 'reason': 'model_not_available'}
            }
        
        # Generate predictions using mess-specific model
        predictions = model.predict_next_slots_15min(
            current_time=current_time,
            current_count=current_count,
            capacity=capacity
        )
        
        return {
            'messId': mess_id,
            'timestamp': datetime.now().isoformat(),
            'date': current_time.strftime('%Y-%m-%d'),
            'mealType': model.get_meal_type(current_time.hour, current_time.minute)[0] or 'none',
            'current_crowd': current_count,
            'capacity': capacity,
            'current_percentage': round((current_count / capacity) * 100, 1),
            'predictions': predictions,
            'model_info': model.get_model_info()
        }
    
    def get_model_info(self, mess_id):
        """Get information about the trained model for a mess"""
        model = self.get_prediction_model(mess_id)
        
        if model is None:
            return {'error': f'No model for mess: {mess_id}'}
        
        return model.get_model_info()


# Global prediction service instance
_prediction_service = None

def get_prediction_service():
    """Get the global prediction service instance"""
    global _prediction_service
    if _prediction_service is None:
        _prediction_service = PredictionService()
    return _prediction_service


def predict_for_mess(mess_id, current_time=None, current_count=0, capacity=100):
    """
    Convenience function to get predictions for a specific mess
    
    Args:
        mess_id: The mess to get predictions for
        current_time: Current time (default: now)
        current_count: Current crowd count
        capacity: Mess capacity
    
    Returns:
        Dictionary with predictions
    """
    if current_time is None:
        current_time = datetime.now()
    
    service = get_prediction_service()
    return service.predict_next_slots(mess_id, current_time, current_count, capacity)


if __name__ == "__main__":
    # Test usage
    mess_id = sys.argv[1] if len(sys.argv) > 1 else 'alder'
    
    print(f"Testing predictions for mess: {mess_id}")
    
    service = get_prediction_service()
    result = service.predict_next_slots(
        mess_id=mess_id,
        current_time=datetime.now(),
        current_count=25,
        capacity=100
    )
    
    print(json.dumps(result, indent=2, default=str))
