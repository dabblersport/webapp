import "package:flutter/material.dart";

class RebookFlow extends StatelessWidget {
  final String gameId;

  const RebookFlow({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rebook"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.replay, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Rebook Game",
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
