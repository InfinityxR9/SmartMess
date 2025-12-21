import numpy as np
from datetime import datetime, timedelta
import json
import os
from pathlib import Path

class PredictionModel:
    """
    Simple prediction model for mess crowd prediction
    Uses time-based features and historical data
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
            'hourly_averages': {},
            'trained': False,
        }
    
    def _save_model(self):
        """Save model data to file"""
        with open(self.model_path, 'w') as f:
            json.dump(self.historical_data, f)
    
    def train(self, scan_data):
        """
        Train the model with historical scan data
        scan_data: list of dicts with 'messId' and 'timestamp'
        """
        hourly_counts = {}
        
        for scan in scan_data:
            try:
                timestamp = datetime.strptime(scan['timestamp'], '%Y-%m-%d %H:%M:%S')
                hour = timestamp.hour
                mess_id = scan['messId']
                
                key = f"{mess_id}_{hour}"
                
                if key not in hourly_counts:
                    hourly_counts[key] = 0
                hourly_counts[key] += 1
            except Exception as e:
                print(f"Error processing scan: {e}")
                continue
        
        # Store averages
        self.historical_data['hourly_averages'] = hourly_counts
        self.historical_data['trained'] = True
        self._save_model()
        
        print(f"Model trained with {len(scan_data)} samples")
    
    def predict_next_slots(self, mess_id, current_count, capacity):
        """
        Predict crowd levels for next 4 hours in 1-hour slots
        """
        predictions = []
        now = datetime.now()
        
        # Generate predictions for next 4 hours
        for i in range(1, 5):
            future_time = now + timedelta(hours=i)
            hour = future_time.hour
            
            # Get historical average for this hour
            key = f"{mess_id}_{hour}"
            base_count = self.historical_data.get('hourly_averages', {}).get(key, current_count)
            
            # Add some randomness to make it realistic
            predicted_count = int(base_count * (0.8 + np.random.random() * 0.4))
            crowd_percentage = min(100, (predicted_count / capacity) * 100)
            
            time_slot = future_time.strftime('%I:%M %p')
            
            predictions.append({
                'time_slot': time_slot,
                'predicted_crowd': predicted_count,
                'crowd_percentage': round(crowd_percentage, 1),
            })
        
        return predictions
