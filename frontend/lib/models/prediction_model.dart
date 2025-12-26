class PredictionResult {
  final String messId;
  final List<TimeSlotPrediction> predictions;
  final TimeSlotPrediction? bestSlot;

  PredictionResult({
    required this.messId,
    required this.predictions,
    this.bestSlot,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final predictions = (json['predictions'] as List<dynamic>?)
        ?.map((p) => TimeSlotPrediction.fromJson(p as Map<String, dynamic>))
        .toList() ?? [];
    
    final bestSlotData = json['best_slot'] as Map<String, dynamic>?;
    final bestSlot = bestSlotData != null 
        ? TimeSlotPrediction.fromJson(bestSlotData)
        : null;

    return PredictionResult(
      messId: json['messId'] ?? '',
      predictions: predictions,
      bestSlot: bestSlot,
    );
  }
}

class TimeSlotPrediction {
  final String timeSlot;
  final double predictedCrowd;
  final double crowdPercentage;

  TimeSlotPrediction({
    required this.timeSlot,
    required this.predictedCrowd,
    required this.crowdPercentage,
  });

  factory TimeSlotPrediction.fromJson(Map<String, dynamic> json) {
    final predictedCrowd = (json['predicted_crowd'] ?? 0.0).toDouble();
    final capacity = (json['capacity'] ?? 0.0).toDouble();
    final crowdPercentage = capacity > 0
        ? (predictedCrowd / capacity) * 100
        : (json['crowd_percentage'] ?? 0.0).toDouble();
    return TimeSlotPrediction(
      timeSlot: json['time_slot'] ?? '',
      predictedCrowd: predictedCrowd,
      crowdPercentage: crowdPercentage,
    );
  }
}
