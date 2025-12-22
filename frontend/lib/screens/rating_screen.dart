import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/services/review_service.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({Key? key}) : super(key: key);

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _commentController = TextEditingController();

  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner'];
  String _selectedMeal = 'lunch';
  double _rating = 3.0;
  bool _isSubmitting = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitReview() async {
    if (_commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your feedback')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final authProvider = context.read<UnifiedAuthProvider>();

    try {
      final success = await _reviewService.submitReview(
        messId: authProvider.messId ?? '',
        mealType: _selectedMeal,
        rating: _rating.toInt(),
        comment: _commentController.text,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          if (success) {
            _message = '✓ Thank you for your feedback!';
            _isSuccess = true;
            _commentController.clear();
            _rating = 3.0;

            Future.delayed(Duration(seconds: 2), () {
              if (mounted) {
                setState(() => _message = null);
              }
            });
          } else {
            _message = 'Error submitting feedback. Please try again.';
            _isSuccess = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _message = 'Error: ${e.toString()}';
          _isSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share Your Feedback'),
        elevation: 0,
        backgroundColor: Color(0xFF6200EE),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.feedback, size: 48, color: Color(0xFF6200EE)),
                      SizedBox(height: 12),
                      Text(
                        'Your feedback is anonymous',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6200EE),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Help us improve meals and services',
                        textAlign: TextAlign.center,
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
              Text(
                'Select Meal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButton<String>(
                    value: _selectedMeal,
                    isExpanded: true,
                    underline: SizedBox(),
                    items: _mealTypes
                        .map((meal) => DropdownMenuItem(
                              value: meal,
                              child: Text(meal.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMeal = value);
                      }
                    },
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Rate this meal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rating:', style: TextStyle(fontSize: 14)),
                        Text(
                          '${_rating.toInt()} / 5',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6200EE),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Slider(
                      value: _rating,
                      onChanged: (value) {
                        setState(() => _rating = value);
                      },
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '${_rating.toInt()}',
                      activeColor: Color(0xFF6200EE),
                      inactiveColor: Colors.grey[300],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Your Feedback',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _commentController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Share your thoughts...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
              SizedBox(height: 24),
              if (_message != null)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    border: Border.all(color: _isSuccess ? Colors.green : Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(_isSuccess ? Icons.check_circle : Icons.error,
                          color: _isSuccess ? Colors.green : Colors.red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(_message!,
                            style: TextStyle(
                              color: _isSuccess ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6200EE),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Submit Feedback',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
