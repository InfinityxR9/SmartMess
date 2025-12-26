import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/screens/qr_scanner_screen.dart';
import 'package:smart_mess/screens/qr_generator_screen.dart';
import 'package:smart_mess/screens/manual_attendance_screen.dart';
import 'package:smart_mess/screens/menu_creation_screen.dart';
import 'package:smart_mess/screens/menu_screen.dart';
import 'package:smart_mess/screens/analytics_screen.dart';
import 'package:smart_mess/screens/analytics_enhanced_screen.dart';
import 'package:smart_mess/screens/student_analytics_predictions_screen.dart';
import 'package:smart_mess/screens/rating_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<UnifiedAuthProvider>(
      builder: (context, authProvider, _) {
        // Show error if authentication failed
        if (authProvider.error != null) {
          return Scaffold(
            appBar: AppBar(title: Text('Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error'),
                  SizedBox(height: 8),
                  Text(
                    authProvider.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/student_login');
                    },
                    child: Text('Back to Login'),
                  ),
                ],
              ),
            ),
          );
        }

        // Show loading state
        if (authProvider.isLoading) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        // Show authenticated home screen
        if (authProvider.isAuthenticated) {
          return Scaffold(
            appBar: AppBar(
              title: Text('${authProvider.messName ?? "Mess"} - SmartMess'),
              elevation: 0,
            ),
            body: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User info card
                    Card(
                      elevation: 2,
                      child: Container(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  authProvider.isStudent
                                      ? Icons.person
                                      : Icons.admin_panel_settings,
                                  size: 40,
                                  color: Color(0xFF6200EE),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        authProvider.userName ?? 'User',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        authProvider.isStudent ? 'Student' : 'Manager',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (authProvider.isStudent)
                                        Text(
                                          'ID: ${authProvider.enrollmentId}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Mess info card
                    Card(
                      elevation: 2,
                      child: Container(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mess Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.restaurant, color: Color(0xFF6200EE)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mess Name',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        authProvider.messName ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.code, color: Color(0xFF6200EE)),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mess Code',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        authProvider.messCode ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Quick Actions
                    if (authProvider.isStudent) ...[
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _buildActionCard(
                            icon: Icons.qr_code_scanner,
                            title: 'Mark Attendance',
                            color: Color(0xFF6200EE),
                            onTap: () {
                              _showMealSelector(context, (mealType) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => QRScannerScreen(
                                      mealType: mealType,
                                    ),
                                  ),
                                );
                              });
                            },
                          ),
                          _buildActionCard(
                            icon: Icons.star,
                            title: 'Submit Review',
                            color: Color(0xFFFF6B6B),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => RatingScreen(),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            icon: Icons.restaurant_menu,
                            title: 'View Menu',
                            color: Color(0xFF03DAC6),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MenuScreen(messId: authProvider.messId ?? ''),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            icon: Icons.bar_chart,
                            title: 'Analytics & Predictions',
                            color: Color(0xFF9C27B0),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => StudentAnalyticsPredictionsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Manager Actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _buildActionCard(
                            icon: Icons.qr_code,
                            title: 'Generate QR',
                            color: Color(0xFF6200EE),
                            onTap: () {
                              _showMealSelector(context, (mealType) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => QRGeneratorScreen(
                                      mealType: mealType,
                                    ),
                                  ),
                                );
                              });
                            },
                          ),
                          _buildActionCard(
                            icon: Icons.checklist,
                            title: 'Mark Attendance',
                            color: Color(0xFFFF6B6B),
                            onTap: () {
                              _showMealSelector(context, (mealType) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ManualAttendanceScreen(mealType: mealType),
                                  ),
                                );
                              });
                            },
                          ),
                          _buildActionCard(
                            icon: Icons.menu_book,
                            title: 'Create Menu',
                            color: Color(0xFF03DAC6),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MenuCreationScreen(),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            icon: Icons.bar_chart,
                            title: 'Analytics',
                            color: Color(0xFFFFC107),
                            onTap: () {
                              final authProvider =
                                  context.read<UnifiedAuthProvider>();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => AnalyticsEnhancedScreen(
                                    messId: authProvider.messId ?? '',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 24),

                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          authProvider.logout();
                          Navigator.of(context)
                              .pushReplacementNamed('/student_login');
                        },
                        icon: Icon(Icons.logout),
                        label: Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Not authenticated
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Please login to continue'),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/student_login');
                  },
                  child: Text('Go to Login'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMealSelector(BuildContext context, Function(String) onMealSelected) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Meal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.breakfast_dining, color: Color(0xFF6200EE)),
              title: Text('Breakfast'),
              onTap: () {
                Navigator.pop(context);
                onMealSelected('breakfast');
              },
            ),
            ListTile(
              leading: Icon(Icons.lunch_dining, color: Color(0xFF6200EE)),
              title: Text('Lunch'),
              onTap: () {
                Navigator.pop(context);
                onMealSelected('lunch');
              },
            ),
            ListTile(
              leading: Icon(Icons.dinner_dining, color: Color(0xFF6200EE)),
              title: Text('Dinner'),
              onTap: () {
                Navigator.pop(context);
                onMealSelected('dinner');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

