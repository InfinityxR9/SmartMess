import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Authenticates a student using Enrollment ID + Date of Birth
  /// Returns user data if valid, null if not found
  Future<Map<String, dynamic>?> authenticateStudent(
    String enrollmentId,
    String dateOfBirth,
  ) async {
    try {
      print('[StudentAuth] Authenticating: $enrollmentId');

      // Query students collection where enrollmentId matches
      final query = await _firestore
          .collection('loginCredentials')
          .where('enrollmentId', isEqualTo: enrollmentId.toUpperCase())
          .where('type', isEqualTo: 'student')
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('[StudentAuth] Student not found: $enrollmentId');
        return null;
      }

      final userData = query.docs.first.data();
      final storedDob = userData['password'] as String?;

      // Verify date of birth matches
      if (storedDob != dateOfBirth) {
        print('[StudentAuth] DOB mismatch for $enrollmentId');
        return null;
      }

      print('[StudentAuth] Authentication successful: ${userData['name']}');
      
      // Return user data with ID
      return {
        'userId': query.docs.first.id,
        ...userData,
      };
    } catch (e) {
      print('[StudentAuth] Authentication error: $e');
      return null;
    }
  }

  /// Get student's mess information from loginCredentials
  Future<Map<String, dynamic>?> getStudentMessInfo(String messId) async {
    try {
      print('[StudentAuth] Getting mess info for: $messId');
      
      final messDoc = await _firestore.collection('messes').doc(messId).get();
      
      if (!messDoc.exists) {
        print('[StudentAuth] Mess not found: $messId');
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
      print('[StudentAuth] Error getting mess info: $e');
      return null;
    }
  }

  /// Verify student belongs to a specific mess
  Future<bool> isStudentInMess(String messId, String targetMessId) async {
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
                'messName': doc['messName'],
                'messCode': doc['messCode'],
                'capacity': doc['capacity'],
              })
          .toList();
    } catch (e) {
      print('[StudentAuth] Error getting messes: $e');
      return [];
    }
  }
}
