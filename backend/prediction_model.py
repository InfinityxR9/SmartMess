import numpy as np
from datetime import datetime, timedelta
import json
import os
from pathlib import Path

class PredictionModel:
    """
    Prediction model for mess crowd prediction 
    Generates 15-minute interval predictions during meal times
    """
    
    def __init__(self):
        self.model_path = 'model_data.json'
        self.historical_data = self._load_model()
        
    def _load_model(self):
        """Load model data from file if exists"""
        if os.path.exists(self.model_path):
            with open(self.model_path, 'r') as f:
                return json.load(f)
        return {
            'time_interval_averages': {},
            'trained': False,
        }
    
    def _save_model(self):
        """Save model data to file"""
        with open(self.model_path, 'w') as f:
            json.dump(self.historical_data, f)
    
    def train(self, scan_data):
        """
        Train the model with historical attendance data
        scan_data: list of dicts with 'ts' (timestamp float) and 'messId'
        """
        if not scan_data:
            print("✗ No training data provided")
            return False
        
        time_interval_counts = {}
        
        for scan in scan_data:
            try:
                # Get timestamp - could be float or string
                ts = scan.get('ts')
                timestamp_str = scan.get('timestamp')
                
                # Try to parse timestamp
                dt = None
                if isinstance(ts, float):
                    # Unix timestamp
                    dt = datetime.fromtimestamp(ts)
                elif isinstance(timestamp_str, str):
                    # ISO format string
                    dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                elif isinstance(ts, str):
                    # String timestamp
                    dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
                else:
                    # Assume it's a datetime object
                    dt = ts
                
                if dt is None:
                    continue
                
                # Extract hour and 15-minute bucket
                hour = dt.hour
                minute_bucket = (dt.minute // 15)  # 0, 1, 2, or 3
                mess_id = scan.get('messId', 'unknown')
                
                # Create key: messId_hour_minuteBucket (e.g., mess1_12_2 for 12:30-12:45)
                key = f"{mess_id}_{hour}_{minute_bucket}"
                
                if key not in time_interval_counts:
                    time_interval_counts[key] = 0
                time_interval_counts[key] += 1
            except Exception as e:
                print(f"Warning: Error processing attendance record: {e}")
                continue
        
        if len(time_interval_counts) < 3:
            print("✗ Insufficient training data (need at least 3 data points)")
            return False
        
        # Store averages
        self.historical_data['time_interval_averages'] = time_interval_counts
        self.historical_data['trained'] = True
        self._save_model()
        
        print(f"✓ Model trained with {len(scan_data)} samples")
        print(f"✓ Generated {len(time_interval_counts)} 15-minute interval data points")
        return True
    
    def predict_next_slots_15min(self, mess_id, current_time, current_count, capacity, meal_info, db):
        """
        Real-time prediction with 15-minute intervals
        Queries actual attendance data from Firebase for better predictions
        
        Args:
            mess_id: ID of the mess
            current_time: Current datetime
            current_count: Current attendance count (at current time)
            capacity: Mess capacity
            meal_info: Dict with meal type and time range info
            db: Firestore database instance
        
        Returns:
            List of predictions for upcoming 15-minute intervals
        """
        predictions = []
        
        if not meal_info:
            return predictions
        
        date_str = current_time.strftime('%Y-%m-%d')
        meal_type = meal_info['type']
        meal_start_minutes = meal_info['start_minutes']
        meal_end_minutes = meal_info['end_minutes']
        
        # Round current time to nearest 15-minute interval
        current_minutes = current_time.hour * 60 + current_time.minute
        current_bucket = (current_time.minute // 15)
        
        # Generate predictions for upcoming 15-minute slots
        slot_num = 0
        temp_time = current_time.replace(minute=(current_bucket * 15), second=0, microsecond=0)
        
        while temp_time.hour * 60 + temp_time.minute < meal_end_minutes and slot_num < 10:
            # Move to next 15-minute interval
            temp_time = temp_time + timedelta(minutes=15)
            temp_minutes = temp_time.hour * 60 + temp_time.minute
            
            if temp_minutes >= meal_end_minutes:
                break
            
            # Try to get historical data for this time slot
            predicted_count = current_count  # Default to current count
            
            try:
                # Query historical data: attendance/<messId>/<date>/<meal>/students
                # Average counts across multiple days for this time slot
                historical_count = 0
                historical_days = 0
                
                # Check past 7 days for same meal type
                for day_offset in range(1, 8):
                    past_date = current_time - timedelta(days=day_offset)
                    past_date_str = past_date.strftime('%Y-%m-%d')
                    
                    try:
                        students_ref = db.collection(f'attendance/{mess_id}/{past_date_str}/{meal_type}/students')
                        students = students_ref.stream()
                        day_count = sum(1 for _ in students)
                        if day_count > 0:
                            historical_count += day_count
                            historical_days += 1
                    except:
                        continue
                
                if historical_days > 0:
                    # Use historical average, with slight variation
                    avg_historical = historical_count / historical_days
                    predicted_count = int(avg_historical * (0.8 + np.random.random() * 0.4))
                else:
                    # No historical data, trend based on current
                    trend_factor = 1.0 + (slot_num * 0.05)  # Slight increase over time
                    predicted_count = int(current_count * trend_factor)
                    
            except Exception as e:
                print(f"Warning: Could not fetch historical data: {e}")
                # Fallback: trend-based prediction
                trend_factor = 1.0 + (slot_num * 0.05)
                predicted_count = int(current_count * trend_factor)
            
            # Ensure reasonable bounds
            predicted_count = max(0, min(predicted_count, capacity))
            crowd_percentage = (predicted_count / capacity) * 100
            
            time_slot = temp_time.strftime('%I:%M %p')
            
            predictions.append({
                'time_slot': time_slot,
                'time_24h': temp_time.strftime('%H:%M'),
                'predicted_crowd': predicted_count,
                'capacity': capacity,
                'crowd_percentage': round(crowd_percentage, 1),
                'recommendation': 'Avoid' if crowd_percentage > 70 else ('Moderate' if crowd_percentage > 40 else 'Good time'),
                'confidence': 'high' if historical_days > 3 else 'medium' if historical_days > 0 else 'low'
            })
            
            slot_num += 1
        
        return predictions
    
    def predict_next_slots(self, mess_id, current_time, current_count, capacity, meal_info):
        """
        Predict crowd levels for 15-minute intervals during current meal time
        
        Args:
            mess_id: ID of the mess
            current_time: Current datetime
            current_count: Current attendance count
            capacity: Mess capacity
            meal_info: Dict with meal type and time range
        
        Returns:
            List of predictions for 15-minute intervals
        """
        predictions = []
        
        if not meal_info:
            return predictions
        
        # Calculate 15-minute intervals from current time to end of meal
        current_minutes = current_time.hour * 60 + current_time.minute
        meal_end_minutes = meal_info['end_minutes']
        
        # Round current time to nearest 15-minute bucket for consistency
        current_bucket = (current_time.minute // 15)
        
        # Generate predictions for each 15-minute slot
        slot_num = 0
        temp_time = current_time.replace(minute=(current_bucket * 15), second=0, microsecond=0)
        
        while temp_time.hour * 60 + temp_time.minute < meal_end_minutes and slot_num < 8:
            # Move to next 15-minute interval
            temp_time = temp_time + timedelta(minutes=15)
            if temp_time.hour * 60 + temp_time.minute >= meal_end_minutes:
                break
            
            hour = temp_time.hour
            minute_bucket = (temp_time.minute // 15)
            
            # Look up historical data for this time slot
            key = f"{mess_id}_{hour}_{minute_bucket}"
            base_count = self.historical_data.get('time_interval_averages', {}).get(key, current_count)
            
            # Add slight variation based on trend
            predicted_count = int(base_count * (0.85 + np.random.random() * 0.3))
            crowd_percentage = min(100, (predicted_count / capacity) * 100)
            
            time_slot = temp_time.strftime('%I:%M %p')
            
            predictions.append({
                'time_slot': time_slot,
                'time_24h': temp_time.strftime('%H:%M'),
                'predicted_crowd': predicted_count,
                'capacity': capacity,
                'crowd_percentage': round(crowd_percentage, 1),
                'recommendation': 'Avoid' if crowd_percentage > 70 else 'Moderate crowd' if crowd_percentage > 40 else 'Good time',
            })
            
            slot_num += 1
        
        return predictions

