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
    
    def train(self, attendance_data):
        """
        Train the TensorFlow model using historical attendance data.
        
        Args:
            attendance_data: List of attendance documents with 'ts' (timestamp) and 'messId'
        """
        if not attendance_data:
            print("✗ No training data provided")
            return False
        
        try:
            # Convert to DataFrame
            df = pd.DataFrame(attendance_data)
            
            # Handle both datetime objects and timestamp strings
            def parse_timestamp(ts):
                if isinstance(ts, str):
                    try:
                        return pd.to_datetime(ts)
                    except:
                        return None
                else:
                    return pd.to_datetime(ts)
            
            df['ts'] = df['ts'].apply(parse_timestamp)
            df = df[df['ts'].notna()]  # Remove invalid timestamps
            
            if len(df) == 0:
                print("✗ No valid timestamp data found")
                return False
            
            # Extract features
            df['hour'] = df['ts'].dt.hour
            df['day_of_week'] = df['ts'].dt.dayofweek
            df['minute_bucket'] = (df['ts'].dt.minute // 15).astype(int)
            
            # Count attendance records per hour (target variable)
            hourly_counts = df.groupby(['hour', 'day_of_week']).size().reset_index(name='crowd_count')
            
            if len(hourly_counts) < 3:
                print(f"✗ Insufficient training data: {len(hourly_counts)} data points (need at least 3)")
                print("  Tip: Collect more attendance data to improve predictions")
                return False
            
            # Prepare features and target
            X = hourly_counts[['hour', 'day_of_week']].values.astype(float)
            y = hourly_counts['crowd_count'].values.astype(float)
            
            # Scale features
            X_scaled = self.scaler.fit_transform(X)
            
            # Build simple TensorFlow regression model
            self.model = keras.Sequential([
                layers.Dense(32, input_shape=(2,), activation='relu'),
                layers.Dense(16, activation='relu'),
                layers.Dense(1)
            ])
            
            self.model.compile(
                optimizer='adam',
                loss='mse',
                metrics=['mae']
            )
            
            # Train model with smaller verbosity
            print(f"Training on {len(df)} attendance records, {len(hourly_counts)} unique time slots...")
            self.model.fit(
                X_scaled, y,
                epochs=30,
                batch_size=4,
                verbose=0,
                validation_split=0.2
            )
            
            self._save_model()
            print(f"✓ Model trained with {len(df)} attendance records")
            print(f"✓ {len(hourly_counts)} unique hourly time slots identified")
            return True
            
        except Exception as e:
            print(f"✗ Error during training: {e}")
            return False
    
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
        
        try:
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
                
                # Assume average capacity is 100 for percentage calculation
                crowd_percentage = min(100, (pred / 100) * 100)
                
                predictions.append({
                    'time_slot': f"{next_hour:02d}:00",
                    'time_24h': f"{next_hour:02d}:00",
                    'predicted_crowd': int(pred),
                    'crowd_percentage': round(crowd_percentage, 1),
                })
        except Exception as e:
            print(f"Warning: Prediction failed: {e}")
            return []
        
        return predictions
    
    def get_hourly_stats(self):
        """Return hourly statistics"""
        return self.hourly_data


if __name__ == '__main__':
    # Example usage
    print("Mess Crowd Prediction Model")
    print("Train this model with your Firebase attendance data")
    print("\nUsage:")
    print("  python train.py  # Train the model")
    print("  python -c 'from crowd_predictor import MessCrowdPredictor; p = MessCrowdPredictor(); print(p.predict_next_slots())'  # Make predictions")
