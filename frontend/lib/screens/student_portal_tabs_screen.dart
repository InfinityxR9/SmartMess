import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/screens/menu_screen.dart';
import 'package:smart_mess/screens/qr_scanner_screen.dart';
import 'package:smart_mess/screens/rating_screen.dart';
import 'package:smart_mess/screens/student_analytics_predictions_screen.dart';
import 'package:smart_mess/utils/meal_time.dart';
import 'package:smart_mess/widgets/reviews_tab.dart';

class StudentPortalTabsScreen extends StatelessWidget {
  final int initialIndex;

  const StudentPortalTabsScreen({
    Key? key,
    this.initialIndex = 1,
  }) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<UnifiedAuthProvider>();
    final messId = authProvider.messId ?? '';
    final messName = authProvider.messName ?? 'Mess';
    final tabIndex = initialIndex < 0 ? 0 : initialIndex > 2 ? 2 : initialIndex;

    return DefaultTabController(
      length: 3,
      initialIndex: tabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '$messName - Student Portal',
            overflow: TextOverflow.ellipsis,
          ),
          toolbarHeight: 72,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showStudentActions(context, authProvider),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Reviews'),
              Tab(text: 'Predictions'),
              Tab(text: 'Analytics'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ReviewsTab(messId: messId),
            StudentAnalyticsPredictionsScreen(
              includeScaffold: false,
              showAnalytics: false,
              showPredictions: true,
              showReviews: false,
            ),
            StudentAnalyticsPredictionsScreen(
              includeScaffold: false,
              showAnalytics: true,
              showPredictions: false,
              showReviews: false,
            ),
          ],
        ),
      ),
    );
  }
}
