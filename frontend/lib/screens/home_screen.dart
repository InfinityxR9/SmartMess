import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/screens/qr_scanner_screen.dart';
import 'package:smart_mess/screens/qr_generator_screen.dart';
import 'package:smart_mess/screens/manual_attendance_screen.dart';
import 'package:smart_mess/screens/menu_creation_screen.dart';
import 'package:smart_mess/screens/menu_screen.dart';
import 'package:smart_mess/screens/manager_portal_tabs_screen.dart';
import 'package:smart_mess/screens/rating_screen.dart';
import 'package:smart_mess/screens/student_portal_tabs_screen.dart';
import 'package:smart_mess/utils/meal_time.dart';
import 'package:smart_mess/theme/app_tokens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
                  const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                  SizedBox(height: 16),
                  Text('Error'),
                  SizedBox(height: 8),
                  Text(
                    authProvider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger, fontSize: 14),
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
              controller: _scrollController,
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
                                  color: AppColors.primary,
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
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                      if (authProvider.isStudent)
                                        Text(
                                          'ID: ${authProvider.enrollmentId}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.inkMuted,
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
                                Icon(Icons.restaurant, color: AppColors.primary),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mess Name',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.inkMuted,
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
                                Icon(Icons.code, color: AppColors.primary),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mess Code',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.inkMuted,
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
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.badge, color: AppColors.primary),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Manager Name',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                      Text(
                                        authProvider.messManagerName ?? 'N/A',
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
                                Icon(Icons.email, color: AppColors.primary),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Manager Email',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.inkMuted,
                                        ),
                                      ),
                                      Text(
                                        authProvider.messManagerEmail ?? 'N/A',
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
                            color: AppColors.primary,
                            onTap: () {
                              final slot = getCurrentMealSlot();
                              if (slot == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Outside meal hours. Attendance can only be marked during meal times.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => QRScannerScreen(
                                    mealType: slot.type,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            icon: Icons.star,
                            title: 'Submit Review',
                            color: AppColors.danger,
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
                            color: AppColors.accent,
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
                            color: AppColors.primary,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const StudentPortalTabsScreen(
                                    initialIndex: 1,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'Manager Insights',
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
                            icon: Icons.show_chart,
                            title: 'Prediction + Analysis',
                            color: AppColors.primary,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ManagerPredictionAnalysisScreen(
                                    messId: authProvider.messId ?? '',
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            icon: Icons.qr_code,
                            title: 'Generate QR',
                            color: AppColors.primary,
                            onTap: () {
                              final slot = getCurrentMealSlot();
                              if (slot == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Outside meal hours. QR can only be generated during meal times.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => QRGeneratorScreen(
                                    mealType: slot.type,
                                  ),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            icon: Icons.checklist,
                            title: 'Mark Attendance',
                            color: AppColors.danger,
                            onTap: () {
                              final slot = getCurrentMealSlot();
                              if (slot == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Outside meal hours. Attendance can only be marked during meal times.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ManualAttendanceScreen(mealType: slot.type),
                                ),
                              );
                            },
                          ),
                          _buildActionCard(
                            icon: Icons.menu_book,
                            title: 'Create Menu',
                            color: AppColors.accent,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MenuCreationScreen(),
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
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
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
                Icon(Icons.login, size: 64, color: AppColors.inkMuted),
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
          border: Border.all(color: color.withOpacity(0.3)),
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

