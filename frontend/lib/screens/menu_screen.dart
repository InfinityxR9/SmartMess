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

  List<String> _splitMenuText(String text) {
    return text
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _dayNameFor(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  Widget _buildMealCard({
    required String title,
    required IconData icon,
    required List<String> items,
    required Color accent,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((item) => Chip(
                      label: Text(item),
                      backgroundColor: Colors.white,
                      shape: StadiumBorder(
                        side: BorderSide(color: accent.withValues(alpha: 0.2)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuContent({
    required String dayLabel,
    required List<String> breakfastItems,
    required List<String> lunchItems,
    required List<String> dinnerItems,
    String? note,
  }) {
    final hasAny = breakfastItems.isNotEmpty || lunchItems.isNotEmpty || dinnerItems.isNotEmpty;

    if (!hasAny) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No menu available for today'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6200EE), Color(0xFF03DAC6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant_menu, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dayLabel,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildMealCard(
            title: 'Breakfast',
            icon: Icons.breakfast_dining,
            items: breakfastItems,
            accent: const Color(0xFFF9A825),
          ),
          _buildMealCard(
            title: 'Lunch',
            icon: Icons.lunch_dining,
            items: lunchItems,
            accent: const Color(0xFF2E7D32),
          ),
          _buildMealCard(
            title: 'Dinner',
            icon: Icons.dinner_dining,
            items: dinnerItems,
            accent: const Color(0xFF1565C0),
          ),
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

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dayLabel = _dayNameFor(today);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Menu'),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fallbackMenu,
        builder: (context, fallbackSnapshot) {
          return StreamBuilder<Menu?>(
            stream: _firestoreService.getTodayMenuStream(widget.messId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  fallbackSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final fallbackData = fallbackSnapshot.data;
              final fallbackDays = fallbackData?['days'] as Map<String, dynamic>?;
              final fallbackDayMenu = fallbackDays?[dayLabel] as Map<String, dynamic>?;
              final note = fallbackData?['note'] as String?;

              final fallbackBreakfast =
                  (fallbackDayMenu?['Breakfast'] as List?)?.cast<String>() ?? [];
              final fallbackLunch =
                  (fallbackDayMenu?['Lunch'] as List?)?.cast<String>() ?? [];
              final fallbackDinner =
                  (fallbackDayMenu?['Dinner'] as List?)?.cast<String>() ?? [];

              final menu = snapshot.data;
              String? overrideBreakfast;
              String? overrideLunch;
              String? overrideDinner;

              if (menu != null) {
                for (final item in menu.items) {
                  if (item.name == 'Breakfast') {
                    overrideBreakfast = item.description;
                  } else if (item.name == 'Lunch') {
                    overrideLunch = item.description;
                  } else if (item.name == 'Dinner') {
                    overrideDinner = item.description;
                  }
                }
              }

              final breakfastOverride = overrideBreakfast;
              final lunchOverride = overrideLunch;
              final dinnerOverride = overrideDinner;
              final breakfastItems = (breakfastOverride != null && breakfastOverride.isNotEmpty)
                  ? _splitMenuText(breakfastOverride)
                  : fallbackBreakfast;
              final lunchItems = (lunchOverride != null && lunchOverride.isNotEmpty)
                  ? _splitMenuText(lunchOverride)
                  : fallbackLunch;
              final dinnerItems = (dinnerOverride != null && dinnerOverride.isNotEmpty)
                  ? _splitMenuText(dinnerOverride)
                  : fallbackDinner;

              return _buildMenuContent(
                dayLabel: dayLabel,
                breakfastItems: breakfastItems,
                lunchItems: lunchItems,
                dinnerItems: dinnerItems,
                note: note,
              );
            },
          );
        },
      ),
    );
  }
}
