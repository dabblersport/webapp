import "package:flutter/material.dart";
import 'package:dabbler/core/design_system/design_system.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleSectionLayout(
      appBar: AppBar(
        title: const Text("FAQ"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.question_answer, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "FAQ",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
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
