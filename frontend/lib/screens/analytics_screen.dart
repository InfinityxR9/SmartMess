import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/services/attendance_service.dart';
import 'package:smart_mess/services/prediction_service.dart';
import 'package:smart_mess/services/review_service.dart';
import 'package:smart_mess/models/prediction_model.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/utils/meal_time.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics Dashboard'),
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
                elevation: 2,
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Attendance Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Date: ${DateTime.now().toString().split(' ')[0]}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Attendance stats
              Text(
                'Meal-wise Attendance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),

              // Breakfast
              _buildStatCard(
                mealType: 'breakfast',
                title: 'Breakfast',
                icon: Icons.breakfast_dining,
                color: Color(0xFFFFC107),
              ),
              SizedBox(height: 12),

              // Lunch
              _buildStatCard(
                mealType: 'lunch',
                title: 'Lunch',
                icon: Icons.lunch_dining,
                color: Color(0xFF4CAF50),
              ),
              SizedBox(height: 12),

              // Dinner
              _buildStatCard(
                mealType: 'dinner',
                title: 'Dinner',
                icon: Icons.dinner_dining,
                color: Color(0xFF2196F3),
              ),
              SizedBox(height: 24),

              // Total
              FutureBuilder<Map<String, int>>(
                future: _attendanceCounts,
                builder: (context, snapshot) {
                  final counts = snapshot.data ?? {};
                  final total = (counts['breakfast'] ?? 0) + 
                                (counts['lunch'] ?? 0) + 
                                (counts['dinner'] ?? 0);
                  return Card(
                    elevation: 4,
                    color: Color(0xFF6200EE),
                    child: Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'Total Attendance Today',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            '$total',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'students marked across all meals',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 24),

              // ML Predictions Section
              Text(
                'Crowd Predictions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              FutureBuilder<PredictionResult?>(
                future: _predictions,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Card(
                      child: Container(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  final prediction = snapshot.data;
                  if (prediction == null || prediction.predictions.isEmpty) {
                    return Card(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Predictions unavailable. Backend service may be offline.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: prediction.predictions.map((slot) {
                      final crowdLevel = _getCrowdLevel(slot.crowdPercentage);
                      final crowdColor = _getCrowdColor(slot.crowdPercentage);
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: crowdColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.people, color: crowdColor, size: 32),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      slot.timeSlot,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${slot.predictedCrowd.toStringAsFixed(0)} students',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    crowdLevel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: crowdColor,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Container(
                                    width: 60,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 60 * (slot.crowdPercentage / 100),
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: crowdColor,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              SizedBox(height: 24),

              // Customer Reviews Section
              Text(
                'Meal Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _reviewService.getMessReviews(messId: widget.messId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Card(
                      child: Container(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final reviews = snapshot.data ?? [];
                  if (reviews.isEmpty) {
                    return Card(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No reviews yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final review = reviews[index];
                      final rating = review['rating'] ?? 0;
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    (review['mealType'] ?? 'Unknown').toString().toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(5, (i) {
                                      return Icon(
                                        Icons.star,
                                        size: 16,
                                        color: i < rating ? Colors.amber : Colors.grey[300],
                                      );
                                    }),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              if (review['comment'] != null && (review['comment'] as String).isNotEmpty)
                                Text(
                                  review['comment'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              SizedBox(height: 8),
                              Text(
                                'Anonymous feedback',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 24),

              // Tips
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700),
                        SizedBox(width: 12),
                        Text(
                          'Tips',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '- Monitor meal-wise attendance patterns\n'
                      '- Identify peak hours for better resource planning\n'
                      '- Use this data to improve meal planning\n'
                      '- Track which meals are more popular\n'
                      '- Prepare for expected crowds',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade900,
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
          elevation: 2,
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$count students marked',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
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
    if (percentage < 30) return Colors.green;
    if (percentage < 60) return Colors.orange;
    if (percentage < 85) return Colors.deepOrange;
    return Colors.red;
  }
}
