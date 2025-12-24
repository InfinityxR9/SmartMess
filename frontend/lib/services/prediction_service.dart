import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:smart_mess/models/prediction_model.dart';

class PredictionService {
  // Points to local backend running on port 8080
  // In production, replace with actual Cloud Run endpoint
  static const String baseUrl = 'http://localhost:8080';

  Future<PredictionResult?> getPrediction(String messId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messId': messId,
          'devMode': true,  // Enable dev mode to show predictions outside meal times
        }),
      ).timeout(Duration(seconds: 10));

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
}
