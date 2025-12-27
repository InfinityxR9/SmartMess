import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_mess/services/review_service.dart';
import 'package:smart_mess/utils/meal_time.dart';
import 'package:smart_mess/theme/app_tokens.dart';
import 'package:smart_mess/widgets/empty_state.dart';
import 'package:smart_mess/widgets/skeleton_loader.dart';
import 'package:smart_mess/widgets/staggered_fade_in.dart';

class ReviewsTab extends StatefulWidget {
  final String messId;

  const ReviewsTab({
    Key? key,
    required this.messId,
  }) : super(key: key);

  @override
  State<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<ReviewsTab> {
  final ReviewService _reviewService = ReviewService();
  MealSlotInfo? _currentSlot;
  Timer? _slotTimer;
  late Future<List<Map<String, dynamic>>> _reviews;
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
        _reviews = Future.value([]);
      } else {
        final now = DateTime.now();
        final dateStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        _reviews = _reviewService.getReviewsForDateAndSlot(
          messId: widget.messId,
          date: dateStr,
          slot: _currentSlot!.type,
        );
      }
    });
  }

  String _formatMarkedTime(dynamic markedAt) {
    if (markedAt == null) return '';
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
                        ? 'Outside meal hours. Reviews show only during meal slots.'
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
            title: 'No reviews right now',
            message: 'Reviews appear during active meal slots.',
          )
        else
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _reviews,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SkeletonList(itemCount: 2, lineCount: 2);
              }

              final reviews = snapshot.data ?? [];
              if (reviews.isEmpty) {
                return const EmptyStateCard(
                  icon: Icons.rate_review_outlined,
                  title: 'No reviews yet',
                  message: 'Be the first to share feedback for this meal.',
                );
              }

              return Column(
                children: reviews.asMap().entries.map((entry) {
                  final index = entry.key;
                  final reviewData = entry.value;
                  return StaggeredFadeIn(
                    index: index,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Anonymous',
                                  style: textTheme.titleSmall,
                                ),
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      Icons.star,
                                      size: 16,
                                      color: i < (reviewData['rating'] as int? ?? 0)
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
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}

