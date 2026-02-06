import "package:flutter/material.dart";
import 'package:dabbler/core/design_system/design_system.dart';

class BadgeDetailScreen extends StatelessWidget {
  final String badgeId;

  const BadgeDetailScreen({super.key, required this.badgeId});

  @override
  Widget build(BuildContext context) {
    return SingleSectionLayout(
      appBar: AppBar(
        title: const Text("Badge Details"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Badge Details",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Badge ID: $badgeId",
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            Text(
              "This screen is under development",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
