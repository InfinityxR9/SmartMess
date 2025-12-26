import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_mess/services/firestore_service.dart';
import 'package:smart_mess/models/menu_model.dart';

class MenuScreen extends StatefulWidget {
  final String messId;
  const MenuScreen({Key? key, required this.messId}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late final FirestoreService _firestoreService = FirestoreService();
  late final Future<Map<String, dynamic>?> _fallbackMenu = _loadFallbackMenu();

  Future<Map<String, dynamic>?> _loadFallbackMenu() async {
    try {
      final raw = await rootBundle.loadString('assets/menu_data.json');
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Menu?>(
        stream: _firestoreService.getTodayMenuStream(widget.messId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return FutureBuilder<Map<String, dynamic>?>(
              future: _fallbackMenu,
              builder: (context, fallbackSnapshot) {
                if (fallbackSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final fallbackData = fallbackSnapshot.data;
                if (fallbackData == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No menu available for today'),
                      ],
                    ),
                  );
                }

                return _buildFallbackMenu(fallbackData);
              },
            );
          }

          final menu = snapshot.data!;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),
                Text(
                  'Today\'s Menu',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  _formatDate(menu.date),
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 20),
                ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: menu.items.length,
                  separatorBuilder: (_, __) => Divider(),
                  itemBuilder: (context, index) {
                    final item = menu.items[index];
                    return Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (item.description != null) ...[
                              SizedBox(height: 8),
                              Text(
                                item.description!,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  Widget _buildFallbackMenu(Map<String, dynamic> data) {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = days[now.weekday - 1];
    final dayMenu = (data['days'] as Map<String, dynamic>?)?[dayName] as Map<String, dynamic>?;

    if (dayMenu == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No menu available for today'),
          ],
        ),
      );
    }

    final note = data['note'] as String?;
    final meals = ['Breakfast', 'Lunch', 'Dinner'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Today\'s Menu',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            dayName,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ...meals.map((meal) {
            final items = (dayMenu[meal] as List?)?.cast<String>() ?? [];
            if (items.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...items.map(
                  (item) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }).toList(),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  note,
                  style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
