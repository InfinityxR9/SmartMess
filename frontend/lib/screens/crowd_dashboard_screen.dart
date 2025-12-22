import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/mess_provider.dart';
import 'package:smart_mess/providers/crowd_provider.dart';
import 'package:smart_mess/providers/prediction_provider.dart';
import 'package:smart_mess/providers/auth_provider.dart';
import 'package:smart_mess/screens/qr_scanner_screen.dart';
import 'package:smart_mess/screens/menu_screen.dart';
import 'package:smart_mess/screens/rating_screen.dart';
import 'package:smart_mess/widgets/crowd_badge.dart';

class CrowdDashboardScreen extends StatefulWidget {
  const CrowdDashboardScreen({Key? key}) : super(key: key);

  @override
  State<CrowdDashboardScreen> createState() => _CrowdDashboardScreenState();
}

class _CrowdDashboardScreenState extends State<CrowdDashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messProvider = context.read<MessProvider>();
      final crowdProvider = context.read<CrowdProvider>();
      final predictionProvider = context.read<PredictionProvider>();

      if (messProvider.selectedMess != null) {
        crowdProvider.listenToCrowdCount(messProvider.selectedMess!.id);
        predictionProvider.fetchPrediction(messProvider.selectedMess!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MessProvider>(
      builder: (context, messProvider, _) {
        if (messProvider.selectedMess == null) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final mess = messProvider.selectedMess!;

        return Scaffold(
          appBar: AppBar(
            title: Text(mess.name),
            actions: [
              IconButton(
                icon: Icon(Icons.logout),
                onPressed: () {
                  context.read<AuthProvider>().signOut();
                  Navigator.of(context).pushReplacementNamed('/home');
                },
              ),
            ],
          ),
          body: _buildPage(mess),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() => _selectedIndex = index);
            },
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Crowd',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.restaurant_menu),
                label: 'Menu',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.qr_code),
                label: 'Scan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.star),
                label: 'Rating',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPage(dynamic mess) {
    switch (_selectedIndex) {
      case 0:
        return _buildCrowdPage(mess);
      case 1:
        return MenuScreen(messId: mess.id);
      case 2:
        return _buildScanPage(mess);
      case 3:
        return RatingScreen();
      default:
        return _buildCrowdPage(mess);
    }
  }

  Widget _buildScanPage(dynamic mess) {
    // Show meal type selector for QR scanning
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Select Meal Type to Scan QR', style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => QRScannerScreen(mealType: 'breakfast'),
              ));
            },
            child: Text('Breakfast'),
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => QRScannerScreen(mealType: 'lunch'),
              ));
            },
            child: Text('Lunch'),
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => QRScannerScreen(mealType: 'dinner'),
              ));
            },
            child: Text('Dinner'),
          ),
        ],
      ),
    );
  }

  Widget _buildCrowdPage(dynamic mess) {
    return Consumer2<CrowdProvider, PredictionProvider>(
      builder: (context, crowdProvider, predictionProvider, _) {
        final crowdCount = crowdProvider.crowdCount;
        final percentage = crowdProvider.getCrowdPercentage(mess.capacity);
        final level = crowdProvider.getCrowdLevel(mess.capacity);

        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Current Crowd Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Current Crowd',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(
                                '$crowdCount',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6200EE),
                                ),
                              ),
                              Text('Students'),
                            ],
                          ),
                          CrowdBadge(level: level),
                          Column(
                            children: [
                              Text(
                                '${(percentage * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF03DAC6),
                                ),
                              ),
                              Text('Capacity'),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getCrowdColor(level),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Prediction Card
              if (predictionProvider.prediction != null)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Prediction',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        if (predictionProvider.prediction!.bestSlot != null) ...[
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFF03DAC6).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Best Time to Visit',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  predictionProvider.prediction!.bestSlot!.timeSlot,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF03DAC6),
                                  ),
                                ),
                                Text(
                                  'Predicted Crowd: ${predictionProvider.prediction!.bestSlot!.crowdPercentage.toStringAsFixed(1)}%',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                        Text(
                          'Upcoming Slots',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: predictionProvider.prediction!.predictions.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final slot = predictionProvider.prediction!.predictions[index];
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(slot.timeSlot),
                                Chip(
                                  label: Text(
                                    '${slot.crowdPercentage.toStringAsFixed(0)}%',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: _getCrowdColor(
                                    slot.crowdPercentage < 30
                                        ? 'Low'
                                        : slot.crowdPercentage < 60
                                            ? 'Medium'
                                            : 'High',
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                )
              else if (predictionProvider.isLoading)
                Center(child: CircularProgressIndicator())
              else if (predictionProvider.error != null)
                Text('Error: ${predictionProvider.error}'),
            ],
          ),
        );
      },
    );
  }

  Color _getCrowdColor(String level) {
    switch (level) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'High':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
