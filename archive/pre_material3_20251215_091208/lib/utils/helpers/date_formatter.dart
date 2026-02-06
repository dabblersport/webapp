import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  static final DateFormat _timeFormat = DateFormat('h:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('MMM d, yyyy h:mm a');
  static final DateFormat _shortDateFormat = DateFormat('M/d/yy');

  /// Formats a date in a readable format (e.g., "Jan 15, 2024")
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Formats time in 12-hour format (e.g., "2:30 PM")
  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }

  /// Formats both date and time (e.g., "Jan 15, 2024 2:30 PM")
  static String formatDateTime(DateTime date) {
    return _dateTimeFormat.format(date);
  }

  /// Formats date in short format (e.g., "1/15/24")
  static String formatShortDate(DateTime date) {
    return _shortDateFormat.format(date);
  }

  /// Formats a relative time (e.g., "2 hours ago", "3 days ago")
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return formatDate(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Formats a date range (e.g., "Jan 15 - 20, 2024")
  static String formatDateRange(DateTime startDate, DateTime endDate) {
    if (startDate.year == endDate.year && startDate.month == endDate.month) {
      return '${DateFormat('MMM d').format(startDate)} - ${DateFormat('d, yyyy').format(endDate)}';
    } else if (startDate.year == endDate.year) {
      return '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}';
    } else {
      return '${formatDate(startDate)} - ${formatDate(endDate)}';
    }
  }

  /// Gets greeting based on time of day
  static String getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  /// Formats duration until a future date (e.g., "2 days left")
  static String formatTimeRemaining(DateTime futureDate) {
    final now = DateTime.now();
    final difference = futureDate.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    }

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} left';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} left';
    } else {
      return 'Less than a minute';
    }
  }

  /// Checks if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Checks if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// Gets day of week name (e.g., "Monday")
  static String getDayName(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  /// Gets month name (e.g., "January")
  static String getMonthName(DateTime date) {
    return DateFormat('MMMM').format(date);
  }
}
