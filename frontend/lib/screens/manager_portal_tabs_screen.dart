import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/models/prediction_model.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/screens/menu_creation_screen.dart';
import 'package:smart_mess/screens/manual_attendance_screen.dart';
import 'package:smart_mess/screens/qr_generator_screen.dart';
import 'package:smart_mess/services/prediction_service.dart';
import 'package:smart_mess/services/review_service.dart';
import 'package:smart_mess/utils/meal_time.dart';
import 'package:smart_mess/widgets/reviews_tab.dart';

class ManagerPortalTabsScreen extends StatefulWidget {
  final String messId;
  final int initialIndex;

  const ManagerPortalTabsScreen({
    Key? key,
    required this.messId,
    this.initialIndex = 1,
  }) : super(key: key);

  @override
  State<ManagerPortalTabsScreen> createState() => _ManagerPortalTabsScreenState();
}

class _ManagerPortalTabsScreenState extends State<ManagerPortalTabsScreen> {
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIndex;
    _selectedIndex = initial.clamp(0, 2);
  }

  void _showManagerActions(BuildContext context, UnifiedAuthProvider authProvider) {
    final rootContext = context;
    showModalBottomSheet(
      context: rootContext,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('Generate QR'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final slot = getCurrentMealSlot();
                  if (slot == null) {
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(
                        content: Text('Outside meal hours. QR can only be generated during meal times.'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(rootContext).push(
                    MaterialPageRoute(
                      builder: (_) => QRGeneratorScreen(mealType: slot.type),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.checklist),
                title: const Text('Mark Attendance'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final slot = getCurrentMealSlot();
                  if (slot == null) {
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(
                        content: Text('Outside meal hours. Attendance can only be marked during meal times.'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(rootContext).push(
                    MaterialPageRoute(
                      builder: (_) => ManualAttendanceScreen(mealType: slot.type),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book),
                title: const Text('Update Menu'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(rootContext).push(
                    MaterialPageRoute(builder: (_) => MenuCreationScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  authProvider.logout();
                  Navigator.of(rootContext).pushReplacementNamed('/student_login');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBox({
    required IconData icon,
    required String title,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? color : Colors.black).withOpacity(isSelected ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<UnifiedAuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Portal'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showManagerActions(context, authProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildTabBox(
                  icon: Icons.rate_review,
                  title: 'Review',
                  color: const Color(0xFFFF6B6B),
                  isSelected: _selectedIndex == 0,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  },
                ),
                _buildTabBox(
                  icon: Icons.insights,
                  title: 'Prediction + Analysis',
                  color: const Color(0xFF6200EE),
                  isSelected: _selectedIndex == 1,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                ),
                _buildTabBox(
                  icon: Icons.people_alt,
                  title: 'Attendance',
                  color: const Color(0xFF03DAC6),
                  isSelected: _selectedIndex == 2,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                ReviewsTab(messId: widget.messId),
                ManagerAttendanceTab(
                  messId: widget.messId,
                  showPredictions: true,
                  showStudentList: false,
                ),
                ManagerAttendanceTab(
                  messId: widget.messId,
                  showPredictions: false,
                  showStudentList: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ManagerReviewsScreen extends StatelessWidget {
  final String messId;

  const ManagerReviewsScreen({
    Key? key,
    required this.messId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
        elevation: 0,
      ),
      body: ReviewsTab(messId: messId),
    );
  }
}

class ManagerPredictionAnalysisScreen extends StatelessWidget {
  final String messId;

  const ManagerPredictionAnalysisScreen({
    Key? key,
    required this.messId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prediction + Analysis'),
        elevation: 0,
      ),
      body: ManagerAttendanceTab(
        messId: messId,
        showPredictions: true,
        showStudentList: false,
      ),
    );
  }
}

class ManagerAttendanceScreen extends StatelessWidget {
  final String messId;

  const ManagerAttendanceScreen({
    Key? key,
    required this.messId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        elevation: 0,
      ),
      body: ManagerAttendanceTab(
        messId: messId,
        showPredictions: false,
        showStudentList: true,
      ),
    );
  }
}

class ManagerPredictionTab extends StatefulWidget {
  final String messId;

  const ManagerPredictionTab({Key? key, required this.messId}) : super(key: key);

  @override
  State<ManagerPredictionTab> createState() => _ManagerPredictionTabState();
}

class _ManagerPredictionTabState extends State<ManagerPredictionTab> {
  final PredictionService _predictionService = PredictionService();
  MealSlotInfo? _currentSlot;
  Timer? _slotTimer;
  late Future<PredictionResult?> _predictions;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _refreshSlot();
    _slotTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _refreshSlot();
      }
    });
  }

  @override
  void dispose() {
    _slotTimer?.cancel();
    super.dispose();
  }

  void _refreshSlot() {
    final slot = getCurrentMealSlot();
    if (_hasInitialized && slot?.type == _currentSlot?.type) {
      return;
    }

    setState(() {
      _currentSlot = slot;
      _hasInitialized = true;
      if (_currentSlot == null) {
        _predictions = Future.value(null);
      } else {
        _predictions = _predictionService.getPrediction(
          widget.messId,
          slot: _currentSlot!.type,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final slot = _currentSlot;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  slot == null ? Icons.access_time : Icons.restaurant,
                  color: const Color(0xFF6200EE),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    slot == null
                        ? 'Outside meal hours. Predictions show only during meal slots.'
                        : 'Current Slot: ${slot.label} (${slot.window})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (slot == null)
          const Text('No predictions available outside meal hours')
        else
          FutureBuilder<PredictionResult?>(
            future: _predictions,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final prediction = snapshot.data;
              if (prediction == null || prediction.predictions.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('No predictions available. Check back during meal times.'),
                );
              }

              return Column(
                children: prediction.predictions.map((pred) {
                  final isBad = pred.crowdPercentage > 70;
                  final isModerate = pred.crowdPercentage > 40;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isBad
                            ? Colors.red.shade300
                            : isModerate
                                ? Colors.orange.shade300
                                : Colors.green.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isBad
                          ? Colors.red.shade50
                          : isModerate
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pred.timeSlot,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${pred.predictedCrowd.toStringAsFixed(0)} students expected',
                              style: TextStyle(color: Colors.grey[700], fontSize: 12),
                            ),
                          ],
                        ),
                        Text(
                          '${pred.crowdPercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isBad
                                ? Colors.red
                                : isModerate
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

class ManagerAttendanceTab extends StatefulWidget {
  final String messId;
  final bool showStudentList;
  final bool showPredictions;

  const ManagerAttendanceTab({
    Key? key,
    required this.messId,
    required this.showStudentList,
    required this.showPredictions,
  }) : super(key: key);

  @override
  State<ManagerAttendanceTab> createState() => _ManagerAttendanceTabState();
}

class _ManagerAttendanceTabState extends State<ManagerAttendanceTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ReviewService _reviewService = ReviewService();
  final PredictionService _predictionService = PredictionService();
  MealSlotInfo? _currentSlot;
  Timer? _slotTimer;
  late Future<Map<String, dynamic>> _attendanceData;
  Future<PredictionResult?>? _predictions;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _refreshSlot();
    _slotTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _refreshSlot();
      }
    });
  }

  @override
  void dispose() {
    _slotTimer?.cancel();
    super.dispose();
  }

  void _refreshSlot() {
    final slot = getCurrentMealSlot();
    if (_hasInitialized && slot?.type == _currentSlot?.type) {
      return;
    }

    setState(() {
      _currentSlot = slot;
      _hasInitialized = true;
      if (_currentSlot == null) {
        _attendanceData = Future.value(_emptyAttendanceData());
        _predictions = Future.value(null);
      } else {
        _attendanceData = _fetchAttendanceData(widget.messId, _currentSlot!.type);
        if (widget.showPredictions) {
          _predictions = _predictionService.getPrediction(
            widget.messId,
            slot: _currentSlot!.type,
          );
        }
      }
    });
  }

  Map<String, dynamic> _emptyAttendanceData() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return {
      'date': dateStr,
      'capacity': 0,
      'totalAttendance': 0,
      'crowdPercentage': '0',
      'students': <Map<String, dynamic>>[],
      'avgRating': '0',
      'reviewCount': 0,
    };
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

  Future<Map<String, dynamic>> _fetchAttendanceData(String messId, String meal) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final messSnapshot = await _firestore.collection('messes').doc(messId).get();
      final capacity = (messSnapshot.data()?['capacity'] ?? 0) as int;

      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .doc(messId)
          .collection(dateStr)
          .doc(meal)
          .collection('students')
          .get();

      final students = attendanceSnapshot.docs
          .map((doc) {
            final data = doc.data();
            return {
              'studentId': doc.id,
              'enrollmentId': data['enrollmentId'] ?? 'Anonymous',
              'studentName': data['studentName'] ?? 'Anonymous',
              'markedAt': data['markedAt'] ?? '',
              'markedBy': data['markedBy'] ?? 'unknown',
            };
          })
          .toList();

      final totalAttendance = students.length;
      final crowdPercentage =
          capacity > 0 ? ((totalAttendance / capacity) * 100).toStringAsFixed(1) : '0';

      final reviews = await _reviewService.getReviewsForDateAndSlot(
        messId: messId,
        date: dateStr,
        slot: meal,
      );

      double avgRating = 0;
      if (reviews.isNotEmpty) {
        final totalRating = reviews.fold<int>(
          0,
          (sum, r) => sum + ((r['rating'] as int?) ?? 0),
        );
        avgRating = totalRating / reviews.length;
      }

      return {
        'date': dateStr,
        'capacity': capacity,
        'totalAttendance': totalAttendance,
        'crowdPercentage': crowdPercentage,
        'students': students,
        'avgRating': avgRating.toStringAsFixed(1),
        'reviewCount': reviews.length,
      };
    } catch (e) {
      return _emptyAttendanceData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = _currentSlot;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  slot == null ? Icons.access_time : Icons.restaurant,
                  color: const Color(0xFF6200EE),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    slot == null
                        ? 'Outside meal hours. Attendance shows only during meal slots.'
                        : 'Current Slot: ${slot.label} (${slot.window})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (slot == null)
          const Text('No attendance available outside meal hours')
        else
          FutureBuilder<Map<String, dynamic>>(
            future: _attendanceData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data ?? {};
              final students = (data['students'] as List?) ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    'Date: ${data['date'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Attendance',
                          value: '${data['totalAttendance']?.toString() ?? '0'}/${data['capacity']}',
                          icon: Icons.people,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Crowd %',
                          value: '${data['crowdPercentage']}%',
                          icon: Icons.trending_up,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Reviews',
                          value: '${data['reviewCount']?.toString() ?? '0'}',
                          icon: Icons.star,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Avg Rating',
                          value: '${data['avgRating'] ?? '0'}',
                          icon: Icons.rate_review,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (widget.showPredictions) ...[
                    const Text(
                      'Upcoming 15-Min Slot Predictions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<PredictionResult?>(
                      future: _predictions,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final prediction = snapshot.data;
                        if (prediction == null || prediction.predictions.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('No predictions available. Check back during meal times.'),
                          );
                        }

                        return Column(
                          children: prediction.predictions.map((pred) {
                            final isBad = pred.crowdPercentage > 70;
                            final isModerate = pred.crowdPercentage > 40;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isBad
                                      ? Colors.red.shade300
                                      : isModerate
                                          ? Colors.orange.shade300
                                          : Colors.green.shade300,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: isBad
                                    ? Colors.red.shade50
                                    : isModerate
                                        ? Colors.orange.shade50
                                        : Colors.green.shade50,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pred.timeSlot,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${pred.predictedCrowd.toStringAsFixed(0)} students expected',
                                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${pred.crowdPercentage.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isBad
                                          ? Colors.red
                                          : isModerate
                                              ? Colors.orange
                                              : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (widget.showStudentList) ...[
                    const Text(
                      'Student Attendance',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (students.isEmpty)
                      const Text('No attendance marked yet for this slot')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index] as Map<String, dynamic>;
                          final markedBy = (student['markedBy'] ?? 'unknown').toString();
                          final markedByLabel = markedBy == 'qr' ? 'scanned' : markedBy;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                              title: Text(student['studentName']?.toString() ?? 'Anonymous'),
                              subtitle: Text(
                                'ID: ${student['enrollmentId']?.toString() ?? 'Anonymous'} | $markedByLabel',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                _formatMarkedTime(student['markedAt']),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: Colors.purple, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
