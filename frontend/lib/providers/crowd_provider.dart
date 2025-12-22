import 'package:flutter/foundation.dart';
import 'package:smart_mess/services/firestore_service.dart';

class CrowdProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  int _crowdCount = 0;
  bool _isLoading = false;

  int get crowdCount => _crowdCount;
  bool get isLoading => _isLoading;

  double getCrowdPercentage(int capacity) {
    if (capacity == 0) return 0.0;
    return (_crowdCount / capacity).clamp(0.0, 1.0);
  }

  String getCrowdLevel(int capacity) {
    final percentage = getCrowdPercentage(capacity);
    if (percentage < 0.3) return 'Low';
    if (percentage < 0.6) return 'Medium';
    return 'High';
  }

  void listenToCrowdCount(String messId) {
    _firestoreService.getCrowdCountStream(messId).listen((count) {
      _crowdCount = count;
      notifyListeners();
    });
  }

  Future<void> logScan(String userId, String messId) async {
    try {
      await _firestoreService.logScan(userId, messId);
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }
}
