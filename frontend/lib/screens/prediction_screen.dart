import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/services/prediction_service.dart';
import 'package:smart_mess/models/prediction_model.dart';
import 'package:smart_mess/utils/meal_time.dart';
import 'package:smart_mess/theme/app_tokens.dart';
import 'package:smart_mess/widgets/animated_metric_bar.dart';
import 'package:smart_mess/widgets/empty_state.dart';
import 'package:smart_mess/widgets/section_header.dart';
import 'package:smart_mess/widgets/skeleton_loader.dart';
import 'package:smart_mess/widgets/staggered_fade_in.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({Key? key}) : super(key: key);

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final PredictionService _predictionService = PredictionService();
  late Future<PredictionResult?> _predictions;
  int? _messCapacity;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<UnifiedAuthProvider>();
    _messCapacity = authProvider.messCapacity;
    final slot = getCurrentMealSlot();
    _predictions = _loadPredictions(authProvider.messId ?? '', slot?.type);
  }

  Future<PredictionResult?> _loadPredictions(String messId, String? mealType) async {
    return _predictionService.getPrediction(
      messId,
      mealType: mealType,
      capacity: _messCapacity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Best Time to Eat'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Card(
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info, color: AppColors.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'AI-Powered Crowd Predictions',
                              style: textTheme.titleLarge?.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Machine learning models analyze historical data to predict the best times to visit the mess with minimal crowd.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Predictions section
              const SectionHeader(
                title: 'Crowd Predictions for Today',
                icon: Icons.insights,
              ),
              const SizedBox(height: 16),

              FutureBuilder<PredictionResult?>(
                future: _predictions,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SkeletonList(itemCount: 2, lineCount: 2);
                  }

                  if (snapshot.hasError) {
                    return const EmptyStateCard(
                      icon: Icons.warning_amber,
                      title: 'Unable to load predictions',
                      message: 'Backend service may be offline.',
                    );
                  }

                  final prediction = snapshot.data;
                  if (prediction == null || prediction.predictions.isEmpty) {
                    return const EmptyStateCard(
                      icon: Icons.bar_chart,
                      title: 'Predictions unavailable',
                      message: 'Please try again later.',
                    );
                  }

                  return Column(
                    children: [
                      // Best slot recommendation
                      if (prediction.bestSlot != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppGradients.primary,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            boxShadow: AppShadows.floating,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.star, color: AppColors.secondary, size: 28),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Best Time',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                prediction.bestSlot!.timeSlot,
                                style: textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Estimated crowd: ${prediction.bestSlot!.predictedCrowd.toStringAsFixed(0)} students',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                      ],

                      // All time slots
                      const SectionHeader(
                        title: 'All Time Slots',
                        icon: Icons.timeline,
                      ),
                      const SizedBox(height: 12),
                      ...prediction.predictions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final slot = entry.value;
                        final crowdLevel = _getCrowdLevel(slot.crowdPercentage);
                        final crowdColor = _getCrowdColor(slot.crowdPercentage);
                        final crowdIcon = _getCrowdIcon(slot.crowdPercentage);

                        return StaggeredFadeIn(
                          index: index,
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: crowdColor.withValues(alpha: 0.2),
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.sm),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        crowdIcon,
                                        color: crowdColor,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          slot.timeSlot,
                                          style: textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${slot.predictedCrowd.toStringAsFixed(0)} students expected',
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
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        crowdLevel,
                                        style: textTheme.labelLarge?.copyWith(
                                          color: crowdColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${slot.crowdPercentage.toStringAsFixed(0)}%',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.inkMuted,
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
                    ],
                  );
                },
              ),
              SizedBox(height: 24),

              // Tips card
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Tips for Better Experience',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem(
                      '- Visit during green/low crowd slots for shorter queues',
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem(
                      '- Peak hours usually coincide with typical break times',
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem(
                      '- Predictions improve with more historical data',
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem(
                      '- Check updated predictions throughout the day',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // How it works card
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
                        const Icon(Icons.psychology, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Text(
                          'How It Works',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHowItWorksItem('Historical data', 'Past attendance patterns'),
                    const SizedBox(height: 12),
                    _buildHowItWorksItem('ML Analysis', 'Pattern recognition and learning'),
                    const SizedBox(height: 12),
                    _buildHowItWorksItem('Real-time prediction', 'Updated crowd forecasts'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    final textTheme = Theme.of(context).textTheme;
    return Text(
      text,
      style: textTheme.bodyMedium?.copyWith(
        color: AppColors.inkMuted,
        height: 1.4,
      ),
    );
  }

  Widget _buildHowItWorksItem(String step, String description) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
              child: const Center(
                child: Icon(Icons.check, size: 18, color: Colors.white),
              ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              Text(
                description,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
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

  IconData _getCrowdIcon(double percentage) {
    if (percentage < 30) return Icons.sentiment_very_satisfied;
    if (percentage < 60) return Icons.sentiment_satisfied;
    if (percentage < 85) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_very_dissatisfied;
  }
}

