import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String id;
  final String userId;
  final String messId;
  final int score;
  final DateTime timestamp;
  final String? comment;

  Rating({
    required this.id,
    required this.userId,
    required this.messId,
    required this.score,
    required this.timestamp,
    this.comment,
  });

  factory Rating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Rating(
      id: doc.id,
      userId: data['uid'] ?? '',
      messId: data['messId'] ?? '',
      score: data['score'] ?? 0,
      timestamp: (data['ts'] as Timestamp).toDate(),
      comment: data['comment'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': userId,
      'messId': messId,
      'score': score,
      'ts': Timestamp.fromDate(timestamp),
      'comment': comment,
    };
  }
}

class RatingSummary {
  final String id;
  final String messId;
  final int count;
  final int sum;
  final double average;

  RatingSummary({
    required this.id,
    required this.messId,
    required this.count,
    required this.sum,
    required this.average,
  });

  factory RatingSummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RatingSummary(
      id: doc.id,
      messId: data['messId'] ?? '',
      count: data['count'] ?? 0,
      sum: data['sum'] ?? 0,
      average: (data['avg'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'messId': messId,
      'count': count,
      'sum': sum,
      'avg': average,
    };
  }
}
