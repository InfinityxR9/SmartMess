import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smart_mess/services/review_service.dart';
import 'package:smart_mess/utils/meal_time.dart';

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
                        ? 'Outside meal hours. Reviews show only during meal slots.'
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
          const Text('No reviews available outside meal hours')
        else
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _reviews,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final reviews = snapshot.data ?? [];
              if (reviews.isEmpty) {
                return const Text('No reviews yet for this slot');
              }

              return Column(
                children: reviews.map((reviewData) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
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
                }).toList(),
              );
            },
          ),
      ],
    );
  }
}
