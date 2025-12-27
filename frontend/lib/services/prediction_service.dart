import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:smart_mess/models/prediction_model.dart';

class PredictionService {
  // Use --dart-define=SMARTMESS_BACKEND_URL=... to override in production.
  static const String baseUrl =
      String.fromEnvironment('SMARTMESS_BACKEND_URL', defaultValue: 'http://localhost:8080');

  bool _shouldSkipWebRequest() {
    if (!kIsWeb) return false;
    if (baseUrl.trim().isEmpty) return true;
    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null || !baseUri.hasScheme) {
      return true;
    }
    final pageUri = Uri.base;
    if (pageUri.scheme == 'https' && baseUri.scheme == 'http') {
      return true; // mixed content blocked by browsers
    }
    final baseHost = baseUri.host;
    final pageHost = pageUri.host;
    final isLocalBase = baseHost == 'localhost' || baseHost == '127.0.0.1';
    final isLocalPage = pageHost == 'localhost' || pageHost == '127.0.0.1';
    if (isLocalBase && !isLocalPage) {
      return true; // hosted app still pointing to localhost
    }
    return false;
  }

  void _logWebSkip() {
    if (!kIsWeb) return;
    final pageUri = Uri.base;
    print(
      '[Prediction] Backend URL is not configured for web hosting. '
      'Current page: ${pageUri.origin}, baseUrl: $baseUrl',
    );
  }

  String? _normalizeSlot(String? slot) {
    if (slot == null) return null;
    final normalized = slot.trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  Future<PredictionResult?> getPrediction(
    String messId, {
    String? slot,
    bool forceTrain = false,
    bool autoTrain = true,
    bool asyncTrain = true,
    int daysBack = 30,
    int? minutesBack,
    int? capacity,
  }) async {
    try {
      if (messId.isEmpty) {
        return null;
      }
      if (_shouldSkipWebRequest()) {
        _logWebSkip();
        return null;
      }
      final normalizedSlot = _normalizeSlot(slot);
      final payload = <String, dynamic>{
        'messId': messId,
        'devMode': true,
        'forceTrain': forceTrain,
        'autoTrain': autoTrain,
        'asyncTrain': asyncTrain,
        'daysBack': daysBack,
      };
      if (normalizedSlot != null) {
        payload['slot'] = normalizedSlot;
      }
      if (minutesBack != null && minutesBack > 0) {
        payload['minutesBack'] = minutesBack;
      }
      if (capacity != null && capacity > 0) {
        payload['capacity'] = capacity;
      }
      final response = await http.post(
        Uri.parse('$baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
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

  Future<bool> trainModel(
    String messId, {
    String? slot,
    int daysBack = 30,
    int? minutesBack,
    int? capacity,
    bool asyncTrain = true,
    bool forceTrain = false,
  }) async {
    try {
      if (messId.isEmpty) {
        return false;
      }
      if (_shouldSkipWebRequest()) {
        _logWebSkip();
        return false;
      }
      final normalizedSlot = _normalizeSlot(slot);
      final payload = <String, dynamic>{
        'messId': messId,
        'daysBack': daysBack,
        'forceTrain': forceTrain,
        'devMode': true,
        'asyncTrain': asyncTrain,
      };
      if (normalizedSlot != null) {
        payload['slot'] = normalizedSlot;
      }
      if (minutesBack != null && minutesBack > 0) {
        payload['minutesBack'] = minutesBack;
      }
      if (capacity != null && capacity > 0) {
        payload['capacity'] = capacity;
      }
      final response = await http
          .post(
            Uri.parse('$baseUrl/train'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        print('[Prediction] Train returned ${response.statusCode}: ${response.body}');
        return false;
      }
      try {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (data['warning'] != null) {
            print('[Prediction] Train warning: ${data['warning']}');
            return false;
          }
          final training = data['training'];
          if (training is Map) {
            final trained = training['trained'] == true || training['queued'] == true;
            if (!trained) {
              return false;
            }
          }
        }
      } catch (_) {
        // Non-JSON response; treat as success.
      }
      return true;
    } catch (e) {
      print('[Prediction] Train error: $e');
      return false;
    }
  }

  Future<PredictionResult?> trainAndPredict(
    String messId, {
    String? slot,
    int daysBack = 30,
    int? minutesBack,
    int? capacity,
    bool asyncTrain = false,
    bool forceTrain = true,
  }) async {
    final trained = await trainModel(
      messId,
      slot: slot,
      daysBack: daysBack,
      minutesBack: minutesBack,
      capacity: capacity,
      asyncTrain: asyncTrain,
      forceTrain: forceTrain,
    );
    return getPrediction(
      messId,
      slot: slot,
      daysBack: daysBack,
      minutesBack: minutesBack,
      capacity: capacity,
      forceTrain: forceTrain,
      autoTrain: !trained,
      asyncTrain: asyncTrain,
    );
  }
}
