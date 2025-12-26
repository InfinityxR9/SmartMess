import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _getMealType() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    
    if ((hour == 7 && minute >= 30) || (hour > 7 && hour < 9) || (hour == 9 && minute < 30)) {
      return 'breakfast';
    } else if (hour == 12 || hour == 13 || (hour == 14 && minute == 0)) {
      return 'lunch';
    } else if ((hour == 19 && minute >= 30) || (hour > 19 && hour < 21) || (hour == 21 && minute < 30)) {
      return 'dinner';
    }
    return '';
  }

  Future<bool> submitReview({
    required String messId,
    required String mealType,
    required int rating,
    required String comment,
    String? studentId,
    String? studentName,
  }) async {
    try {
      final currentMealType = _getMealType();
      final normalizedMealType = mealType.trim().toLowerCase();
      if (currentMealType.isEmpty) {
        throw 'Outside meal hours - reviews only during meal time';
      }
      
      if (normalizedMealType != currentMealType) {
        throw 'Can only submit $currentMealType reviews during $currentMealType hours';
      }

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await _firestore
          .collection('reviews')
          .doc(messId)
          .collection(dateStr)
          .doc(normalizedMealType)
          .collection('items')
          .add({
        'rating': rating,
        'comment': comment,
        'studentId': studentId,
        'studentName': studentName ?? 'Anonymous',
        'submittedAt': now.toIso8601String(),
        'slot': normalizedMealType,
        'date': dateStr,
        'messId': messId
      });
      
      print('[Review] Submitted successfully for $messId $dateStr $normalizedMealType');
      return true;
    } catch (e) {
      print('[Review] Error submitting review: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMealReviews({
    required String messId,
    required String mealType,
  }) async {
    try {
      final normalizedMealType = mealType.trim().toLowerCase();
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final snapshot = await _firestore
          .collection('reviews')
          .doc(messId)
          .collection(dateStr)
          .doc(normalizedMealType)
          .collection('items')
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data()})
          .toList();
          
    } catch (e) {
      print('[Review] Error getting reviews: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMessReviews({
    required String messId,
  }) async {
    try {
      final currentMealType = _getMealType();
      if (currentMealType.isEmpty) {
        return [];
      }
      
      return await getMealReviews(messId: messId, mealType: currentMealType);
    } catch (e) {
      print('[Review] Error getting mess reviews: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReviewsForDateAndSlot({
    required String messId,
    required String date,
    required String slot,
  }) async {
    try {
      final normalizedSlot = slot.trim().toLowerCase();
      final snapshot = await _firestore
          .collection('reviews')
          .doc(messId)
          .collection(date)
          .doc(normalizedSlot)
          .collection('items')
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data()})
          .toList();
    } catch (e) {
      print('[Review] Error getting reviews for $date/$slot: $e');
      return [];
    }
  }

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
