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

# Add ml_model to path to import mess_prediction_model
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'ml_model'))

from mess_prediction_model import MessPredictionModel, create_or_load_mess_model

class PredictionService:
    """
    Service for getting mess-specific crowd predictions
    Loads the appropriate trained model for each mess
    """
    
    def __init__(self):
        self.models_cache = {}
    
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
            return {
                'error': f'Model not trained for mess: {mess_id}',
                'mess_id': mess_id,
                'predictions': []
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
