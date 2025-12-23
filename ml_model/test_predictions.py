#!/usr/bin/env python3
"""
Test the backend prediction model
"""

import sys
import os
from datetime import datetime

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'backend'))

from prediction_model import PredictionModel

def test_prediction_model():
    """Test the prediction model"""
    print("=" * 60)
    print("Testing Prediction Model")
    print("=" * 60)
    
    # Initialize model
    print("\n[1/3] Initializing prediction model...")
    model = PredictionModel()
    print(f"✓ Model initialized")
    print(f"  - Trained: {model.historical_data.get('trained', False)}")
    print(f"  - Time intervals learned: {len(model.historical_data.get('time_interval_averages', {}))}")
    
    # Test predict_next_slots()
    print("\n[2/3] Testing predict_next_slots() method...")
    try:
        current_time = datetime.now()
        meal_info = {
            'type': 'breakfast',
            'start_minutes': 7 * 60 + 30,  # 7:30 AM
            'end_minutes': 9 * 60 + 30     # 9:30 AM
        }
        
        # Override to lunch if current time is around noon
        if 11 <= current_time.hour < 15:
            meal_info = {
                'type': 'lunch',
                'start_minutes': 12 * 60,      # 12:00 PM
                'end_minutes': 14 * 60         # 2:00 PM
            }
        
        predictions = model.predict_next_slots(
            mess_id='mess1',
            current_time=current_time,
            current_count=25,
            capacity=100,
            meal_info=meal_info
        )
        
        if predictions:
            print(f"✓ Generated {len(predictions)} predictions for {meal_info['type']}")
            for pred in predictions[:2]:
                print(f"  - {pred['time_slot']}: {pred['predicted_crowd']}/{pred['capacity']} ({pred['crowd_percentage']}%)")
        else:
            print("⚠ No predictions generated (likely outside meal hours)")
    
    except Exception as e:
        print(f"✗ Error testing predict_next_slots(): {e}")
        import traceback
        traceback.print_exc()
        return False
    
    # Test predict_next_slots_15min() with mock db
    print("\n[3/3] Testing predict_next_slots_15min() method...")
    try:
        from unittest.mock import MagicMock
        mock_db = MagicMock()
        
        predictions = model.predict_next_slots_15min(
            mess_id='mess1',
            current_time=current_time,
            current_count=25,
            capacity=100,
            meal_info=meal_info,
            db=mock_db
        )
        
        if predictions:
            print(f"✓ Generated {len(predictions)} real-time predictions")
            for pred in predictions[:2]:
                print(f"  - {pred['time_slot']}: {pred['predicted_crowd']}/{pred['capacity']} ({pred['crowd_percentage']}%)")
        else:
            print("⚠ No predictions generated")
    
    except Exception as e:
        print(f"✗ Error testing predict_next_slots_15min(): {e}")
        import traceback
        traceback.print_exc()
        return False
    
    print("\n" + "=" * 60)
    print("✓ All tests completed successfully!")
    print("=" * 60)
    return True

if __name__ == "__main__":
    success = test_prediction_model()
    sys.exit(0 if success else 1)
