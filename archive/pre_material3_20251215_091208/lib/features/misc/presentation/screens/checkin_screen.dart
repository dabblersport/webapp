import "package:flutter/material.dart";

class CheckinScreen extends StatelessWidget {
  final String bookingId;

  const CheckinScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Check-in"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Check-in",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Booking ID: $bookingId",
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
