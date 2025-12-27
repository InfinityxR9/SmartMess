import 'package:flutter/foundation.dart';
import 'package:smart_mess/services/firestore_service.dart';
import 'package:smart_mess/models/rating_model.dart';

class RatingProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  RatingSummary? _ratingSummary;
  bool _isLoading = false;

  RatingSummary? get ratingSummary => _ratingSummary;
  bool get isLoading => _isLoading;

  void listenToRatingSummary(String messId) {
    _firestoreService.getRatingSummaryStream(messId).listen((summary) {
      _ratingSummary = summary;
      notifyListeners();
    });
  }

  Future<void> submitRating({
    required String userId,
    required String messId,
    required int score,
    String? comment,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final rating = Rating(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        messId: messId,
        score: score,
        timestamp: DateTime.now(),
        comment: comment,
      );

      await _firestoreService.submitRating(rating);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Handle error silently
      _isLoading = false;
      notifyListeners();
    }
  }
}
