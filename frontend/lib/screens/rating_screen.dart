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

  double _rating = 3.0;
  bool _isSubmitting = false;
  String? _message;
  bool _isSuccess = false;
  String? _currentMealType;
  String? _timeWindow;

  @override
  void initState() {
    super.initState();
    _updateMealType();
  }

  void _updateMealType() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    
    String? meal;
    String? window;
    
    if ((hour == 7 && minute >= 30) || (hour > 7 && hour < 9) || (hour == 9 && minute < 30)) {
      meal = 'breakfast';
      window = 'Breakfast (7:30-9:30)';
    } else if (hour == 12 || hour == 13 || (hour == 14 && minute == 0)) {
      meal = 'lunch';
      window = 'Lunch (12:00-14:00)';
    } else if ((hour == 19 && minute >= 30) || (hour > 19 && hour < 21) || (hour == 21 && minute < 30)) {
      meal = 'dinner';
      window = 'Dinner (19:30-21:30)';
    }
    
    setState(() {
      _currentMealType = meal;
      _timeWindow = window;
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitReview() async {
    if (_commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback')),
      );
      return;
    }

    if (_currentMealType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reviews can only be submitted during meal times')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final authProvider = context.read<UnifiedAuthProvider>();

    try {
      final success = await _reviewService.submitReview(
        messId: authProvider.messId ?? '',
        mealType: _currentMealType!,
        rating: _rating.toInt(),
        comment: _commentController.text,
        studentId: authProvider.userId,
        studentName: authProvider.userName,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          if (success) {
            _message = ' Thank you for your feedback!';
            _isSuccess = true;
            _commentController.clear();
            _rating = 3.0;

            Future.delayed(const Duration(seconds: 2), () {
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
          _message = 'Error: \';
          _isSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _currentMealType != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Your Feedback'),
        elevation: 0,
        backgroundColor: const Color(0xFF6200EE),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                color: canSubmit ? Colors.green.shade50 : Colors.orange.shade50,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        canSubmit ? Icons.check_circle : Icons.access_time,
                        size: 48,
                        color: canSubmit ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        canSubmit ? 'You can submit now' : 'Outside meal hours',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: canSubmit ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        canSubmit
                            ? 'Submitting feedback for \'
                            : 'Reviews can only be submitted during meal times:\nBreakfast (7:30-9:30)\nLunch (12:00-14:00)\nDinner (19:30-21:30)',
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
              const SizedBox(height: 24),
              Text(
                'Meal: \',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Card(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rating',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() => _rating = (index + 1).toDouble());
                            },
                            child: Icon(
                              Icons.star,
                              size: 40,
                              color: index < _rating.toInt() ? Colors.amber : Colors.grey[300],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          '\ / 5',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Feedback',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _commentController,
                        minLines: 4,
                        maxLines: 6,
                        enabled: canSubmit,
                        decoration: InputDecoration(
                          hintText: 'Share your feedback about the meal...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_message != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    border: Border.all(
                      color: _isSuccess ? Colors.green : Colors.red,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _isSuccess ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSubmit && !_isSubmitting ? _submitReview : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6200EE),
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          canSubmit ? 'Submit Feedback' : 'Not Available Now',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
