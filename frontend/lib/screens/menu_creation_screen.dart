import 'package:flutter/material.dart';
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
  final TextEditingController _breakfastController = TextEditingController();
  final TextEditingController _lunchController = TextEditingController();
  final TextEditingController _dinnerController = TextEditingController();

  bool _isSaving = false;
  String? _message;
  bool _isSuccess = false;

  void _saveMenu() async {
    if (_breakfastController.text.isEmpty &&
        _lunchController.text.isEmpty &&
        _dinnerController.text.isEmpty) {
      setState(() {
        _message = 'Please enter at least one meal';
        _isSuccess = false;
      });
      return;
    }

    setState(() => _isSaving = true);

    final authProvider = context.read<UnifiedAuthProvider>();
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    try {
      final menuData = {
        'date': dateStr,
        'breakfast': _breakfastController.text,
        'lunch': _lunchController.text,
        'dinner': _dinnerController.text,
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': authProvider.userId,
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
          _message = '✓ Menu saved successfully';
          _isSuccess = true;
          _isSaving = false;
        });

        _breakfastController.clear();
        _lunchController.clear();
        _dinnerController.clear();

        // Close after 2 seconds
        Future.delayed(Duration(seconds: 2), () {
          Navigator.pop(context);
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

  @override
  void dispose() {
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Today\'s Menu'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Card(
                elevation: 2,
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Menu Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Enter the dishes for each meal today.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Breakfast
              _buildMealInput(
                icon: Icons.breakfast_dining,
                label: 'Breakfast',
                controller: _breakfastController,
                hint: 'e.g., Idli, Sambar, Chutney',
              ),
              SizedBox(height: 16),

              // Lunch
              _buildMealInput(
                icon: Icons.lunch_dining,
                label: 'Lunch',
                controller: _lunchController,
                hint: 'e.g., Biryani, Raita, Pickle',
              ),
              SizedBox(height: 16),

              // Dinner
              _buildMealInput(
                icon: Icons.dinner_dining,
                label: 'Dinner',
                controller: _dinnerController,
                hint: 'e.g., Roti, Dal, Vegetables',
              ),
              SizedBox(height: 24),

              // Message
              if (_message != null)
                Container(
                  padding: EdgeInsets.all(16),
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
                      SizedBox(width: 12),
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

              if (_message != null) SizedBox(height: 24),

              // Save button
              ElevatedButton.icon(
                icon: Icon(Icons.save),
                label: Text('Save Menu'),
                onPressed: _isSaving ? null : _saveMenu,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Color(0xFF6200EE),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealInput({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Color(0xFF6200EE), size: 24),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}
