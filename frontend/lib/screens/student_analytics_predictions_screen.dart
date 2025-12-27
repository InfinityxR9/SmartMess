import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/services/prediction_service.dart';
import 'package:smart_mess/services/review_service.dart';
import 'package:smart_mess/models/prediction_model.dart';
import 'package:smart_mess/utils/meal_time.dart';
import 'package:smart_mess/widgets/reviews_tab.dart';

class StudentAnalyticsPredictionsScreen extends StatefulWidget {
  final bool includeScaffold;
  final bool showAnalytics;
  final bool showPredictions;
  final bool showReviews;

  const StudentAnalyticsPredictionsScreen({
    Key? key,
    this.includeScaffold = true,
    this.showAnalytics = true,
    this.showPredictions = true,
    this.showReviews = false,
  }) : super(key: key);

  @override
  State<StudentAnalyticsPredictionsScreen> createState() => _StudentAnalyticsPredictionsScreenState();
}

class _StudentAnalyticsPredictionsScreenState extends State<StudentAnalyticsPredictionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PredictionService _predictionService = PredictionService();
  final ReviewService _reviewService = ReviewService();
  late Future<Map<String, dynamic>> _analyticsData;
  late Future<PredictionResult?> _predictions;
  MealSlotInfo? _currentSlot;
  Timer? _slotTimer;
  String _messId = '';
  int? _messCapacity;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<UnifiedAuthProvider>();
    _messId = authProvider.messId ?? '';
    _messCapacity = authProvider.messCapacity;
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
        _analyticsData = Future.value(_emptyAnalyticsData());
        _predictions = Future.value(null);
      } else {
        final slotType = _currentSlot!.type;
        _analyticsData = widget.showAnalytics
            ? _fetchAnalyticsData(_messId, slotType)
            : Future.value(_emptyAnalyticsData());
        _predictions = widget.showPredictions
            ? _loadPredictions(slotType)
            : Future.value(null);
      }
    });
  }

  Future<PredictionResult?> _loadPredictions(String slotType) async {
    return _predictionService.trainAndPredict(
      _messId,
      slot: slotType,
      capacity: _messCapacity,
      minutesBack: 15,
      asyncTrain: false,
      forceTrain: true,
    );
  }

  Map<String, dynamic> _emptyAnalyticsData() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return {
      'date': dateStr,
      'capacity': 0,
      'totalAttendance': 0,
      'crowdPercentage': '0',
      'reviews': [],
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

  Future<Map<String, dynamic>> _fetchAnalyticsData(String messId, String meal) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

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

      final totalAttendance = attendanceSnapshot.docs.length;
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
        'reviews': reviews,
        'avgRating': avgRating.toStringAsFixed(1),
        'reviewCount': reviews.length,
      };
    } catch (e) {
      return _emptyAnalyticsData();
    }
  }

  Widget _buildPredictionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming 15-Min Slot Predictions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      ],
    );
  }

  Widget _buildContent({
    required bool showAnalytics,
    required bool showPredictions,
    required bool showReviews,
  }) {
    final slot = _currentSlot;
    final noDataMessage = showAnalytics && showPredictions
        ? 'No analytics or predictions available outside meal hours'
        : showAnalytics
            ? 'No analytics available outside meal hours'
            : showPredictions
                ? 'No predictions available outside meal hours'
                : 'No data available for this view';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                          ? 'Outside meal hours. Analytics show only during meal slots.'
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
            Text(noDataMessage)
          else if (!showAnalytics && showPredictions)
            _buildPredictionsSection()
          else
            FutureBuilder<Map<String, dynamic>>(
              future: _analyticsData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load analytics'));
                }

                final data = snapshot.data ?? {};

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showAnalytics) ...[
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
                              value:
                                  '${data['totalAttendance']?.toString() ?? '0'}/${data['capacity']}',
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
                    ],
                    if (showAnalytics && showPredictions) const SizedBox(height: 24),
                    if (showPredictions) _buildPredictionsSection(),
                    if (showReviews) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Recent Reviews',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if ((data['reviews'] as List?)?.isNotEmpty ?? false)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: (data['reviews'] as List?)?.length ?? 0,
                          itemBuilder: (context, index) {
                            final reviewData = (data['reviews'] as List?)?[index];
                            if (reviewData == null) return const SizedBox.shrink();

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Anonymous',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Row(
                                          children: List.generate(
                                            5,
                                            (i) => Icon(
                                              Icons.star,
                                              size: 16,
                                              color: i < (reviewData['rating'] as int? ?? 0)
                                                  ? Colors.amber
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      reviewData['comment'] ?? '',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatMarkedTime(reviewData['submittedAt']),
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      else
                        const Text('No reviews yet for this slot'),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.includeScaffold &&
        widget.showAnalytics &&
        widget.showPredictions &&
        !widget.showReviews) {
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Analytics & Predictions'),
            elevation: 0,
            backgroundColor: const Color(0xFF6200EE),
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'Reviews'),
                Tab(text: 'Predictions'),
                Tab(text: 'Analytics'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              ReviewsTab(messId: _messId),
              _buildContent(
                showAnalytics: false,
                showPredictions: true,
                showReviews: false,
              ),
              _buildContent(
                showAnalytics: true,
                showPredictions: false,
                showReviews: false,
              ),
            ],
          ),
        ),
      );
    }

    final content = _buildContent(
      showAnalytics: widget.showAnalytics,
      showPredictions: widget.showPredictions,
      showReviews: widget.showReviews,
    );

    if (!widget.includeScaffold) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Predictions'),
        elevation: 0,
        backgroundColor: const Color(0xFF6200EE),
      ),
      body: content,
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
