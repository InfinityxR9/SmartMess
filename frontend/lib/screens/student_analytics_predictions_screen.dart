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
  late Future<Map<String, dynamic>> _predictionData;
  late Future<Map<String, dynamic>> _todayStats;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<UnifiedAuthProvider>();
    _predictionData = _predictionService.getPrediction(authProvider.messId ?? '').then((result) {
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
    
    _todayStats = _fetchTodayStats(authProvider.messId ?? '');
  }

  Future<Map<String, dynamic>> _fetchTodayStats(String messId) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final messDoc = await _firestore.collection('messes').doc(messId).get();
      final capacity = messDoc.data()?['capacity'] as int? ?? 100;

      // Get total attendance for today
      int totalToday = 0;
      final meals = ['breakfast', 'lunch', 'dinner'];
      
      for (final meal in meals) {
        final snapshot = await _firestore
            .collection('attendance')
            .doc(messId)
            .collection(dateStr)
            .doc(meal)
            .collection('students')
            .get();
        totalToday += snapshot.docs.length;
      }

      return {
        'capacity': capacity,
        'totalAttendance': totalToday,
        'crowdPercentage': ((totalToday / capacity) * 100).toStringAsFixed(1),
      };
    } catch (e) {
      return {
        'capacity': 100,
        'totalAttendance': 0,
        'crowdPercentage': '0.0',
        'error': e.toString(),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crowd Predictions & Analytics'),
        elevation: 0,
        backgroundColor: const Color(0xFF6200EE),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's Statistics
            FutureBuilder<Map<String, dynamic>>(
              future: _todayStats,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                if (!snapshot.hasData) {
                  return const Text('Error loading statistics');
                }

                final stats = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Crowd Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current Attendance',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    '${stats['totalAttendance']}/${stats['capacity']}',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Crowd Level',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    '${stats['crowdPercentage']}%',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // Predictions
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
                  children: [
                    // Chart
                    SizedBox(
                      height: 250,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 && index < predictions.length) {
                                    return Text(
                                      predictions[index].timeSlot.split(' ')[0],
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toInt()}%',
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: predictions.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(), e.value.crowdPercentage);
                              }).toList(),
                              isCurved: true,
                              color: Colors.blue,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Prediction Cards
                    ...predictions.map((pred) {
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
                                  '${pred.predictedCrowd.toInt()} people expected',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${pred.crowdPercentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: isBad
                                        ? Colors.red
                                        : isModerate
                                            ? Colors.orange
                                            : Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isBad
                                        ? Colors.red
                                        : isModerate
                                            ? Colors.orange
                                            : Colors.green,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isBad
                                        ? 'Crowded'
                                        : isModerate
                                            ? 'Moderate'
                                            : 'Good Time',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
