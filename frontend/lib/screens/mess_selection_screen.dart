import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mess/providers/mess_provider.dart';
import 'package:smart_mess/screens/crowd_dashboard_screen.dart';

class MessSelectionScreen extends StatefulWidget {
  const MessSelectionScreen({Key? key}) : super(key: key);

  @override
  State<MessSelectionScreen> createState() => _MessSelectionScreenState();
}

class _MessSelectionScreenState extends State<MessSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessProvider>().fetchAllMesses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Your Mess'),
        centerTitle: true,
      ),
      body: Consumer<MessProvider>(
        builder: (context, messProvider, _) {
          // Show error if any
          if (messProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error Loading Messes'),
                  SizedBox(height: 8),
                  Text(messProvider.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      messProvider.fetchAllMesses();
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (messProvider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (messProvider.messes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No messes available'),
                  SizedBox(height: 8),
                  Text('Please create a mess in Firebase Firestore'),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      messProvider.fetchAllMesses();
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: messProvider.messes.length,
            itemBuilder: (context, index) {
              final mess = messProvider.messes[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(Icons.location_on, color: Color(0xFF6200EE)),
                  title: Text(
                    mess.name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text('Capacity: ${mess.capacity}'),
                  trailing: Icon(Icons.arrow_forward),
                  onTap: () {
                    messProvider.setSelectedMess(mess);
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => CrowdDashboardScreen()),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
