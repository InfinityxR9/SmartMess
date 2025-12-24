import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  String _selectedMeal = 'breakfast';

  Future<Map<String, dynamic>> _fetchAnalyticsData(String messId, String meal) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      // Fetch mess info for capacity
      final messSnapshot = await _firestore.collection('messes').doc(messId).get();
      final capacity = (messSnapshot.data()?['capacity'] ?? 0) as int;

      // Fetch attendance for this meal
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .doc(messId)
          .collection(dateStr)
          .doc(meal)
          .get();

      final totalAttendance = (attendanceSnapshot.data()?['students'] as List?)?.length ?? 0;
      final students = (attendanceSnapshot.data()?['students'] as List?) ?? [];

      final crowdPercentage =
          capacity > 0 ? ((totalAttendance / capacity) * 100).toStringAsFixed(1) : '0';

      // Fetch reviews
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('messId', isEqualTo: messId)
          .where('date', isEqualTo: dateStr)
          .where('mealSlot', isEqualTo: meal)
          .get();

      List<Map<String, dynamic>> reviews = [];
      double avgRating = 0;

      if (reviewsSnapshot.docs.isNotEmpty) {
        reviews = reviewsSnapshot.docs
            .map((doc) {
              final data = doc.data();
              return {
                'rating': data['rating'] ?? 0,
                'comment': data['comment'] ?? '',
                'studentName': data['studentName'] ?? 'Anonymous',
              };
            })
            .toList();

        avgRating = reviews.fold<double>(0, (sum, r) => sum + ((r['rating'] as int?) ?? 0)) /
            reviews.length;
      }

      return {
        'capacity': capacity,
        'totalAttendance': totalAttendance,
        'crowdPercentage': crowdPercentage,
        'students': students,
        'reviews': reviews,
        'avgRating': avgRating.toStringAsFixed(1),
        'reviewCount': reviews.length,
      };
    } catch (e) {
      print('Error fetching analytics: $e');
      return {
        'capacity': 0,
        'totalAttendance': 0,
        'crowdPercentage': '0',
        'students': [],
        'reviews': [],
        'avgRating': '0',
        'reviewCount': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // Meal Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Meal', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedMeal,
                      items: const [
                        DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                        DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                        DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedMeal = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Analytics Data
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchAnalyticsData(widget.messId, _selectedMeal),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final data = snapshot.data ?? {};

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Row
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
                            value: '${data['avgRating'] ?? '0'} ★',
                            icon: Icons.rate_review,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Attendance List
                    if ((data['students'] as List?)?.isNotEmpty ?? false) ...[
                      const Text(
                        'Student Attendance',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: (data['students'] as List?)?.length ?? 0,
                        itemBuilder: (context, index) {
                          final student = (data['students'] as List?)?[index] ?? {};
                          return ListTile(
                            leading: const Icon(Icons.check_circle_outline),
                            title: Text(student.toString()),
                            subtitle: const Text('Marked'),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Reviews Section
                    if ((data['reviews'] as List?)?.isNotEmpty ?? false) ...[
                      const Text(
                        'Recent Reviews',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
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
                                      Text(
                                        reviewData['studentName'] ?? 'Anonymous',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ] else
                      const Text('No reviews yet'),
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
