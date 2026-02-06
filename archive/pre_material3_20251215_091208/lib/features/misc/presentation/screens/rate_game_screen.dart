import "package:flutter/material.dart";

class RateGameScreen extends StatelessWidget {
  final String gameId;

  const RateGameScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rate Game"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_rate, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Rate Game",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text("Game ID: $gameId", style: TextStyle(color: Colors.grey[600])),
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
