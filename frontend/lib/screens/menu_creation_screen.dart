import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';

class MenuCreationScreen extends StatefulWidget {
  const MenuCreationScreen({Key? key}) : super(key: key);

  @override
  State<MenuCreationScreen> createState() => _MenuCreationScreenState();
}

class _MenuCreationScreenState extends State<MenuCreationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _menuController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedMeal = 'breakfast';
  Map<String, dynamic>? _standardMenu;

  bool _isSaving = false;
  bool _isLoadingMenu = true;
  String? _message;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadStandardMenu();
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  Future<void> _loadStandardMenu() async {
    try {
      final raw = await rootBundle.loadString('assets/menu_data.json');
      _standardMenu = jsonDecode(raw) as Map<String, dynamic>?;
    } catch (e) {
      _standardMenu = null;
    } finally {
      if (mounted) {
        setState(() => _isLoadingMenu = false);
      }
      await _loadCurrentMenuText();
    }
  }

  String _dayNameFor(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  String _mealLabel(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return mealType;
    }
  }

  List<String> _standardItemsFor(DateTime date, String mealType) {
    final dayName = _dayNameFor(date);
    final daysMap = _standardMenu?['days'] as Map<String, dynamic>?;
    final dayMenu = daysMap?[dayName] as Map<String, dynamic>?;
    final mealLabel = _mealLabel(mealType);
    final items = (dayMenu?[mealLabel] as List?)?.cast<String>() ?? [];
    return items;
  }

  String _standardMenuText() {
    final items = _standardItemsFor(_selectedDate, _selectedMeal);
    return items.join(', ');
  }

  Future<void> _loadCurrentMenuText() async {
    final authProvider = context.read<UnifiedAuthProvider>();
    final messId = authProvider.messId ?? '';
    if (messId.isEmpty) {
      return;
    }

    final dateStr = _formatDate(_selectedDate);
    try {
      final doc = await _firestore
          .collection('menus')
          .doc(messId)
          .collection('daily')
          .doc(dateStr)
          .get();

      final data = doc.data();
      final override = data?[ _selectedMeal ] as String?;
      final standard = _standardMenuText();
      if (mounted) {
        _menuController.text = (override != null && override.isNotEmpty) ? override : standard;
      }
    } catch (e) {
      if (mounted) {
        _menuController.text = _standardMenuText();
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('en', 'GB'),
      builder: (context, child) {
        return Localizations.override(
          context: context,
          locale: const Locale('en', 'GB'),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadCurrentMenuText();
    }
  }

  Future<void> _saveMenu() async {
    if (_menuController.text.trim().isEmpty) {
      setState(() {
        _message = 'Please enter a menu update';
        _isSuccess = false;
      });
      return;
    }

    setState(() => _isSaving = true);

    final authProvider = context.read<UnifiedAuthProvider>();
    final dateStr = _formatDate(_selectedDate);

    try {
      final menuData = {
        _selectedMeal: _menuController.text.trim(),
        'date': dateStr,
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': authProvider.userId,
        'messId': authProvider.messId,
      };

      await _firestore
          .collection('menus')
          .doc(authProvider.messId)
          .collection('daily')
          .doc(dateStr)
          .set(menuData, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _message = 'Menu saved successfully';
          _isSuccess = true;
          _isSaving = false;
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Error: ${e.toString()}';
          _isSuccess = false;
          _isSaving = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatReadableDate(DateTime date) {
    final dayName = _dayNameFor(date);
    return '$dayName, ${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final mealLabel = _mealLabel(_selectedMeal);
    final standardItems = _standardItemsFor(_selectedDate, _selectedMeal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Menu'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Standard Menu',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Update a single meal for a specific day. Other meals stay unchanged.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 1,
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Color(0xFF6200EE)),
                  title: const Text('Select Date'),
                  subtitle: Text(_formatReadableDate(_selectedDate)),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Meal Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMeal,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
                      DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                      DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _selectedMeal = value);
                      await _loadCurrentMenuText();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _menuController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '$mealLabel Menu',
                  hintText: 'Edit the standard menu items',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Standard $mealLabel (${_dayNameFor(_selectedDate)})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingMenu)
                        const Text('Loading standard menu...')
                      else if (standardItems.isEmpty)
                        const Text('Standard menu not available for this day.')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: standardItems
                              .map((item) => Chip(
                                    label: Text(item),
                                    backgroundColor: Colors.white,
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_message != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSuccess ? Colors.green.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.error_outline,
                        color: _isSuccess ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _isSuccess
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_message != null) const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Menu Update'),
                onPressed: _isSaving ? null : _saveMenu,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: const Color(0xFF6200EE),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
