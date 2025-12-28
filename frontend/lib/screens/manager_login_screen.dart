import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/theme/app_tokens.dart';
import 'package:smart_mess/widgets/primary_action_button.dart';

class ManagerLoginScreen extends StatefulWidget {
  const ManagerLoginScreen({Key? key}) : super(key: key);

  @override
  State<ManagerLoginScreen> createState() => _ManagerLoginScreenState();
}

class _ManagerLoginScreenState extends State<ManagerLoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin(BuildContext context, UnifiedAuthProvider authProvider) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    authProvider.managerLogin(email, password).then((success) {
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
                      Icon(Icons.admin_panel_settings, size: 80, color: Colors.white),
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
                        'Manager Login',
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
                      // Email field
                      TextField(
                        controller: _emailController,
                        enabled: !authProvider.isLoading,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'manager@college.edu',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(height: 16),
                      // Password field
                      TextField(
                        controller: _passwordController,
                        enabled: !authProvider.isLoading,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        obscureText: !_isPasswordVisible,
                      ),
                      SizedBox(height: 32),
                      // Login button
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryActionButton(
                          label: 'Login as Manager',
                          onPressed: authProvider.isLoading
                              ? null
                              : () => _handleLogin(context, authProvider),
                          isLoading: authProvider.isLoading,
                        ),
                      ),
                      SizedBox(height: 24),
                      // Switch to student login
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/student_login'),
                        child: Text(
                          'Are you a student? Login here',
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

