import 'package:cloud_firestore/cloud_firestore.dart';

class Mess {
  final String id;
  final String name;
  final int capacity;
  final double latitude;
  final double longitude;
  final String? imageUrl;

  Mess({
    required this.id,
    required this.name,
    required this.capacity,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
  });

  factory Mess.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Mess(
      id: doc.id,
      name: data['name'] ?? '',
      capacity: data['capacity'] ?? 0,
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'capacity': capacity,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
    };
  }
}
