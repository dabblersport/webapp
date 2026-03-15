import 'package:flutter/material.dart';

/// Simple rewards screen for navigation tab
/// This serves as the main entry point for the rewards system
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Rewards'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: const Center(child: Text('Rewards Screen - Under Construction')),
    );
  }
}
