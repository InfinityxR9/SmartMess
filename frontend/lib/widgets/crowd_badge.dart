import 'package:flutter/material.dart';

class CrowdBadge extends StatelessWidget {
  final String level;
  const CrowdBadge({Key? key, required this.level}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    late Color backgroundColor;
    late Color textColor;
    late IconData icon;

    switch (level) {
      case 'Low':
        backgroundColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green;
        icon = Icons.sentiment_satisfied;
        break;
      case 'Medium':
        backgroundColor = Colors.orange.withValues(alpha: 0.2);
        textColor = Colors.orange;
        icon = Icons.sentiment_neutral;
        break;
      case 'High':
        backgroundColor = Colors.red.withValues(alpha: 0.2);
        textColor = Colors.red;
        icon = Icons.sentiment_dissatisfied;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: textColor),
          SizedBox(height: 4),
          Text(
            level,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
