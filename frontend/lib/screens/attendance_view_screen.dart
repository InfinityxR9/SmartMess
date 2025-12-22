import 'package:flutter/material.dart';
import 'package:smart_mess/services/attendance_service.dart';

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
  final AttendanceService _attendanceService = AttendanceService();
  late Future<List<Map<String, dynamic>>> _attendanceFuture;
  late Future<Map<String, int>> _countsFuture;

  @override
  void initState() {
    super.initState();
    _attendanceFuture =
        _attendanceService.getTodayAttendance(widget.messId, widget.mealType);
    _countsFuture =
        _attendanceService.getTodayAttendanceCount(widget.messId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance - ${widget.mealType.toUpperCase()}'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats card
            FutureBuilder<Map<String, int>>(
              future: _countsFuture,
              builder: (context, snapshot) {
                final counts = snapshot.data ?? {};
                final count = counts[widget.mealType] ?? 0;
                return Container(
                  padding: EdgeInsets.all(16),
                  child: Card(
                    elevation: 2,
                    child: Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'Total Marked',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6200EE),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'students marked for ${widget.mealType}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Attendance list
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Student Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _attendanceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey[300]),
                          SizedBox(height: 16),
                          Text(
                            'No attendance marked yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final students = snapshot.data!;
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final enrollmentId = student['enrollmentId'] ?? 'N/A';
                      final studentName = student['studentName'] ?? 'Unknown';
                      final markedAt =
                          student['markedAt'] ?? DateTime.now().toIso8601String();
                      final markedBy = student['markedBy'] ?? 'unknown';

                      // Parse and format time
                      DateTime parsedTime;
                      try {
                        parsedTime = DateTime.parse(markedAt);
                      } catch (e) {
                        parsedTime = DateTime.now();
                      }
                      String formattedTime =
                          '${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}';

                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(0xFF6200EE).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                studentName[0].toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6200EE),
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            studentName,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '$enrollmentId • $formattedTime (${markedBy.toUpperCase()})',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: Icon(Icons.check_circle,
                              color: Colors.green, size: 24),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
