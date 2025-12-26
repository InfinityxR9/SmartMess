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
      final normalizedStudentId = _normalizeStudentId(studentId);
      final normalizedEnrollmentId = _normalizeEnrollmentId(enrollmentId);
      final normalizedStudentName = _normalizeStudentName(studentName);
      final anonymousId = _anonymousEnrollmentId();
      final storedEnrollmentId =
          normalizedEnrollmentId.isNotEmpty ? normalizedEnrollmentId : anonymousId;
      final attendanceDocId = normalizedEnrollmentId.isNotEmpty
          ? normalizedEnrollmentId
          : (normalizedStudentId.isNotEmpty ? normalizedStudentId : anonymousId);

      final studentsRef = _firestore
          .collection('attendance')
          .doc(messId)
          .collection(dateStr)
          .doc(mealType)
          .collection('students');

      // Check if already marked (case-insensitive enrollment ID)
      final duplicate = await _hasDuplicateAttendance(
        studentsRef: studentsRef,
        normalizedEnrollmentId: normalizedEnrollmentId,
        rawEnrollmentId: enrollmentId,
        normalizedStudentId: normalizedStudentId,
      );

      if (duplicate) {
        return false;
      }

      // Mark attendance
      await studentsRef.doc(attendanceDocId).set({
        'enrollmentId': storedEnrollmentId,
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
    String mealType, {
    String? enrollmentId,
    String? studentId,
  }) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final normalizedStudentId = _normalizeStudentId(studentId ?? '');
      final normalizedEnrollmentId = _normalizeEnrollmentId(enrollmentId);

      if (normalizedEnrollmentId.isEmpty && normalizedStudentId.isEmpty) {
        return false;
      }

      final studentsRef = _firestore
          .collection('attendance')
          .doc(messId)
          .collection(dateStr)
          .doc(mealType)
          .collection('students');

      return _hasDuplicateAttendance(
        studentsRef: studentsRef,
        normalizedEnrollmentId: normalizedEnrollmentId,
        rawEnrollmentId: enrollmentId,
        normalizedStudentId: normalizedStudentId,
      );
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
      final normalizedStudentId = _normalizeStudentId(studentId);
      final normalizedEnrollmentId = _normalizeEnrollmentId(enrollmentId);
      final normalizedStudentName = _normalizeStudentName(studentName);
      final anonymousId = _anonymousEnrollmentId();
      final storedEnrollmentId =
          normalizedEnrollmentId.isNotEmpty ? normalizedEnrollmentId : anonymousId;
      final attendanceDocId = normalizedEnrollmentId.isNotEmpty
          ? normalizedEnrollmentId
          : (normalizedStudentId.isNotEmpty ? normalizedStudentId : anonymousId);

      final studentsRef = _firestore
          .collection('attendance')
          .doc(messId)
          .collection(dateStr)
          .doc(mealType)
          .collection('students');

      // Check if already marked (case-insensitive enrollment ID)
      final duplicate = await _hasDuplicateAttendance(
        studentsRef: studentsRef,
        normalizedEnrollmentId: normalizedEnrollmentId,
        rawEnrollmentId: enrollmentId,
        normalizedStudentId: normalizedStudentId,
      );

      if (duplicate) {
        return false;
      }

      // Mark attendance
      await studentsRef.doc(attendanceDocId).set({
        'enrollmentId': storedEnrollmentId,
        'studentName': normalizedStudentName,
        'markedAt': DateTime.now().toIso8601String(),
        'markedBy': 'manual',
      });

      return true;
    } catch (e) {
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
    final trimmed = enrollmentId?.trim().toLowerCase() ?? '';
    return trimmed;
  }

  String _normalizeStudentId(String studentId) {
    final trimmed = studentId.trim().toLowerCase();
    return trimmed;
  }

  String _anonymousEnrollmentId() {
    return 'anon-${uuid.v4()}';
  }

  Future<bool> _hasDuplicateAttendance({
    required CollectionReference<Map<String, dynamic>> studentsRef,
    required String normalizedEnrollmentId,
    required String? rawEnrollmentId,
    required String normalizedStudentId,
  }) async {
    final idsToCheck = <String>{};
    if (normalizedEnrollmentId.isNotEmpty) {
      idsToCheck.add(normalizedEnrollmentId);
    }
    final raw = rawEnrollmentId?.trim() ?? '';
    if (raw.isNotEmpty) {
      idsToCheck.add(raw);
      idsToCheck.add(raw.toUpperCase());
      idsToCheck.add(raw.toLowerCase());
    }
    if (normalizedEnrollmentId.isEmpty && normalizedStudentId.isNotEmpty) {
      idsToCheck.add(normalizedStudentId);
    }

    for (final id in idsToCheck) {
      final doc = await studentsRef.doc(id).get();
      if (doc.exists) {
        return true;
      }
    }
    return false;
  }

  String _normalizeStudentName(String? studentName) {
    final trimmed = studentName?.trim() ?? '';
    return trimmed.isNotEmpty ? trimmed : 'Anonymous';
  }
}
