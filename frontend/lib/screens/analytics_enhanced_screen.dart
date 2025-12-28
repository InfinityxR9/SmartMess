import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_mess/services/review_service.dart';
import 'package:smart_mess/utils/meal_time.dart';
import 'package:smart_mess/theme/app_tokens.dart';
import 'package:smart_mess/widgets/empty_state.dart';
import 'package:smart_mess/widgets/section_header.dart';
import 'package:smart_mess/widgets/skeleton_loader.dart';
import 'package:smart_mess/widgets/staggered_fade_in.dart';

class AnalyticsEnhancedScreen extends StatefulWidget {
  final String messId;

  const AnalyticsEnhancedScreen({
    Key? key,
    required this.messId,
  }) : super(key: key);

  @override
  State<AnalyticsEnhancedScreen> createState() => _AnalyticsEnhancedScreenState();
}

class _AnalyticsEnhancedScreenState extends State<AnalyticsEnhancedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ReviewService _reviewService = ReviewService();
  late Future<Map<String, dynamic>> _analyticsData;
  MealSlotInfo? _currentSlot;
  Timer? _slotTimer;
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
        _analyticsData = Future.value(_emptyAnalyticsData());
      } else {
        _analyticsData = _fetchAnalyticsData(widget.messId, _currentSlot!.type);
      }
    });
  }

  Map<String, dynamic> _emptyAnalyticsData() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return {
      'date': dateStr,
      'capacity': 0,
      'totalAttendance': 0,
      'crowdPercentage': '0',
      'students': [],
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
        'reviews': reviews,
        'avgRating': avgRating.toStringAsFixed(1),
        'reviewCount': reviews.length,
      };
    } catch (e) {
      return _emptyAnalyticsData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = _currentSlot;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
              const EmptyStateCard(
                icon: Icons.access_time,
                title: 'No analytics right now',
                message: 'Analytics are available during active meal slots.',
              )
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
                      if ((data['students'] as List?)?.isNotEmpty ?? false) ...[
                        const SectionHeader(
                          title: 'Student Attendance',
                          icon: Icons.check_circle,
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: (data['students'] as List?)?.length ?? 0,
                          itemBuilder: (context, index) {
                            final student = (data['students'] as List?)?[index] ?? {};
                            final markedBy = (student['markedBy'] ?? 'unknown').toString();
                            final markedByLabel = markedBy == 'qr' ? 'scanned' : markedBy;
                            return StaggeredFadeIn(
                              index: index,
                              child: Card(
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.check_circle_outline,
                                    color: AppColors.success,
                                  ),
                                  title:
                                      Text(student['studentName']?.toString() ?? 'Anonymous'),
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
                        const SizedBox(height: 24),
                      ] else
                        const EmptyStateCard(
                          icon: Icons.person_off,
                          title: 'No attendance marked',
                          message: 'Attendance will appear as students check in.',
                        ),
                      if ((data['reviews'] as List?)?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 24),
                        const SectionHeader(
                          title: 'Recent Reviews',
                          icon: Icons.rate_review,
                        ),
                        const SizedBox(height: 12),
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
                        ),
                      ] else
                        const EmptyStateCard(
                          icon: Icons.star_border,
                          title: 'No reviews yet',
                          message: 'Feedback will show up once students submit reviews.',
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
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

