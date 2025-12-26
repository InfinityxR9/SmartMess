import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/screens/menu_screen.dart';
import 'package:smart_mess/screens/qr_scanner_screen.dart';
import 'package:smart_mess/screens/rating_screen.dart';
import 'package:smart_mess/screens/student_analytics_predictions_screen.dart';
import 'package:smart_mess/utils/meal_time.dart';
import 'package:smart_mess/widgets/reviews_tab.dart';

class StudentPortalTabsScreen extends StatefulWidget {
  const StudentPortalTabsScreen({Key? key}) : super(key: key);

  @override
  State<StudentPortalTabsScreen> createState() => _StudentPortalTabsScreenState();
}

class _StudentPortalTabsScreenState extends State<StudentPortalTabsScreen> {
  int _selectedIndex = 0;

  void _showStudentActions(BuildContext context, UnifiedAuthProvider authProvider) {
    final rootContext = context;
    showModalBottomSheet(
      context: rootContext,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Mark Attendance'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final slot = getCurrentMealSlot();
                  if (slot == null) {
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(
                        content: Text('Outside meal hours. Attendance can only be marked during meal times.'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(rootContext).push(
                    MaterialPageRoute(
                      builder: (_) => QRScannerScreen(mealType: slot.type),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Submit Review'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(rootContext).push(
                    MaterialPageRoute(builder: (_) => RatingScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: const Text('View Menu'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(rootContext).push(
                    MaterialPageRoute(builder: (_) => MenuScreen(messId: authProvider.messId ?? '')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  authProvider.logout();
                  Navigator.of(rootContext).pushReplacementNamed('/student_login');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBox({
    required IconData icon,
    required String title,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? color : Colors.black).withOpacity(isSelected ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UnifiedAuthProvider>();
    final messId = authProvider.messId ?? '';
    final messName = authProvider.messName ?? 'Mess';
    final managerName = authProvider.messManagerName ?? 'Not Assigned';
    final managerEmail = authProvider.messManagerEmail ?? '';
    final managerLine = managerEmail.isNotEmpty ? '$managerName - $managerEmail' : managerName;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$messName - Student Portal',
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Manager: $managerLine',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        toolbarHeight: 72,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showStudentActions(context, authProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildTabBox(
                  icon: Icons.insights,
                  title: 'Analysis + Prediction',
                  color: const Color(0xFF6200EE),
                  isSelected: _selectedIndex == 0,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  },
                ),
                _buildTabBox(
                  icon: Icons.rate_review,
                  title: 'Review',
                  color: const Color(0xFFFF6B6B),
                  isSelected: _selectedIndex == 1,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                StudentAnalyticsPredictionsScreen(
                  includeScaffold: false,
                  showReviews: false,
                ),
                ReviewsTab(messId: messId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
