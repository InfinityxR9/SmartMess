import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const uuid = Uuid();

  /// Submit an anonymous review for a meal
  /// studentId is not stored in the review to keep it anonymous
  Future<bool> submitReview({
    required String messId,
    required String mealType,
    required int rating, // 1-5
    required String comment,
  }) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      await _firestore
          .collection('reviews')
          .doc(messId)
          .collection('meal_reviews')
          .add({
        'mealType': mealType,
        'rating': rating,
        'comment': comment,
        'date': dateStr,
        'submittedAt': today.toIso8601String(),
        'anonymous': true,
      });

      return true;
    } catch (e) {
      print('[Review] Error submitting review: $e');
      return false;
    }
  }

  /// Get all reviews for a specific meal in a mess
  Future<List<Map<String, dynamic>>> getMealReviews({
    required String messId,
    required String mealType,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .doc(messId)
          .collection('meal_reviews')
          .where('mealType', isEqualTo: mealType)
          .orderBy('submittedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('[Review] Error getting reviews: $e');
      return [];
    }
  }

  /// Get all reviews for a mess (all meals)
  Future<List<Map<String, dynamic>>> getMessReviews({
    required String messId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .doc(messId)
          .collection('meal_reviews')
          .orderBy('submittedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('[Review] Error getting mess reviews: $e');
      return [];
    }
  }

  /// Get average rating for a meal
  Future<double> getAverageRating({
    required String messId,
    required String mealType,
  }) async {
    try {
      final reviews = await getMealReviews(messId: messId, mealType: mealType);
      if (reviews.isEmpty) return 0.0;

      final totalRating = reviews.fold<int>(
        0,
        (sum, review) => sum + (review['rating'] as int? ?? 0),
      );

      return totalRating / reviews.length;
    } catch (e) {
      print('[Review] Error calculating average rating: $e');
      return 0.0;
    }
  }

  /// Get review count for a meal
  Future<int> getReviewCount({
    required String messId,
    required String mealType,
  }) async {
    try {
      final reviews = await getMealReviews(messId: messId, mealType: mealType);
      return reviews.length;
    } catch (e) {
      return 0;
    }
  }
}
