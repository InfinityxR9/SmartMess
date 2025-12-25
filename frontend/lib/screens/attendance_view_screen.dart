import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceViewScreen extends StatefulWidget {
  final String messId;
  final String mealType;

  const AttendanceViewScreen({
    Key? key,
    required this.messId,
    required this.mealType,
  }) : super(key: key);

  @override
  State<AttendanceViewScreen> createState() => _AttendanceViewScreenState();
}

class _AttendanceViewScreenState extends State<AttendanceViewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> _fetchAttendanceData() async {
    final now = DateTime.now();
    final dateStr = '--';

    try {
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .doc(widget.messId)
          .collection(dateStr)
          .doc(widget.mealType)
          .collection('students')
          .get();

      final students = attendanceSnapshot.docs
          .map((doc) => {
                'studentId': doc.id,
                'enrollmentId': doc.get('enrollmentId') ?? 'Anonymous',
                'studentName': doc.get('studentName') ?? 'Anonymous',
                'markedAt': doc.get('markedAt') ?? '',
                'markedBy': doc.get('markedBy') ?? 'unknown',
              })
          .toList();

      return {
        'date': dateStr,
        'slot': widget.mealType,
        'students': students,
        'count': students.length,
      };
    } catch (e) {
      print('Error fetching attendance: \');
      return {
        'date': '',
        'slot': widget.mealType,
        'students': [],
        'count': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - '),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchAttendanceData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: '));
          }

          final data = snapshot.data ?? {};
          final students = (data['students'] as List?) ?? [];
          final count = data['count'] as int? ?? 0;
          final date = data['date'] ?? '';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 2,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade400, Colors.purple.shade600],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Attendance for \',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'students marked for ',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: const Text('No attendance marked yet'),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.shade200,
                            child: Text((index + 1).toString()),
                          ),
                          title: Text(student['studentName']?.toString() ?? 'Anonymous'),
                          subtitle: Text(
                            'ID: ',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                student['markedAt']?.toString().substring(11, 16) ?? '',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                student['markedBy']?.toString() ?? 'unknown',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
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
