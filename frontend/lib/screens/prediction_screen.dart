import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/services/prediction_service.dart';
import 'package:smart_mess/models/prediction_model.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({Key? key}) : super(key: key);

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final PredictionService _predictionService = PredictionService();
  late Future<PredictionResult?> _predictions;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<UnifiedAuthProvider>();
    _predictions = _predictionService.getPrediction(authProvider.messId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Best Time to Eat'),
        elevation: 0,
        backgroundColor: Color(0xFF6200EE),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Card(
                elevation: 2,
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Color(0xFF6200EE), size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'AI-Powered Crowd Predictions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6200EE),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Machine learning models analyze historical data to predict the best times to visit the mess with minimal crowd.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Predictions section
              Text(
                'Crowd Predictions for Today',
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
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF6200EE),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading predictions...',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Card(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 48),
                            SizedBox(height: 12),
                            Text(
                              'Unable to load predictions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Backend service may be offline',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
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
                          'Predictions unavailable. Please try again later.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Best slot recommendation
                      if (prediction.bestSlot != null) ...[
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF6200EE), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 28),
                                  SizedBox(width: 12),
                                  Text(
                                    'Best Time',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Text(
                                prediction.bestSlot!.timeSlot,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Estimated crowd: ${prediction.bestSlot!.predictedCrowd.toStringAsFixed(0)} students',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                      ],

                      // All time slots
                      Text(
                        'All Time Slots',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...prediction.predictions.map((slot) {
                        final crowdLevel = _getCrowdLevel(slot.crowdPercentage);
                        final crowdColor = _getCrowdColor(slot.crowdPercentage);
                        final crowdIcon = _getCrowdIcon(slot.crowdPercentage);

                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: crowdColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      crowdIcon,
                                      color: crowdColor,
                                      size: 32,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot.timeSlot,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '${slot.predictedCrowd.toStringAsFixed(0)} students expected',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: slot.crowdPercentage / 100,
                                          minHeight: 6,
                                          backgroundColor: Colors.grey[200],
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            crowdColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      crowdLevel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: crowdColor,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${slot.crowdPercentage.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.orange.shade700),
                        SizedBox(width: 12),
                        Text(
                          'Tips for Better Experience',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildTipItem(
                      '- Visit during green/low crowd slots for shorter queues',
                    ),
                    SizedBox(height: 8),
                    _buildTipItem(
                      '- Peak hours usually coincide with typical break times',
                    ),
                    SizedBox(height: 8),
                    _buildTipItem(
                      '- Predictions improve with more historical data',
                    ),
                    SizedBox(height: 8),
                    _buildTipItem(
                      '- Check updated predictions throughout the day',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // How it works card
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
                        Icon(Icons.psychology, color: Colors.blue.shade700),
                        SizedBox(width: 12),
                        Text(
                          'How It Works',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildHowItWorksItem('Historical data', 'Past attendance patterns'),
                    SizedBox(height: 12),
                    _buildHowItWorksItem('ML Analysis', 'Pattern recognition and learning'),
                    SizedBox(height: 12),
                    _buildHowItWorksItem('Real-time prediction', 'Updated crowd forecasts'),
                  ],
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[700],
        height: 1.4,
      ),
    );
  }

  Widget _buildHowItWorksItem(String step, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.blue.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(Icons.check, size: 18, color: Colors.white),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade900,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade600,
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
    if (percentage < 30) return Colors.green;
    if (percentage < 60) return Colors.orange;
    if (percentage < 85) return Colors.deepOrange;
    return Colors.red;
  }

  IconData _getCrowdIcon(double percentage) {
    if (percentage < 30) return Icons.sentiment_very_satisfied;
    if (percentage < 60) return Icons.sentiment_satisfied;
    if (percentage < 85) return Icons.sentiment_dissatisfied;
    return Icons.sentiment_very_dissatisfied;
  }
}
