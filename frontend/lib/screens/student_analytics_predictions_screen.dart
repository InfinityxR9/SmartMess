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
import 'package:smart_mess/theme/app_tokens.dart';
import 'package:smart_mess/widgets/animated_metric_bar.dart';
import 'package:smart_mess/widgets/empty_state.dart';
import 'package:smart_mess/widgets/section_header.dart';
import 'package:smart_mess/widgets/skeleton_loader.dart';
import 'package:smart_mess/widgets/staggered_fade_in.dart';

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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Upcoming 15-Min Slot Predictions',
          icon: Icons.insights,
        ),
        const SizedBox(height: 12),
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
                              borderRadius: BorderRadius.circular(AppRadii.sm),
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
                                Text(pred.timeSlot, style: textTheme.titleSmall),
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
    );
  }

  Widget _buildContent({
    required bool showAnalytics,
    required bool showPredictions,
    required bool showReviews,
  }) {
    final slot = _currentSlot;
    final textTheme = Theme.of(context).textTheme;
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
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      slot == null
                          ? 'Outside meal hours. Analytics show only during meal slots.'
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
            EmptyStateCard(
              icon: Icons.schedule,
              title: 'No data right now',
              message: noDataMessage,
            )
          else if (!showAnalytics && showPredictions)
            _buildPredictionsSection()
          else
            FutureBuilder<Map<String, dynamic>>(
              future: _analyticsData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SkeletonList(itemCount: 2, lineCount: 2);
                }

                if (snapshot.hasError) {
                  return const EmptyStateCard(
                    icon: Icons.warning_amber,
                    title: 'Unable to load analytics',
                    message: 'Please try again in a moment.',
                  );
                }

                final data = snapshot.data ?? {};

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showAnalytics) ...[
                      Text(
                        'Date: ${data['date'] ?? ''}',
                        style:
                            textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
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
                      const SectionHeader(
                        title: 'Recent Reviews',
                        icon: Icons.rate_review,
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

                            return StaggeredFadeIn(
                              index: index,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Anonymous', style: textTheme.titleSmall),
                                          Row(
                                            children: List.generate(
                                              5,
                                              (i) => Icon(
                                                Icons.star,
                                                size: 16,
                                                color:
                                                    i < (reviewData['rating'] as int? ?? 0)
                                                        ? AppColors.secondary
                                                        : AppColors.outlineSubtle,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        reviewData['comment'] ?? '',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatMarkedTime(reviewData['submittedAt']),
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        const EmptyStateCard(
                          icon: Icons.star_border,
                          title: 'No reviews yet',
                          message: 'Feedback will show up once students submit reviews.',
                        ),
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
            bottom: const TabBar(
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
            Icon(icon, color: AppColors.secondary, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

