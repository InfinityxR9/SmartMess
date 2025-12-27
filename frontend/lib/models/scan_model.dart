import 'package:cloud_firestore/cloud_firestore.dart';

class Scan {
  final String id;
  final String userId;
  final String messId;
  final DateTime timestamp;

  Scan({
    required this.id,
    required this.userId,
    required this.messId,
    required this.timestamp,
  });

  factory Scan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Scan(
      id: doc.id,
      userId: data['uid'] ?? '',
      messId: data['messId'] ?? '',
      timestamp: (data['ts'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': userId,
      'messId': messId,
      'ts': Timestamp.fromDate(timestamp),
    };
  }
}
