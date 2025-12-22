import 'package:flutter/material.dart';
import 'package:smart_mess/services/firestore_service.dart';
import 'package:smart_mess/models/menu_model.dart';

class MenuScreen extends StatefulWidget {
  final String messId;
  const MenuScreen({Key? key, required this.messId}) : super(key: key);

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<Menu?>(
        stream: _firestoreService.getTodayMenuStream(widget.messId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No menu available for today'),
                ],
              ),
            );
          }

          final menu = snapshot.data!;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),
                Text(
                  'Today\'s Menu',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  _formatDate(menu.date),
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 20),
                ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: menu.items.length,
                  separatorBuilder: (_, __) => Divider(),
                  itemBuilder: (context, index) {
                    final item = menu.items[index];
                    return Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (item.description != null) ...[
                              SizedBox(height: 8),
                              Text(
                                item.description!,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }
}
