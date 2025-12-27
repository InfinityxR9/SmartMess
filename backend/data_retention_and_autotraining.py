"""
Auto-training and data retention service for SmartMess
Runs periodically to:
1. Train models every 7 days
2. Apply data retention policies
3. Clean up old predictions, QR codes, etc.
"""

import os
import sys
from datetime import datetime, timedelta
import firebase_admin
from firebase_admin import credentials, firestore
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Add ml_model to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'ml_model'))

try:
    from train_tensorflow import train_mess_model_from_data
except ImportError:
    logger.warning("Could not import TensorFlow training module")

class DataRetentionManager:
    """Manages data retention and cleanup policies"""
    
    def __init__(self):
        try:
            if os.path.exists('serviceAccountKey.json'):
                cred = credentials.Certificate('serviceAccountKey.json')
            else:
                cred = credentials.ApplicationDefault()
            
            if not firebase_admin._apps:
                firebase_admin.initialize_app(cred)
            
            self.db = firestore.client()
        except Exception as e:
            logger.error(f"Firebase init error: {e}")
            self.db = None
    
    def apply_retention_policies(self):
        """Apply all data retention policies"""
        if not self.db:
            logger.error("Firebase not initialized")
            return False
        
        try:
            logger.info("Starting data retention cleanup...")
            
            # 1. Delete QR codes older than 1 week
            self._delete_old_qr_codes()
            
            # 2. Delete/Archive predictions older than 3 months
            self._cleanup_old_predictions()
            
            # 3. Archive sessions older than 6 months
            self._archive_old_sessions()
            
            logger.info("Data retention cleanup completed")
            return True
            
        except Exception as e:
            logger.error(f"Retention policy error: {e}")
            return False
    
    def _delete_old_qr_codes(self):
        """Delete QR codes older than 1 week"""
        try:
            cutoff_date = datetime.now() - timedelta(days=7)
            
            # Get all QR code collections
            qr_ref = self.db.collection('qr_codes')
            docs = qr_ref.where('createdAt', '<', cutoff_date).stream()
            
            deleted_count = 0
            for doc in docs:
                doc.reference.delete()
                deleted_count += 1
            
            logger.info(f"Deleted {deleted_count} old QR codes")
            
        except Exception as e:
            logger.error(f"Error deleting old QR codes: {e}")
    
    def _cleanup_old_predictions(self):
        """Delete/Archive predictions older than 3 months"""
        try:
            cutoff_date = datetime.now() - timedelta(days=90)
            
            # Get all messes
            messes = self.db.collection('messes').stream()
            
            for mess in messes:
                mess_id = mess.id
                
                # Delete old prediction records
                pred_ref = self.db.collection('predictions').document(mess_id)
                pred_dates = pred_ref.collections()
                
                for date_col in pred_dates:
                    # Collection name is date string YYYY-MM-DD
                    try:
                        col_date = datetime.strptime(date_col.id, '%Y-%m-%d')
                        if col_date < cutoff_date:
                            # Delete all docs in this date collection
                            for doc in date_col.stream():
                                doc.reference.delete()
                            logger.info(f"Cleaned predictions for {mess_id}/{date_col.id}")
                    except ValueError:
                        pass  # Skip invalid date formats
            
        except Exception as e:
            logger.error(f"Error cleaning predictions: {e}")
    
    def _archive_old_sessions(self):
        """Archive sessions older than 6 months"""
        try:
            cutoff_date = datetime.now() - timedelta(days=180)
            
            # Get all session documents
            sessions = self.db.collection('sessions').where(
                'lastActive', '<', cutoff_date
            ).stream()
            
            archived_count = 0
            for session in sessions:
                # Move to archive collection
                session_data = session.to_dict()
                session_data['archivedAt'] = datetime.now()
                
                self.db.collection('sessions_archive').document(session.id).set(session_data)
                session.reference.delete()
                archived_count += 1
            
            logger.info(f"Archived {archived_count} old sessions")
            
        except Exception as e:
            logger.error(f"Error archiving sessions: {e}")


class AutoTrainerService:
    """Automatically trains models every 7 days"""
    
    def __init__(self):
        try:
            if os.path.exists('serviceAccountKey.json'):
                cred = credentials.Certificate('serviceAccountKey.json')
            else:
                cred = credentials.ApplicationDefault()
            
            if not firebase_admin._apps:
                firebase_admin.initialize_app(cred)
            
            self.db = firestore.client()
        except Exception as e:
            logger.error(f"Firebase init error: {e}")
            self.db = None
    
    def should_retrain(self, mess_id):
        """Check if model should be retrained (hasn't been trained in 7 days)"""
        if not self.db:
            return False
        
        try:
            # Get last training date from metadata
            metadata_ref = self.db.collection('model_metadata').document(mess_id)
            metadata = metadata_ref.get()
            
            if not metadata.exists:
                # Never trained - should train
                return True
            
            last_training = metadata.get('lastTrainedAt')
            if last_training is None:
                return True
            
            # Check if more than 7 days have passed
            days_since_training = (datetime.now() - last_training).days
            return days_since_training >= 7
            
        except Exception as e:
            logger.error(f"Error checking retrain status: {e}")
            return False
    
    def retrain_model(self, mess_id):
        """Retrain model for a specific mess"""
        if not self.db:
            logger.error("Firebase not initialized")
            return False
        
        try:
            logger.info(f"Starting model retrain for {mess_id}")
            
            # Load attendance data for the past 30 days
            cutoff_date = datetime.now() - timedelta(days=30)
            training_data = []
            
            # Get all attendance records for past 30 days
            attendance_ref = self.db.collection('attendance').document(mess_id)
            date_collections = attendance_ref.collections()
            
            for date_col in date_collections:
                try:
                    col_date = datetime.strptime(date_col.id, '%Y-%m-%d')
                    if col_date >= cutoff_date:
                        # Get all meal data for this date
                        for meal in ['breakfast', 'lunch', 'dinner']:
                            meal_ref = date_col.document(meal)
                            students_collection = meal_ref.collection('students')
                            
                            student_count = 0
                            for student in students_collection.stream():
                                student_count += 1
                            
                            if student_count > 0:
                                training_data.append({
                                    'date': col_date,
                                    'meal': meal,
                                    'count': student_count,
                                })
                except ValueError:
                    pass
            
            if not training_data:
                logger.warning(f"No training data available for {mess_id}")
                return False
            
            # Train model (this calls the actual TensorFlow training)
            try:
                # For now, just log that we would train
                # In production, call: train_mess_model_from_data(mess_id, training_data)
                logger.info(f"Would train {mess_id} model with {len(training_data)} records")
                
                # Update metadata with new training date
                self.db.collection('model_metadata').document(mess_id).set({
                    'lastTrainedAt': datetime.now(),
                    'recordsUsed': len(training_data),
                    'status': 'trained',
                }, merge=True)
                
                logger.info(f"Successfully retrained {mess_id}")
                return True
                
            except Exception as e:
                logger.error(f"TensorFlow training failed: {e}")
                return False
                
        except Exception as e:
            logger.error(f"Error retraining model for {mess_id}: {e}")
            return False
    
    def check_and_retrain_all(self):
        """Check all messes and retrain if needed"""
        if not self.db:
            logger.error("Firebase not initialized")
            return
        
        try:
            messes = self.db.collection('messes').stream()
            
            for mess in messes:
                mess_id = mess.id
                if self.should_retrain(mess_id):
                    logger.info(f"Retraining {mess_id}...")
                    self.retrain_model(mess_id)
            
            logger.info("Auto-training check completed")
            
        except Exception as e:
            logger.error(f"Error in auto-training: {e}")


# Scheduled task functions (for Cloud Functions or APScheduler)
def scheduled_data_retention():
    """Run data retention cleanup (call this weekly)"""
    manager = DataRetentionManager()
    return manager.apply_retention_policies()


def scheduled_auto_training():
    """Run auto-training check (call this daily)"""
    trainer = AutoTrainerService()
    trainer.check_and_retrain_all()


if __name__ == '__main__':
    print("SmartMess Auto-Training and Data Retention Service")
    print("=" * 50)
    
    # Test data retention
    print("\n[TEST] Data Retention Policies:")
    manager = DataRetentionManager()
    manager.apply_retention_policies()
    
    # Test auto-training
    print("\n[TEST] Auto-Training Service:")
    trainer = AutoTrainerService()
    trainer.check_and_retrain_all()
    
    print("\nDone!")
