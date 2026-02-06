import 'package:flutter/material.dart';
import 'leaderboard_screen.dart';

/// Temporary wrapper so the rewards route renders the leaderboard directly.
class RewardsDashboardScreen extends StatelessWidget {
  const RewardsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LeaderboardScreen();
  }
}
