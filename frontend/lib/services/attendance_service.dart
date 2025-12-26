import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const uuid = Uuid();

  /// Mark attendance for a student via QR code
  /// Returns true if marked successfully, false if already marked or error
  Future<bool> markAttendanceViaQR({
    required String messId,
    required String studentId,
    required String mealType,
    required String enrollmentId,
    required String studentName,
    String? qrCodeId,
    String? qrGeneratedAt,
    String? qrExpiresAt,
  }) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final normalizedStudentId = studentId.trim().isNotEmpty ? studentId : uuid.v4();
      final normalizedEnrollmentId = _normalizeEnrollmentId(enrollmentId);
      final normalizedStudentName = _normalizeStudentName(studentName);

      // Check if already marked
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc(messId)
          .collection(dateStr)
          .doc(mealType)
          .collection('students')
          .doc(normalizedStudentId)
          .get();

      if (attendanceDoc.exists) {
        return false;
      }

      // Mark attendance
      await _firestore
          .collection('attendance')
          .doc(messId)
          .collection(dateStr)
          .doc(mealType)
          .collection('students')
          .doc(normalizedStudentId)
          .set({
        'enrollmentId': normalizedEnrollmentId,
        'studentName': normalizedStudentName,
        'markedAt': DateTime.now().toIso8601String(),
        'markedBy': 'scanned',
        'qrCodeId': qrCodeId,
        'qrGeneratedAt': qrGeneratedAt,
        'qrExpiresAt': qrExpiresAt,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if student already marked for this meal today
  Future<bool> isAlreadyMarked(
    String messId,
    String studentId,
    String mealType,
  ) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection('attendance')
          .doc(messId)
          .collection(dateStr)
          .doc(mealType)
          .collection('students')
          .doc(studentId)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Generate QR code for a meal session
  /// Manager calls this to create a new QR
  Future<Map<String, dynamic>?> generateQRCode(
    String messId,
    String mealType,
    String managerId,
  ) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final qrCodeId = uuid.v4();

      // QR expires in 15 minutes
      final expiresAt = today.add(Duration(minutes: 15));

      final qrData = {
        'qrCodeId': qrCodeId,
        'messId': messId,
        'mealType': mealType,
        'date': dateStr,
        'generatedAt': today.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'generatedBy': managerId,
        'scannedCount': 0,
      };

      // Store in Firestore
      await _firestore
          .collection('qr_codes')
          .doc(messId)
          .collection(dateStr)
          .doc(mealType)
          .set(qrData);

      print('[QR] Generated QR: $qrCodeId for $mealType');
      return qrData;
    } catch (e) {
      print('[QR] Error generating QR: $e');
      return null;
    }
  }

  /// Verify and get current QR code
  Future<Map<String, dynamic>?> getCurrentQRCode(
    String messId,
    String mealType,
  ) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection('qr_codes')
          .doc(messId)
          .collection(dateStr)
          .doc(mealType)
          .get();

      if (!doc.exists) {
        return null;
      }

      final qrData = doc.data() as Map<String, dynamic>;
      final expiresAt = DateTime.parse(qrData['expiresAt'] as String);

      // Check if expired
      if (DateTime.now().isAfter(expiresAt)) {
        print('[QR] QR code expired');
        return null;
      }

      return qrData;
    } catch (e) {
      print('[QR] Error getting QR: $e');
      return null;
    }
  }

  /// Mark attendance manually (manager marks a student)
  Future<bool> markAttendanceManually(
    String messId,
    String studentId,
    String mealType,
    String enrollmentId,
    String studentName,
  ) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final normalizedStudentId = studentId.trim().isNotEmpty ? studentId : uuid.v4();
      final normalizedEnrollmentId = _normalizeEnrollmentId(enrollmentId);
      final normalizedStudentName = _normalizeStudentName(studentName);

      // Check if already marked
      final attendanceDoc = await _firestore
          .collection('attendance')
          .doc(messId)
          .collection(dateStr)
          .doc(mealType)
          .collection('students')
          .doc(normalizedStudentId)
          .get();

      if (attendanceDoc.exists) {
        print('[Attendance] Already marked for $mealType on $dateStr');
        return false;
      }

      // Mark attendance
      await _firestore
          .collection('attendance')
          .doc(messId)
          .collection(dateStr)
          .doc(mealType)
          .collection('students')
          .doc(normalizedStudentId)
          .set({
        'enrollmentId': normalizedEnrollmentId,
        'studentName': normalizedStudentName,
        'markedAt': DateTime.now().toIso8601String(),
        'markedBy': 'manual',
      });

      print('[Attendance] Manual mark successful: $studentId for $mealType');
      return true;
    } catch (e) {
      print('[Attendance] Error marking attendance manually: $e');
      return false;
    }
  }

  /// Get today's attendance for a meal
  Future<List<Map<String, dynamic>>> getTodayAttendance(
    String messId,
    String mealType,
  ) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final snapshot = await _firestore
          .collection('attendance')
          .doc(messId)
          .collection(dateStr)
          .doc(mealType)
          .collection('students')
          .get();

      return snapshot.docs
          .map((doc) => {
                'studentId': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('[Attendance] Error getting attendance: $e');
      return [];
    }
  }

  /// Get attendance count for today
  Future<Map<String, int>> getTodayAttendanceCount(String messId) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final meals = ['breakfast', 'lunch', 'dinner'];
      final counts = <String, int>{};

      for (final meal in meals) {
        final snapshot = await _firestore
            .collection('attendance')
            .doc(messId)
            .collection(dateStr)
            .doc(meal)
            .collection('students')
            .get();

        counts[meal] = snapshot.docs.length;
      }

      return counts;
    } catch (e) {
      print('[Attendance] Error getting count: $e');
      return {};
    }
  }

  String _normalizeEnrollmentId(String? enrollmentId) {
    final trimmed = enrollmentId?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : 'ANON-${uuid.v4()}';
  }

  String _normalizeStudentName(String? studentName) {
    final trimmed = studentName?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : 'Anonymous';
  }
}
