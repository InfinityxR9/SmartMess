import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/theme/app_tokens.dart';
import 'package:smart_mess/widgets/primary_action_button.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({Key? key}) : super(key: key);

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  late TextEditingController _enrollmentController;
  late TextEditingController _dobController;

  @override
  void initState() {
    super.initState();
    _enrollmentController = TextEditingController();
    _dobController = TextEditingController();
  }

  @override
  void dispose() {
    _enrollmentController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
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
      _dobController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  void _handleLogin(BuildContext context, UnifiedAuthProvider authProvider) {
    final enrollmentId = _enrollmentController.text.trim();
    final dob = _dobController.text.trim();

    if (enrollmentId.isEmpty || dob.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    authProvider.studentLogin(enrollmentId, dob).then((success) {
      if (success) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UnifiedAuthProvider>(
      builder: (context, authProvider, _) {
        return Scaffold(
          body: SingleChildScrollView(
            child: Container(
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant, size: 80, color: Colors.white),
                      SizedBox(height: 24),
                      Text(
                        'SmartMess',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Student Login',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 48),
                      // Error message
                      if (authProvider.error != null)
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.danger),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  authProvider.error!,
                                  style: const TextStyle(color: AppColors.danger),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (authProvider.error != null) SizedBox(height: 16),
                      // Enrollment ID field
                      TextField(
                        controller: _enrollmentController,
                        enabled: !authProvider.isLoading,
                        decoration: InputDecoration(
                          labelText: 'Enrollment ID',
                          hintText: 'e.g., OAK_E123456',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      SizedBox(height: 16),
                      // DOB field
                      GestureDetector(
                        onTap: authProvider.isLoading
                            ? null
                            : () => _selectDate(context),
                        child: TextField(
                          controller: _dobController,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Date of Birth',
                            hintText: 'DD/MM/YYYY',
                            prefixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 32),
                      // Login button
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryActionButton(
                          label: 'Login as Student',
                          onPressed: authProvider.isLoading
                              ? null
                              : () => _handleLogin(context, authProvider),
                          isLoading: authProvider.isLoading,
                        ),
                      ),
                      SizedBox(height: 24),
                      // Switch to manager login
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/manager_login'),
                        child: Text(
                          'Are you a manager? Login here',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

