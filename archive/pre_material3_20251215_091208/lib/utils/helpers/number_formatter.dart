import 'package:intl/intl.dart';

class NumberFormatter {
  static final NumberFormat _formatter = NumberFormat.compact();
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 0,
  );

  /// Formats a number into a compact format (e.g., 1.2K, 3.4M)
  static String format(int number) {
    if (number < 1000) {
      return number.toString();
    }
    return _formatter.format(number);
  }

  /// Formats a number with thousand separators (e.g., 1,234,567)
  static String formatWithCommas(int number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }

  /// Formats a number as currency (e.g., $1,234)
  static String formatAsCurrency(int number) {
    return _currencyFormatter.format(number);
  }

  /// Formats a percentage (e.g., 85.5%)
  static String formatAsPercentage(double value, {int decimalPlaces = 1}) {
    return '${value.toStringAsFixed(decimalPlaces)}%';
  }

  /// Formats a decimal number with specified decimal places
  static String formatDecimal(double value, {int decimalPlaces = 2}) {
    return value.toStringAsFixed(decimalPlaces);
  }

  /// Formats points with appropriate suffix based on magnitude
  static String formatPoints(int points) {
    if (points < 1000) {
      return '$points pts';
    } else if (points < 1000000) {
      return '${(points / 1000).toStringAsFixed(1)}K pts';
    } else {
      return '${(points / 1000000).toStringAsFixed(1)}M pts';
    }
  }

  /// Formats a rank with ordinal suffix (e.g., 1st, 2nd, 3rd, 4th)
  static String formatRank(int rank) {
    if (rank % 100 >= 11 && rank % 100 <= 13) {
      return '${rank}th';
    }

    switch (rank % 10) {
      case 1:
        return '${rank}st';
      case 2:
        return '${rank}nd';
      case 3:
        return '${rank}rd';
      default:
        return '${rank}th';
    }
  }

  /// Formats duration in a human-readable format
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
