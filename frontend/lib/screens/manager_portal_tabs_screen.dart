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
import 'package:smart_mess/theme/app_tokens.dart';
import 'package:smart_mess/widgets/animated_metric_bar.dart';
import 'package:smart_mess/widgets/empty_state.dart';
import 'package:smart_mess/widgets/section_header.dart';
import 'package:smart_mess/widgets/skeleton_loader.dart';
import 'package:smart_mess/widgets/staggered_fade_in.dart';

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
  late int _tabIndex;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIndex;
    _tabIndex = initial < 0 ? 0 : initial > 2 ? 2 : initial;
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<UnifiedAuthProvider>();
    return DefaultTabController(
      length: 3,
      initialIndex: _tabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prediction + Analysis'),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showManagerActions(context, authProvider),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Review'),
              Tab(text: 'Prediction + Analysis'),
              Tab(text: 'Attendance'),
            ],
          ),
        ),
        body: TabBarView(
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
    return ManagerPortalTabsScreen(
      messId: messId,
      initialIndex: 0,
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
    return ManagerPortalTabsScreen(
      messId: messId,
      initialIndex: 1,
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
    return ManagerPortalTabsScreen(
      messId: messId,
      initialIndex: 2,
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
  int? _messCapacity;

  @override
  void initState() {
    super.initState();
    _messCapacity = context.read<UnifiedAuthProvider>().messCapacity;
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
        _predictions = _loadPredictions(_currentSlot!.type);
      }
    });
  }

  Future<PredictionResult?> _loadPredictions(String slotType) async {
    return _predictionService.getPrediction(
      widget.messId,
      mealType: slotType,
      capacity: _messCapacity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slot = _currentSlot;
    final textTheme = Theme.of(context).textTheme;
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
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    slot == null
                        ? 'Outside meal hours. Predictions show only during meal slots.'
                        : 'Current Slot: ${slot.label} (${slot.window})',
                    style: textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (slot == null)
          const EmptyStateCard(
            icon: Icons.schedule,
            title: 'No predictions available',
            message: 'Predictions appear during active meal slots.',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Upcoming 15-Min Slot Predictions',
                icon: Icons.insights,
              ),
              FutureBuilder<PredictionResult?>(
                future: _predictions,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SkeletonList(itemCount: 2, lineCount: 1);
                  }

                  final prediction = snapshot.data;
                  if (prediction == null || prediction.predictions.isEmpty) {
                    return const EmptyStateCard(
                      icon: Icons.bar_chart,
                      title: 'No predictions available',
                      message: 'Check back during meal times for updates.',
                    );
                  }

                  return Column(
                    children: prediction.predictions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final pred = entry.value;
                      final isBad = pred.crowdPercentage > 70;
                      final isModerate = pred.crowdPercentage > 40;
                      final crowdColor = isBad
                          ? AppColors.danger
                          : isModerate
                              ? AppColors.warning
                              : AppColors.success;

                      return StaggeredFadeIn(
                        index: index,
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: crowdColor.withValues(alpha: 0.16),
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.sm),
                                  ),
                                  child: Icon(
                                    Icons.people,
                                    color: crowdColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(pred.timeSlot,
                                          style: textTheme.titleSmall),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${pred.predictedCrowd.toStringAsFixed(0)} students expected',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      AnimatedMetricBar(
                                        percentage: pred.crowdPercentage,
                                        color: crowdColor,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${pred.crowdPercentage.toStringAsFixed(0)}%',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: crowdColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
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
  int? _messCapacity;

  @override
  void initState() {
    super.initState();
    _messCapacity = context.read<UnifiedAuthProvider>().messCapacity;
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
        final slotType = _currentSlot!.type;
        _attendanceData = _fetchAttendanceData(widget.messId, slotType);
        if (widget.showPredictions) {
          _predictions = _loadPredictions(slotType);
        }
      }
    });
  }

  Future<PredictionResult?> _loadPredictions(String slotType) async {
    return _predictionService.getPrediction(
      widget.messId,
      mealType: slotType,
      capacity: _messCapacity,
    );
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
    final textTheme = Theme.of(context).textTheme;
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
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    slot == null
                        ? 'Outside meal hours. Attendance shows only during meal slots.'
                        : 'Current Slot: ${slot.label} (${slot.window})',
                    style: textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (slot == null)
          const EmptyStateCard(
            icon: Icons.schedule,
            title: 'No attendance data',
            message: 'Attendance appears during active meal slots.',
          )
        else
          FutureBuilder<Map<String, dynamic>>(
            future: _attendanceData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SkeletonList(itemCount: 2, lineCount: 2);
              }

              final data = snapshot.data ?? {};
              final students = (data['students'] as List?) ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    'Date: ${data['date'] ?? ''}',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
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
                    const SectionHeader(
                      title: 'Upcoming 15-Min Slot Predictions',
                      icon: Icons.insights,
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<PredictionResult?>(
                      future: _predictions,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SkeletonList(itemCount: 1, lineCount: 1);
                        }

                        final prediction = snapshot.data;
                        if (prediction == null || prediction.predictions.isEmpty) {
                          return const EmptyStateCard(
                            icon: Icons.bar_chart,
                            title: 'No predictions available',
                            message: 'Check back during meal times for updates.',
                          );
                        }

                        return Column(
                          children: prediction.predictions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final pred = entry.value;
                            final isBad = pred.crowdPercentage > 70;
                            final isModerate = pred.crowdPercentage > 40;
                            final crowdColor = isBad
                                ? AppColors.danger
                                : isModerate
                                    ? AppColors.warning
                                    : AppColors.success;

                            return StaggeredFadeIn(
                              index: index,
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: crowdColor.withValues(alpha: 0.16),
                                          borderRadius:
                                              BorderRadius.circular(AppRadii.sm),
                                        ),
                                        child: Icon(
                                          Icons.people,
                                          color: crowdColor,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pred.timeSlot,
                                              style: textTheme.titleSmall,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${pred.predictedCrowd.toStringAsFixed(0)} students expected',
                                              style: textTheme.bodySmall?.copyWith(
                                                color: AppColors.inkMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            AnimatedMetricBar(
                                              percentage: pred.crowdPercentage,
                                              color: crowdColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${pred.crowdPercentage.toStringAsFixed(0)}%',
                                        style: textTheme.titleMedium?.copyWith(
                                          color: crowdColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (widget.showStudentList) ...[
                    const SectionHeader(
                      title: 'Student Attendance',
                      icon: Icons.badge,
                    ),
                    const SizedBox(height: 12),
                    if (students.isEmpty)
                      const EmptyStateCard(
                        icon: Icons.person_off,
                        title: 'No attendance marked',
                        message: 'Student check-ins will appear here.',
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index] as Map<String, dynamic>;
                          final markedBy = (student['markedBy'] ?? 'unknown').toString();
                          final markedByLabel = markedBy == 'qr' ? 'scanned' : markedBy;
                          return StaggeredFadeIn(
                            index: index,
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.success,
                                ),
                                title: Text(student['studentName']?.toString() ?? 'Anonymous'),
                                subtitle: Text(
                                  'ID: ${student['enrollmentId']?.toString() ?? 'Anonymous'} | $markedByLabel',
                                  style: textTheme.bodySmall,
                                ),
                                trailing: Text(
                                  _formatMarkedTime(student['markedAt']),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkMuted,
                                  ),
                                ),
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
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: AppColors.secondary, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

