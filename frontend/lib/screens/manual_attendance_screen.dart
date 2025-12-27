import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/services/attendance_service.dart';

class ManualAttendanceScreen extends StatefulWidget {
  final String mealType;

  const ManualAttendanceScreen({
    Key? key,
    required this.mealType,
  }) : super(key: key);

  @override
  State<ManualAttendanceScreen> createState() => _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  int _studentCount = 1;
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  final TextEditingController _enrollmentController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _enrollmentController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _markSingleStudent() async {
    if (_enrollmentController.text.isEmpty || _nameController.text.isEmpty) {
      setState(() {
        _message = 'Please enter enrollment ID and student name';
        _isSuccess = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<UnifiedAuthProvider>();

    try {
      final success = await _attendanceService.markAttendanceManually(
        authProvider.messId ?? '',
        _enrollmentController.text,
        widget.mealType,
        _enrollmentController.text,
        _nameController.text,
      );

      if (mounted) {
        setState(() {
          _message = success
              ? 'Success: ${_nameController.text} marked present'
              : 'Duplicate Attendance is not Allowed';
          _isSuccess = success;
          _isLoading = false;
        });

        if (success) {
          _enrollmentController.clear();
          _nameController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Error: ${e.toString()}';
          _isSuccess = false;
          _isLoading = false;
        });
      }
    }
  }

  void _markBulkStudents() async {
    if (_studentCount <= 0) {
      setState(() {
        _message = 'Please enter valid number of students';
        _isSuccess = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<UnifiedAuthProvider>();
    int markedCount = 0;

    try {
      for (int i = 0; i < _studentCount; i++) {
        final enrollmentId = 'ANON_${DateTime.now().millisecondsSinceEpoch}_$i';
        final success = await _attendanceService.markAttendanceManually(
          authProvider.messId ?? '',
          enrollmentId,
          widget.mealType,
          enrollmentId,
          'Anonymous Student ${i + 1}',
        );

        if (success) markedCount++;
      }

      if (mounted) {
        setState(() {
          _message = 'Success: $markedCount/${_studentCount} students marked successfully';
          _isSuccess = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Error: ${e.toString()}';
          _isSuccess = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manual Attendance - ${widget.mealType.toUpperCase()}'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Card(
                elevation: 2,
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mark Attendance Manually',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Use this for students who cannot scan QR codes.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Tabs
              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(child: Text('Individual Student')),
                        Tab(child: Text('Bulk Mark')),
                      ],
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      height: 350,
                      child: TabBarView(
                        children: [
                          // Individual marking
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _enrollmentController,
                                decoration: InputDecoration(
                                  labelText: 'Enrollment ID',
                                  hintText: 'e.g., E123456',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              SizedBox(height: 16),
                              TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Student Name',
                                  hintText: 'e.g., John Doe',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: Icon(Icons.check_circle),
                                label: Text('Mark Present'),
                                onPressed: _isLoading ? null : _markSingleStudent,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                          ),
                          // Bulk marking
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Number of Students',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: _studentCount.toString(),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        setState(() {
                                          _studentCount = int.tryParse(value) ?? 1;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                        hintText: 'Enter number',
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  IconButton(
                                    icon: Icon(Icons.remove),
                                    onPressed: _studentCount > 1
                                        ? () =>
                                            setState(() => _studentCount--)
                                        : null,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add),
                                    onPressed: _studentCount < 200
                                        ? () =>
                                            setState(() => _studentCount++)
                                        : null,
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF17BEBB).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'This will mark $_studentCount anonymous students as present',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFF0B3954),
                                  ),
                                ),
                              ),
                              SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: Icon(Icons.done_all),
                                label: Text('Mark All Present'),
                                onPressed: _isLoading ? null : _markBulkStudents,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: Color(0xFF2196F3),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Status message
              if (_message != null)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? const Color(0xFF2A9D8F).withValues(alpha: 0.12)
                        : const Color(0xFFE63946).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSuccess
                          ? const Color(0xFF2A9D8F).withValues(alpha: 0.35)
                          : const Color(0xFFE63946).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.error_outline,
                        color: _isSuccess
                            ? const Color(0xFF2A9D8F)
                            : const Color(0xFFE63946),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _isSuccess
                                ? const Color(0xFF1B6F64)
                                : const Color(0xFF9B1C1F),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Loading indicator
              if (_isLoading) ...[
                SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Processing...'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
