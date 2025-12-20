import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from sklearn.preprocessing import StandardScaler
import joblib
import json
from datetime import datetime, timedelta

class MessCrowdPredictor:
    """
    Simple linear regression model for crowd prediction.
    Predicts crowd levels for the next 4 hours based on historical data.
    """
    
    def __init__(self, model_path='crowd_model.h5', scaler_path='scaler.pkl'):
        self.model = None
        self.scaler = StandardScaler()
        self.model_path = model_path
        self.scaler_path = scaler_path
        self.hourly_data = {}  # Store hourly averages
        self._load_model()
    
    def _load_model(self):
        """Load model and scaler from disk if they exist"""
        try:
            self.model = keras.models.load_model(self.model_path)
            self.scaler = joblib.load(self.scaler_path)
            print(f"✓ Model loaded from {self.model_path}")
        except:
            print("✗ No existing model found. Will train new model.")
            self.model = None
    
    def _save_model(self):
        """Save model and scaler to disk"""
        self.model.save(self.model_path)
        joblib.dump(self.scaler, self.scaler_path)
        print(f"✓ Model saved to {self.model_path}")
    
    def train(self, scans_data):
        """
        Train the TensorFlow model using historical scan data.
        
        Args:
            scans_data: List of scan documents with timestamp and messId
        """
        if not scans_data:
            print("✗ No training data provided")
            return False
        
        # Convert to DataFrame
        df = pd.DataFrame(scans_data)
        df['ts'] = pd.to_datetime(df['ts'])
        
        # Extract features
        df['hour'] = df['ts'].dt.hour
        df['day_of_week'] = df['ts'].dt.dayofweek
        df['minute_bucket'] = (df['ts'].dt.minute // 15).astype(int)
        
        # Count scans per hour (target variable)
        hourly_counts = df.groupby(['hour', 'day_of_week']).size().reset_index(name='crowd_count')
        
        if len(hourly_counts) < 3:
            print("✗ Insufficient training data (need at least 3 data points)")
            return False
        
        # Prepare features and target
        X = hourly_counts[['hour', 'day_of_week']].values.astype(float)
        y = hourly_counts['crowd_count'].values.astype(float)
        
        # Scale features
        X_scaled = self.scaler.fit_transform(X)
        
        # Build simple TensorFlow regression model
        self.model = keras.Sequential([
            layers.Dense(1, input_shape=(2,))
        ])
        
        self.model.compile(
            optimizer='adam',
            loss='mse',
            metrics=['mae']
        )
        
        # Train model
        self.model.fit(
            X_scaled, y,
            epochs=50,
            batch_size=8,
            verbose=1,
            validation_split=0.2
        )
        
        self._save_model()
        print(f"✓ Model trained with {len(hourly_counts)} data points")
        return True
    
    def predict_next_slots(self, current_hour=None, current_day=None, num_slots=4):
        """
        Predict crowd levels for the next N hours.
        
        Args:
            current_hour: Current hour (0-23), defaults to now
            current_day: Current day of week (0-6), defaults to today
            num_slots: Number of hours to predict
            
        Returns:
            List of predictions with time slot info
        """
        if self.model is None:
            print("✗ Model not trained yet")
            return []
        
        if current_hour is None:
            current_hour = datetime.now().hour
        if current_day is None:
            current_day = datetime.now().weekday()
        
        predictions = []
        
        for i in range(num_slots):
            # Calculate hour and day
            next_hour = (current_hour + i + 1) % 24
            next_day = current_day + ((current_hour + i + 1) // 24)
            next_day = next_day % 7
            
            # Prepare features
            X = np.array([[next_hour, next_day]]).astype(float)
            X_scaled = self.scaler.transform(X)
            
            # Make prediction
            pred = self.model.predict(X_scaled, verbose=0)[0][0]
            pred = max(0, pred)  # Ensure non-negative
            
            predictions.append({
                'time_slot': f"{next_hour}:00",
                'predicted_crowd': int(pred),
                'crowd_percentage': int((pred / 100) * 100),  # Assume capacity is 100 for simple demo
            })
        
        return predictions
    
    def get_hourly_stats(self):
        """Return hourly statistics"""
        return self.hourly_data


if __name__ == '__main__':
    # Example usage
    print("Mess Crowd Prediction Model")
    print("Train this model with your Firebase data")
