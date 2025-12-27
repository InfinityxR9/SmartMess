import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItem {
  final String name;
  final String? description;

  MenuItem({
    required this.name,
    this.description,
  });

  factory MenuItem.fromMap(Map<String, dynamic> data) {
    return MenuItem(
      name: data['name'] ?? '',
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
    };
  }
}

class Menu {
  final String id;
  final String messId;
  final DateTime date;
  final List<MenuItem> items;

  Menu({
    required this.id,
    required this.messId,
    required this.date,
    required this.items,
  });

  factory Menu.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final itemsList = (data['items'] as List<dynamic>?)
        ?.map((item) => MenuItem.fromMap(item as Map<String, dynamic>))
        .toList() ?? [];

    return Menu(
      id: doc.id,
      messId: data['messId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      items: itemsList,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'messId': messId,
      'date': Timestamp.fromDate(date),
      'items': items.map((item) => item.toMap()).toList(),
    };
  }
}
