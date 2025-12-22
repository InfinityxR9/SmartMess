import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Authenticates a manager using Email + Password
  /// Returns user data if valid, null if not found
  Future<Map<String, dynamic>?> authenticateManager(
    String email,
    String password,
  ) async {
    try {
      print('[ManagerAuth] Authenticating: $email');

      // Query loginCredentials collection where email and password match
      final query = await _firestore
          .collection('loginCredentials')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password)
          .where('type', isEqualTo: 'manager')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('[ManagerAuth] Manager not found: $email');
        return null;
      }

      final userData = query.docs.first.data();

      print('[ManagerAuth] Authentication successful: ${userData['name']}');

      // Return user data with ID
      return {
        'userId': query.docs.first.id,
        ...userData,
      };
    } catch (e) {
      print('[ManagerAuth] Authentication error: $e');
      return null;
    }
  }

  /// Get manager's mess information
  Future<Map<String, dynamic>?> getManagerMessInfo(String messId) async {
    try {
      print('[ManagerAuth] Getting mess info for: $messId');

      final messDoc = await _firestore.collection('messes').doc(messId).get();

      if (!messDoc.exists) {
        print('[ManagerAuth] Mess not found: $messId');
        return null;
      }

      final messData = messDoc.data();
      return {
        'messId': messId,
        'name': messData?['name'],
        'messCode': messData?['messCode'],
        'capacity': messData?['capacity'],
      };
    } catch (e) {
      print('[ManagerAuth] Error getting mess info: $e');
      return null;
    }
  }

  /// Verify manager belongs to a specific mess
  Future<bool> isManagerInMess(String messId, String targetMessId) async {
    try {
      return messId == targetMessId;
    } catch (e) {
      return false;
    }
  }

  /// Get all available messes for login screen
  Future<List<Map<String, dynamic>>> getAllMesses() async {
    try {
      final snapshot = await _firestore.collection('messes').get();
      return snapshot.docs
          .map((doc) => {
                'messId': doc.id,
                'name': doc['name'],
                'messCode': doc['messCode'],
                'capacity': doc['capacity'],
              })
          .toList();
    } catch (e) {
      print('[ManagerAuth] Error getting messes: $e');
      return [];
    }
  }

  /// Sign out manager
  Future<void> signOut() async {
    try {
      print('[ManagerAuth] Manager signed out');
    } catch (e) {
      print('[ManagerAuth] Sign-out error: $e');
    }
  }
}
