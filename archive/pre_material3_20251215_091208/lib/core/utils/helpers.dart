import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Added for Timer
import 'dart:math';

class AppHelpers {
  /// Capitalize the first letter of a string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Format a date to a readable string
  static String formatDate(DateTime date, {String format = 'MMM dd, yyyy'}) {
    return DateFormat(format).format(date);
  }

  /// Format a time to a readable string
  static String formatTime(DateTime time, {String format = 'HH:mm'}) {
    return DateFormat(format).format(time);
  }

  /// Format a date and time to a readable string
  static String formatDateTime(
    DateTime dateTime, {
    String format = 'MMM dd, yyyy HH:mm',
  }) {
    return DateFormat(format).format(dateTime);
  }

  /// Get relative time (e.g., "2 hours ago", "yesterday")
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return formatDate(dateTime);
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'just now';
    }
  }

  /// Format a number with commas
  static String formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }

  /// Format currency
  static String formatCurrency(double amount, {String currency = 'AED'}) {
    return NumberFormat.currency(symbol: currency).format(amount);
  }

  /// Format percentage
  static String formatPercentage(double value, {int decimalPlaces = 1}) {
    return '${(value * 100).toStringAsFixed(decimalPlaces)}%';
  }

  /// Get initials from a name
  static String getInitials(String name) {
    if (name.isEmpty) return '';

    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  /// Truncate text with ellipsis
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Generate a random string
  static String generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();

    for (int i = 0; i < length; i++) {
      buffer.write(chars[random % chars.length]);
    }

    return buffer.toString();
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 10 && digits.length <= 15;
  }

  /// Get file extension from filename
  static String getFileExtension(String filename) {
    return filename.split('.').last.toLowerCase();
  }

  /// Get file size in human readable format
  static String getFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Show a snackbar
  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    Color? textColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: textColor)),
        duration: duration,
        backgroundColor: backgroundColor,
      ),
    );
  }

  /// Show a confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context,
    String title,
    String message, {
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show a loading dialog
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  /// Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Get sport icon
  static IconData getSportIcon(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
        return Icons.sports_soccer;
      case 'basketball':
        return Icons.sports_basketball;
      case 'tennis':
        return Icons.sports_tennis;
      case 'volleyball':
        return Icons.sports_volleyball;
      case 'badminton':
        return Icons.sports_handball;
      case 'table_tennis':
        return Icons.sports_tennis;
      case 'cricket':
        return Icons.sports_cricket;
      case 'baseball':
        return Icons.sports_baseball;
      case 'rugby':
        return Icons.sports_rugby;
      case 'hockey':
        return Icons.sports_hockey;
      default:
        return Icons.sports;
    }
  }

  /// Get sport display name
  static String getSportDisplayName(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
        return 'Football';
      case 'basketball':
        return 'Basketball';
      case 'tennis':
        return 'Tennis';
      case 'volleyball':
        return 'Volleyball';
      case 'badminton':
        return 'Badminton';
      case 'table_tennis':
        return 'Table Tennis';
      case 'cricket':
        return 'Cricket';
      case 'baseball':
        return 'Baseball';
      case 'rugby':
        return 'Rugby';
      case 'hockey':
        return 'Hockey';
      default:
        return capitalize(sport);
    }
  }

  /// Get intent display name
  static String getIntentDisplayName(String intent) {
    switch (intent.toLowerCase()) {
      case 'competitive':
        return 'Competitive';
      case 'casual':
        return 'Casual';
      case 'training':
        return 'Training';
      case 'social':
        return 'Social';
      case 'fitness':
        return 'Fitness';
      default:
        return capitalize(intent);
    }
  }

  /// Get status color
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'completed':
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'inactive':
        return Colors.red;
      case 'ongoing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Get status display name
  static String getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      case 'ongoing':
        return 'Ongoing';
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      default:
        return capitalize(status);
    }
  }

  /// Calculate distance between two coordinates
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);

    final a =
        pow(sin(dLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(dLon / 2), 2);
    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  /// Format distance
  static String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()}m';
    } else if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceInKm.round()}km';
    }
  }

  /// Debounce function
  static Function debounce(Function func, Duration wait) {
    Timer? timer;
    return ([List<dynamic>? args]) {
      timer?.cancel();
      timer = Timer(wait, () => Function.apply(func, args ?? []));
    };
  }

  /// Throttle function
  static Function throttle(Function func, Duration wait) {
    DateTime? lastCall;
    return ([List<dynamic>? args]) {
      final now = DateTime.now();
      if (lastCall == null || now.difference(lastCall!) >= wait) {
        lastCall = now;
        Function.apply(func, args ?? []);
      }
    };
  }
}
