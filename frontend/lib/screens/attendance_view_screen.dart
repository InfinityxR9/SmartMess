import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceViewScreen extends StatefulWidget {
  final String messId;
  final String mealType;
  final String? date;
  final String? qrCodeId;

  const AttendanceViewScreen({
    Key? key,
    required this.messId,
    required this.mealType,
    this.date,
    this.qrCodeId,
  }) : super(key: key);

  @override
  State<AttendanceViewScreen> createState() => _AttendanceViewScreenState();
}

class _AttendanceViewScreenState extends State<AttendanceViewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _resolveDate() {
    final provided = widget.date?.trim() ?? '';
    if (provided.isNotEmpty) {
      return provided;
    }
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatMealLabel(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return mealType.toUpperCase();
    }
  }

  String _formatMarkedTime(dynamic markedAt) {
    if (markedAt == null) return '';
    if (markedAt is Timestamp) {
      final dt = markedAt.toDate();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final text = markedAt.toString();
    if (text.contains('T')) {
      final parts = text.split('T');
      if (parts.length > 1 && parts[1].length >= 5) {
        return parts[1].substring(0, 5);
      }
    }
    if (text.length >= 16 && text[10] == ' ') {
      return text.substring(11, 16);
    }
    return text;
  }

  Future<Map<String, dynamic>> _fetchAttendanceData() async {
    final dateStr = _resolveDate();
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('attendance')
          .doc(widget.messId)
          .collection(dateStr)
          .doc(widget.mealType)
          .collection('students');

      final qrCodeId = widget.qrCodeId?.trim() ?? '';
      if (qrCodeId.isNotEmpty) {
        query = query.where('qrCodeId', isEqualTo: qrCodeId);
      }

      final attendanceSnapshot = await query.get();

      final students = attendanceSnapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'studentId': doc.id,
              'enrollmentId': data['enrollmentId'] ?? 'Anonymous',
              'studentName': data['studentName'] ?? 'Anonymous',
              'markedAt': data['markedAt'] ?? '',
              'markedBy': data['markedBy'] ?? 'unknown',
              'qrCodeId': data['qrCodeId'],
            };
          })
          .toList();

      return {
        'date': dateStr,
        'slot': widget.mealType,
        'students': students,
        'count': students.length,
      };
    } catch (e) {
      return {
        'date': dateStr,
        'slot': widget.mealType,
        'students': [],
        'count': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealLabel = _formatMealLabel(widget.mealType);
    final qrCodeId = widget.qrCodeId?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - $mealLabel'),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchAttendanceData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load attendance'));
          }

          final data = snapshot.data ?? {};
          final students = (data['students'] as List?) ?? [];
          final count = data['count'] as int? ?? 0;
          final date = data['date']?.toString() ?? '';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance for $mealLabel',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Date: $date',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          if (qrCodeId.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Filtered by QR code',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            '$count students marked',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text(
                    'Student Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (students.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No attendance marked yet'),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index] as Map<String, dynamic>;
                      final markedBy = (student['markedBy'] ?? 'unknown').toString();
                      final markedByLabel = markedBy == 'qr' ? 'scanned' : markedBy;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFFD166),
                            child: Text((index + 1).toString()),
                          ),
                          title: Text(student['studentName']?.toString() ?? 'Anonymous'),
                          subtitle: Text(
                            'ID: ${student['enrollmentId']?.toString() ?? 'Anonymous'} | $markedByLabel',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            _formatMarkedTime(student['markedAt']),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
