#!/usr/bin/env python3
"""
Test script to validate meal time windows are correctly implemented
Tests the exact boundaries: 7:30-9:30, 12:00-14:00, 19:30-21:30
"""

from datetime import datetime, timedelta
from mess_prediction_model import MessPredictionModel

def test_meal_time_boundaries():
    """Test that meal time detection works correctly at boundaries"""
    
    test_cases = [
        # Breakfast tests
        (7, 29, None, "Before breakfast (7:29)"),
        (7, 30, 'breakfast', "Breakfast start (7:30)"),
        (8, 30, 'breakfast', "Breakfast middle (8:30)"),
        (9, 29, 'breakfast', "Breakfast end (9:29)"),
        (9, 30, None, "After breakfast (9:30)"),
        
        # Lunch tests
        (11, 59, None, "Before lunch (11:59)"),
        (12, 0, 'lunch', "Lunch start (12:00)"),
        (13, 0, 'lunch', "Lunch middle (13:00)"),
        (14, 0, 'lunch', "Lunch end (14:00)"),
        (14, 1, None, "After lunch (14:01)"),
        
        # Dinner tests
        (19, 29, None, "Before dinner (19:29)"),
        (19, 30, 'dinner', "Dinner start (19:30)"),
        (20, 30, 'dinner', "Dinner middle (20:30)"),
        (21, 29, 'dinner', "Dinner end (21:29)"),
        (21, 30, None, "After dinner (21:30)"),
        
        # Outside all meals
        (6, 0, None, "Early morning (6:00)"),
        (15, 0, None, "Afternoon (15:00)"),
        (22, 0, None, "Late night (22:00)"),
    ]
    
    print("=" * 70)
    print("MEAL TIME BOUNDARY TESTS")
    print("=" * 70)
    
    passed = 0
    failed = 0
    
    for hour, minute, expected_meal, description in test_cases:
        # Get meal type from the model's method
        model = MessPredictionModel('alder')
        meal_type, meal_code = model.get_meal_type(hour, minute)
        
        status = "[PASS]" if meal_type == expected_meal else "[FAIL]"
        
        if meal_type == expected_meal:
            passed += 1
        else:
            failed += 1
        
        time_str = f"{hour:02d}:{minute:02d}"
        expected_str = f"Expected: {expected_meal if expected_meal else 'None (outside meals)':.<20}"
        actual_str = f"Got: {meal_type if meal_type else 'None (outside meals)'}"
        
        print(f"{status} | {time_str} | {description:.<25} | {expected_str} | {actual_str}")
    
    print("=" * 70)
    print(f"Results: {passed} passed, {failed} failed out of {len(test_cases)} tests")
    print("=" * 70)
    
    return failed == 0

if __name__ == "__main__":
    success = test_meal_time_boundaries()
    exit(0 if success else 1)
