import 'package:flutter/material.dart';
import 'package:dabbler/core/design_system/design_system.dart';

/// Simple rewards screen for navigation tab
/// This serves as the main entry point for the rewards system
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleSectionLayout(
      appBar: AppBar(title: const Text('Rewards')),
      child: const Center(child: Text('Rewards Screen - Under Construction')),
    );
  }
}
