#!/usr/bin/env python3
"""
Quick verification that models can load and make predictions
"""

from mess_prediction_model import MessPredictionModel
from datetime import datetime

print("=" * 70)
print("MODEL LOADING AND PREDICTION VERIFICATION")
print("=" * 70)

messes = ['alder', 'oak', 'pine']
test_times = [
    (8, 0, "breakfast"),
    (13, 0, "lunch"),
    (20, 0, "dinner"),
]

all_passed = True

for mess in messes:
    print(f"\n[TEST] Loading model for {mess.upper()}...")
    try:
        model = MessPredictionModel(mess)
        print(f"[OK] Model loaded successfully")
        
        # Check metadata
        info = model.get_model_info()
        print(f"[OK] Metadata: {info['mess_id']} - {info['input_features']}")
        
        # Test predictions at different times
        for hour, minute, meal_name in test_times:
            meal_type, code = model.get_meal_type(hour, minute)
            if meal_type == meal_name:
                print(f"[PASS] {hour:02d}:{minute:02d} detected as {meal_name}")
            else:
                print(f"[FAIL] {hour:02d}:{minute:02d} expected {meal_name}, got {meal_type}")
                all_passed = False
                
    except Exception as e:
        print(f"[ERROR] Failed to load model for {mess}: {e}")
        all_passed = False

print("\n" + "=" * 70)
if all_passed:
    print("[SUCCESS] All models loaded and working correctly!")
else:
    print("[FAILURE] Some tests failed")
print("=" * 70)
