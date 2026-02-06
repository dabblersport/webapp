import 'package:flutter/material.dart';
import 'package:dabbler/core/design_system/design_system.dart';

class InvitePlayersScreen extends StatelessWidget {
  const InvitePlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleSectionLayout(
      appBar: AppBar(
        title: const Text('Invite Players'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Invite Players',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'This screen is under development',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
