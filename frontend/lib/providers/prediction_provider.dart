import 'package:flutter/foundation.dart';
import 'package:smart_mess/services/prediction_service.dart';
import 'package:smart_mess/models/prediction_model.dart';

class PredictionProvider extends ChangeNotifier {
  final PredictionService _predictionService = PredictionService();
  PredictionResult? _prediction;
  bool _isLoading = false;
  String? _error;

  PredictionResult? get prediction => _prediction;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchPrediction(String messId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _prediction = await _predictionService.getPrediction(messId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Handle error silently
      _error = 'Failed to fetch prediction';
      _isLoading = false;
      notifyListeners();
    }
  }
}
