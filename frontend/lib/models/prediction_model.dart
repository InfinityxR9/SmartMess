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
    final predictions = <TimeSlotPrediction>[];
    final rawPredictions = json['predictions'];
    if (rawPredictions is List) {
      for (final item in rawPredictions) {
        if (item is Map<String, dynamic>) {
          predictions.add(TimeSlotPrediction.fromJson(item));
        } else if (item is Map) {
          predictions.add(TimeSlotPrediction.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    final bestSlotRaw = json['best_slot'] ?? json['bestSlot'];
    TimeSlotPrediction? bestSlot;
    if (bestSlotRaw is Map<String, dynamic>) {
      bestSlot = TimeSlotPrediction.fromJson(bestSlotRaw);
    } else if (bestSlotRaw is Map) {
      bestSlot = TimeSlotPrediction.fromJson(Map<String, dynamic>.from(bestSlotRaw));
    }

    return PredictionResult(
      messId: (json['messId'] ?? json['mess_id'] ?? '').toString(),
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
    double readDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final predictedCrowd = readDouble(json['predicted_crowd'] ?? json['predictedCrowd']);
    final capacity = readDouble(json['capacity']);
    double crowdPercentage = capacity > 0
        ? (predictedCrowd / capacity) * 100
        : readDouble(json['crowd_percentage'] ?? json['crowdPercentage']);
    if (crowdPercentage.isNaN || crowdPercentage.isInfinite) {
      crowdPercentage = 0.0;
    }
    return TimeSlotPrediction(
      timeSlot: (json['time_slot'] ?? json['timeSlot'] ?? '').toString(),
      predictedCrowd: predictedCrowd,
      crowdPercentage: crowdPercentage,
    );
  }
}
