import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/services/prediction_service.dart';
import 'package:smart_mess/models/prediction_model.dart';
import 'package:fl_chart/fl_chart.dart';

class StudentAnalyticsPredictionsScreen extends StatefulWidget {
  const StudentAnalyticsPredictionsScreen({Key? key}) : super(key: key);

  @override
  State<StudentAnalyticsPredictionsScreen> createState() => _StudentAnalyticsPredictionsScreenState();
}

class _StudentAnalyticsPredictionsScreenState extends State<StudentAnalyticsPredictionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PredictionService _predictionService = PredictionService();
  late Future<Map<String, dynamic>> _analyticsData;
  late Future<Map<String, dynamic>> _predictionData;
  String _selectedMeal = 'breakfast';

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<UnifiedAuthProvider>();
    final messId = authProvider.messId ?? '';
    
    _analyticsData = _fetchAnalyticsData(messId, _selectedMeal);
    _predictionData = _predictionService.getPrediction(messId).then((result) {
      return {
        'predictions': result?.predictions ?? [],
        'bestSlot': result?.bestSlot,
      };
    }).onError((error, stack) {
      return {
        'predictions': [],
        'bestSlot': null,
        'error': error.toString(),
      };
    });
  }

  Future<Map<String, dynamic>> _fetchAnalyticsData(String messId, String meal) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      // Get mess info for capacity
      final messSnapshot = await _firestore.collection('messes').doc(messId).get();
      final capacity = (messSnapshot.data()?['capacity'] ?? 0) as int;

      // Fetch attendance for this meal and date
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

      // Fetch reviews for this meal and date
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .doc(messId)
          .collection(dateStr)
          .doc(meal)
          .collection('items')
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
        'reviews': [],
        'avgRating': '0',
        'reviewCount': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<UnifiedAuthProvider>();
    final messId = authProvider.messId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Predictions'),
        elevation: 0,
        backgroundColor: const Color(0xFF6200EE),
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
                        DropdownMenuItem(value: 'breakfast', child: Text('Breakfast (7:30-9:30)')),
                        DropdownMenuItem(value: 'lunch', child: Text('Lunch (12:00-14:00)')),
                        DropdownMenuItem(value: 'dinner', child: Text('Dinner (19:30-21:30)')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedMeal = value;
                            _analyticsData = _fetchAnalyticsData(messId, _selectedMeal);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Analytics Section
            const Text(
              'Today\'s Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>>(
              future: _analyticsData,
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
                            value: '${data['avgRating'] ?? '0'} â˜…',
                            icon: Icons.rate_review,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
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
                      const Text('No reviews yet for this slot'),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Predictions Section
            const Text(
              'Upcoming 15-Min Slot Predictions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>>(
              future: _predictionData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Unable to load predictions. Try again later.'),
                  );
                }

                final data = snapshot.data!;
                final predictions = (data['predictions'] as List?)?.cast<TimeSlotPrediction>() ?? [];

                if (predictions.isEmpty) {
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
                  children: predictions.map((pred) {
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
