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
      if (!_dobMatches(storedDob, dateOfBirth)) {
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
      final messCode = messData?['messCode'] as String?;
      Map<String, dynamic>? managerInfo;

      if (messCode != null && messCode.isNotEmpty) {
        var managerQuery = await _firestore
            .collection('loginCredentials')
            .where('messCode', isEqualTo: messCode)
            .where('type', isEqualTo: 'manager')
            .limit(1)
            .get();

        if (managerQuery.docs.isEmpty) {
          managerQuery = await _firestore
              .collection('loginCredentials')
              .where('messcode', isEqualTo: messCode)
              .where('type', isEqualTo: 'manager')
              .limit(1)
              .get();
        }

        if (managerQuery.docs.isNotEmpty) {
          managerInfo = managerQuery.docs.first.data();
        }
      }

      return {
        'messId': messId,
        'name': messData?['name'],
        'messCode': messCode,
        'capacity': messData?['capacity'],
        'managerName': managerInfo?['name'],
        'managerEmail': managerInfo?['email'],
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

  bool _dobMatches(String? storedDob, String inputDob) {
    if (storedDob == null) {
      return false;
    }

    final storedCandidates = _normalizeDobCandidates(storedDob);
    final inputCandidates = _normalizeDobCandidates(inputDob);

    if (storedCandidates.isNotEmpty && inputCandidates.isNotEmpty) {
      return storedCandidates.intersection(inputCandidates).isNotEmpty;
    }

    return storedDob.trim() == inputDob.trim();
  }

  Set<String> _normalizeDobCandidates(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      return {};
    }

    final separator = cleaned.contains('/')
        ? '/'
        : cleaned.contains('-')
            ? '-'
            : null;

    if (separator == null) {
      return {cleaned};
    }

    final parts = cleaned.split(separator);
    if (parts.length != 3) {
      return {cleaned};
    }

    final p1 = int.tryParse(parts[0]);
    final p2 = int.tryParse(parts[1]);
    final p3 = int.tryParse(parts[2]);

    if (p1 == null || p2 == null || p3 == null) {
      return {cleaned};
    }

    final candidates = <String>{};

    if (parts[0].length == 4) {
      _addCandidate(candidates, p1, p2, p3);
    } else if (parts[2].length == 4) {
      // dd/mm/yyyy
      _addCandidate(candidates, p3, p2, p1);
      // mm/dd/yyyy
      _addCandidate(candidates, p3, p1, p2);
    }

    return candidates;
  }

  void _addCandidate(Set<String> candidates, int year, int month, int day) {
    if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
      return;
    }

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return;
    }

    final normalized =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    candidates.add(normalized);
  }
}
