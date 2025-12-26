import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:smart_mess/models/prediction_model.dart';

class PredictionService {
  // Use --dart-define=SMARTMESS_BACKEND_URL=... to override in production.
  static const String baseUrl =
      String.fromEnvironment('SMARTMESS_BACKEND_URL', defaultValue: 'http://localhost:8080');

  Future<PredictionResult?> getPrediction(
    String messId, {
    String? slot,
    bool forceTrain = true,
    int daysBack = 30,
  }) async {
    try {
      if (messId.isEmpty) {
        return null;
      }
      final response = await http.post(
        Uri.parse('$baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messId': messId,
          'devMode': true,
          'slot': slot,
          'forceTrain': forceTrain,
          'daysBack': daysBack,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PredictionResult.fromJson(data);
      } else {
        print('[Prediction] Backend returned ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('[Prediction] Error: $e');
      return null;
    }
  }

  Future<void> trainModel(
    String messId, {
    String? slot,
    int daysBack = 30,
  }) async {
    try {
      if (messId.isEmpty) {
        return;
      }
      await http
          .post(
            Uri.parse('$baseUrl/train'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'messId': messId,
              'slot': slot,
              'daysBack': daysBack,
              'forceTrain': true,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Ignore training errors; predictions handle fallbacks.
    }
  }
}
