import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/services/attendance_service.dart';
import 'package:smart_mess/services/prediction_service.dart';
import 'package:smart_mess/services/review_service.dart';
import 'package:smart_mess/models/prediction_model.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/utils/meal_time.dart';
import 'package:smart_mess/theme/app_tokens.dart';
import 'package:smart_mess/widgets/animated_metric_bar.dart';
import 'package:smart_mess/widgets/empty_state.dart';
import 'package:smart_mess/widgets/section_header.dart';
import 'package:smart_mess/widgets/skeleton_loader.dart';
import 'package:smart_mess/widgets/staggered_fade_in.dart';

class AnalyticsScreen extends StatefulWidget {
  final String messId;

  const AnalyticsScreen({
    Key? key,
    required this.messId,
  }) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final PredictionService _predictionService = PredictionService();
  final ReviewService _reviewService = ReviewService();
  late Future<Map<String, int>> _attendanceCounts;
  late Future<PredictionResult?> _predictions;
  int? _messCapacity;

  @override
  void initState() {
    super.initState();
    _attendanceCounts = _attendanceService.getTodayAttendanceCount(widget.messId);
    _messCapacity = context.read<UnifiedAuthProvider>().messCapacity;
    final slot = getCurrentMealSlot();
    _predictions = _loadPredictions(slot?.type);
  }

  Future<PredictionResult?> _loadPredictions(String? slot) async {
    return _predictionService.trainAndPredict(
      widget.messId,
      slot: slot,
      capacity: _messCapacity,
      minutesBack: 15,
      asyncTrain: false,
      forceTrain: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date info
              Card(
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: AppColors.accent,
                              size: AppSizes.iconSm,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Today\'s Attendance Summary',
                            style: textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Date: ${DateTime.now().toString().split(' ')[0]}',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Attendance stats
              const SectionHeader(
                title: 'Meal-wise Attendance',
                icon: Icons.restaurant_menu,
              ),
              const SizedBox(height: 16),

              // Breakfast
              _buildStatCard(
                mealType: 'breakfast',
                title: 'Breakfast',
                icon: Icons.breakfast_dining,
                color: AppColors.secondary,
              ),
              const SizedBox(height: 12),

              // Lunch
              _buildStatCard(
                mealType: 'lunch',
                title: 'Lunch',
                icon: Icons.lunch_dining,
                color: AppColors.success,
              ),
              const SizedBox(height: 12),

              // Dinner
              _buildStatCard(
                mealType: 'dinner',
                title: 'Dinner',
                icon: Icons.dinner_dining,
                color: AppColors.accent,
              ),
              const SizedBox(height: 24),

              // Total
              FutureBuilder<Map<String, int>>(
                future: _attendanceCounts,
                builder: (context, snapshot) {
                  final counts = snapshot.data ?? {};
                  final total = (counts['breakfast'] ?? 0) + 
                                (counts['lunch'] ?? 0) + 
                                (counts['dinner'] ?? 0);
                  return Card(
                    elevation: 0,
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: AppShadows.floating,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Attendance Today',
                            style: textTheme.titleMedium?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$total',
                            style: textTheme.displayMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'students marked across all meals',
                            style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ML Predictions Section
              const SectionHeader(
                title: 'Crowd Predictions',
                icon: Icons.insights,
              ),
              const SizedBox(height: 16),
              FutureBuilder<PredictionResult?>(
                future: _predictions,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SkeletonList(itemCount: 2, lineCount: 2);
                  }

                  final prediction = snapshot.data;
                  if (prediction == null || prediction.predictions.isEmpty) {
                    return const EmptyStateCard(
                      icon: Icons.bar_chart,
                      title: 'Predictions unavailable',
                      message:
                          'We could not load predictions right now. Try again during meal times.',
                    );
                  }

                  return Column(
                    children: prediction.predictions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final slot = entry.value;
                      final crowdLevel = _getCrowdLevel(slot.crowdPercentage);
                      final crowdColor = _getCrowdColor(slot.crowdPercentage);
                      
                      return StaggeredFadeIn(
                        index: index,
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: crowdColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(AppRadii.sm),
                                  ),
                                  child:
                                      Icon(Icons.people, color: crowdColor, size: 32),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot.timeSlot,
                                        style: textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${slot.predictedCrowd.toStringAsFixed(0)} students',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      AnimatedMetricBar(
                                        percentage: slot.crowdPercentage,
                                        color: crowdColor,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      crowdLevel,
                                      style: textTheme.labelLarge?.copyWith(
                                        color: crowdColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${slot.crowdPercentage.toStringAsFixed(0)}%',
                                      style: textTheme.titleMedium?.copyWith(
                                        color: crowdColor,
                                      ),
                                    ),
                                  ],
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

              // Customer Reviews Section
              const SectionHeader(
                title: 'Meal Reviews',
                icon: Icons.rate_review,
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _reviewService.getMessReviews(messId: widget.messId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SkeletonList(itemCount: 2, lineCount: 2);
                  }

                  final reviews = snapshot.data ?? [];
                  if (reviews.isEmpty) {
                    return const EmptyStateCard(
                      icon: Icons.star_border,
                      title: 'No reviews yet',
                      message: 'Encourage students to share quick feedback.',
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      final rating = review['rating'] ?? 0;
                      
                      return StaggeredFadeIn(
                        index: index,
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      (review['mealType'] ?? 'Unknown')
                                          .toString()
                                          .toUpperCase(),
                                      style: textTheme.labelLarge?.copyWith(
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                    Row(
                                      children: List.generate(5, (i) {
                                        return Icon(
                                          Icons.star,
                                          size: 16,
                                          color: i < rating
                                              ? AppColors.secondary
                                              : AppColors.outlineSubtle,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (review['comment'] != null &&
                                    (review['comment'] as String).isNotEmpty)
                                  Text(
                                    review['comment'],
                                    style: textTheme.bodyMedium,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  'Anonymous feedback',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkMuted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),

              // Tips
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Tips',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '- Monitor meal-wise attendance patterns\n'
                      '- Identify peak hours for better resource planning\n'
                      '- Use this data to improve meal planning\n'
                      '- Track which meals are more popular\n'
                      '- Prepare for expected crowds',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String mealType,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return FutureBuilder<Map<String, int>>(
      future: _attendanceCounts,
      builder: (context, snapshot) {
        final counts = snapshot.data ?? {};
        final count = counts[mealType] ?? 0;
        return Card(
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Center(
                    child: Icon(icon, size: 32, color: color),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$count students marked',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getCrowdLevel(double percentage) {
    if (percentage < 30) return 'Low';
    if (percentage < 60) return 'Medium';
    if (percentage < 85) return 'High';
    return 'Very High';
  }

  Color _getCrowdColor(double percentage) {
    if (percentage < 30) return AppColors.success;
    if (percentage < 60) return AppColors.warning;
    if (percentage < 85) return AppColors.accent;
    return AppColors.danger;
  }
}

