import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const uuid = Uuid();
  static const String _apiBaseUrl = 'http://localhost:8080'; // Backend API endpoint

  /// Get exact meal type based on current time
  String _getMealType() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    
    // Breakfast: 7:30-9:30, Lunch: 12:00-14:00, Dinner: 19:30-21:30 (exclusive end)
    if ((hour == 7 && minute >= 30) || (hour > 7 && hour < 9) || (hour == 9 && minute < 30)) {
      return 'breakfast';
    } else if (hour == 12 || hour == 13 || (hour == 14 && minute == 0)) {
      return 'lunch';
    } else if ((hour == 19 && minute >= 30) || (hour > 19 && hour < 21) || (hour == 21 && minute < 30)) {
      return 'dinner';
    }
    return ''; // Outside meal hours
  }

  /// Submit a review for the current meal slot only
  /// Reviews submitted during breakfast are only visible at breakfast, etc.
  Future<bool> submitReview({
    required String messId,
    required String mealType,
    required int rating,
    required String comment,
    String? studentId,
    String? studentName,
  }) async {
    try {
      // Get current meal type
      final currentMealType = _getMealType();
      if (currentMealType.isEmpty) {
        throw 'Outside meal hours';
      }
      
      // Reviews can only be submitted for current meal slot
      if (mealType != currentMealType) {
        throw 'Can only submit review for $currentMealType, not $mealType';
      }

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Use backend API to submit review
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/reviews?messId=$messId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messId': messId,
          'mealType': mealType,
          'rating': rating,
          'comment': comment,
          'studentId': studentId,
          'studentName': studentName ?? 'Anonymous',
          'submittedAt': now.toIso8601String(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        print('[Review] Backend error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[Review] Error submitting review: $e');
      
      // Fallback to Firestore if backend not available
      try {
        final now = DateTime.now();
        final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final mealTypeToUse = _getMealType();
        
        if (mealTypeToUse.isEmpty) return false;

        await _firestore
            .collection('reviews')
            .doc(messId)
            .collection(dateStr)
            .doc(mealTypeToUse)
            .collection('items')
            .add({
          'rating': rating,
          'comment': comment,
          'studentId': studentId,
          'studentName': studentName ?? 'Anonymous',
          'submittedAt': now.toIso8601String(),
          'meal': mealTypeToUse,
          'date': dateStr,
        });
        
        return true;
      } catch (fallbackError) {
        print('[Review] Fallback error: $fallbackError');
        return false;
      }
    }
  }

  /// Get reviews for current meal slot ONLY
  /// Reviews from other meal slots are not returned
  Future<List<Map<String, dynamic>>> getMealReviews({
    required String messId,
    required String mealType,
  }) async {
    try {
      // Check if currently in the correct meal slot
      final currentMealType = _getMealType();
      if (currentMealType.isEmpty || currentMealType != mealType) {
        return []; // Don't show reviews outside their meal slot
      }

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Try backend API first
      try {
        final response = await http.get(
          Uri.parse('$_apiBaseUrl/reviews?messId=$messId'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final reviews = (data['reviews'] as List<dynamic>?)
              ?.map((r) => Map<String, dynamic>.from(r as Map))
              .toList() ?? [];
          return reviews;
        }
      } catch (e) {
        print('[Review] Backend error: $e');
        // Fall through to Firestore fallback
      }

      // Fallback to Firestore
      final snapshot = await _firestore
          .collection('reviews')
          .doc(messId)
          .collection(dateStr)
          .doc(mealType)
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

  /// Get all reviews for a mess (all meals) - Deprecated: Use getMealReviews instead
  Future<List<Map<String, dynamic>>> getMessReviews({
    required String messId,
  }) async {
    try {
      // Only show reviews from current meal slot
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

  /// Get average rating for a meal (current slot only)
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

  /// Get review count for a meal (current slot only)
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
