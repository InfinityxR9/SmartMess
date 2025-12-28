import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:smart_mess/models/prediction_model.dart';
import 'package:smart_mess/utils/logger.dart';

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
    logDebug(
      '[Prediction] Backend URL is not configured for web hosting. '
      'Current page: ${pageUri.origin}, baseUrl: $baseUrl',
    );
  }

  Uri _buildEndpoint(String endpoint) {
    final normalizedEndpoint =
        endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    final baseUri = Uri.parse(baseUrl);
    if (baseUri.path.isEmpty || baseUri.path == '/') {
      return baseUri.replace(path: '/$normalizedEndpoint');
    }
    final path = baseUri.path.endsWith('/')
        ? '${baseUri.path}$normalizedEndpoint'
        : '${baseUri.path}/$normalizedEndpoint';
    return baseUri.replace(path: path);
  }

  String? _normalizeMealType(String? mealType) {
    if (mealType == null) return null;
    final normalized = mealType.trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  Future<PredictionResult?> getPrediction(
    String messId, {
    String? mealType,
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
      final normalizedMealType = _normalizeMealType(mealType);
      final payload = <String, dynamic>{
        'messId': messId,
      };
      if (normalizedMealType != null) {
        payload['mealType'] = normalizedMealType;
      }
      if (capacity != null && capacity > 0) {
        payload['capacity'] = capacity;
      }
      final response = await http.post(
        _buildEndpoint('predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PredictionResult.fromJson(data);
      } else {
        logError('[Prediction] Backend returned ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      logError('[Prediction] Error: $e');
      return null;
    }
  }

  @Deprecated('Backend no longer exposes /train. Use getPrediction instead.')
  Future<bool> trainModel(
    String messId, {
    String? mealType,
    int? capacity,
  }) async {
    if (messId.isEmpty) {
      return false;
    }
    if (_shouldSkipWebRequest()) {
      _logWebSkip();
      return false;
    }
    logDebug('[Prediction] /train is not supported by the current backend.');
    return false;
  }

  @Deprecated('Backend no longer exposes /train. Use getPrediction instead.')
  Future<PredictionResult?> trainAndPredict(
    String messId, {
    String? mealType,
    String? slot,
    int? capacity,
  }) async {
    return getPrediction(
      messId,
      mealType: mealType ?? slot,
      capacity: capacity,
    );
  }
}
