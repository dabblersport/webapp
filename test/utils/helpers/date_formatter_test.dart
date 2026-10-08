import 'package:dabbler/utils/helpers/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 15 Jan 2024, 14:30 (Monday) - a fixed date for the pure formatters.
  final fixed = DateTime(2024, 1, 15, 14, 30);

  group('fixed-date formatters', () {
    test('formatDate', () {
      expect(DateFormatter.formatDate(fixed), 'Jan 15, 2024');
      expect(DateFormatter.formatDate(DateTime(2024, 3, 5)), 'Mar 5, 2024');
    });

    test('formatTime is 12-hour', () {
      expect(DateFormatter.formatTime(fixed), '2:30 PM');
      expect(DateFormatter.formatTime(DateTime(2024, 1, 15, 9, 5)), '9:05 AM');
      expect(DateFormatter.formatTime(DateTime(2024, 1, 15, 0, 0)), '12:00 AM');
      expect(
        DateFormatter.formatTime(DateTime(2024, 1, 15, 12, 0)),
        '12:00 PM',
      );
    });

    test('formatDateTime', () {
      expect(DateFormatter.formatDateTime(fixed), 'Jan 15, 2024 2:30 PM');
    });

    test('formatShortDate', () {
      expect(DateFormatter.formatShortDate(fixed), '1/15/24');
      expect(DateFormatter.formatShortDate(DateTime(2025, 12, 3)), '12/3/25');
    });

    test('getDayName', () {
      expect(DateFormatter.getDayName(fixed), 'Monday');
      expect(DateFormatter.getDayName(DateTime(2024, 1, 21)), 'Sunday');
    });

    test('getMonthName', () {
      expect(DateFormatter.getMonthName(fixed), 'January');
      expect(DateFormatter.getMonthName(DateTime(2024, 12, 1)), 'December');
    });
  });

  group('formatDateRange', () {
    test('same month', () {
      expect(
        DateFormatter.formatDateRange(
          DateTime(2024, 1, 15),
          DateTime(2024, 1, 20),
        ),
        'Jan 15 - 20, 2024',
      );
    });

    test('same year, different month', () {
      expect(
        DateFormatter.formatDateRange(
          DateTime(2024, 1, 28),
          DateTime(2024, 2, 3),
        ),
        'Jan 28 - Feb 3, 2024',
      );
    });

    test('cross year', () {
      expect(
        DateFormatter.formatDateRange(
          DateTime(2023, 12, 28),
          DateTime(2024, 1, 3),
        ),
        'Dec 28, 2023 - Jan 3, 2024',
      );
    });

    test('same month in different years is a cross-year range', () {
      expect(
        DateFormatter.formatDateRange(
          DateTime(2023, 1, 15),
          DateTime(2024, 1, 20),
        ),
        'Jan 15, 2023 - Jan 20, 2024',
      );
    });
  });

  group('formatRelativeTime', () {
    // Offsets sit well inside each bucket so the test clock drift is harmless.
    String ago(Duration d) =>
        DateFormatter.formatRelativeTime(DateTime.now().subtract(d));

    test('under a minute is Just now', () {
      expect(ago(const Duration(seconds: 10)), 'Just now');
    });

    test('minutes, singular and plural', () {
      expect(ago(const Duration(minutes: 1, seconds: 10)), '1 minute ago');
      expect(ago(const Duration(minutes: 5, seconds: 30)), '5 minutes ago');
    });

    test('hours, singular and plural', () {
      expect(ago(const Duration(hours: 1, minutes: 5)), '1 hour ago');
      expect(ago(const Duration(hours: 2, minutes: 30)), '2 hours ago');
    });

    test('days, singular and plural', () {
      expect(ago(const Duration(days: 1, hours: 1)), '1 day ago');
      expect(ago(const Duration(days: 3, hours: 1)), '3 days ago');
      expect(ago(const Duration(days: 7, hours: 1)), '7 days ago');
    });

    test('more than 7 days falls back to the date', () {
      final old = DateTime.now().subtract(const Duration(days: 8, hours: 1));
      expect(
        DateFormatter.formatRelativeTime(old),
        DateFormatter.formatDate(old),
      );
    });

    test('a future time reads Just now', () {
      expect(
        DateFormatter.formatRelativeTime(
          DateTime.now().add(const Duration(hours: 2)),
        ),
        'Just now',
      );
    });
  });

  group('formatTimeRemaining', () {
    String left(Duration d) =>
        DateFormatter.formatTimeRemaining(DateTime.now().add(d));

    test('past is Expired', () {
      expect(left(const Duration(minutes: -5)), 'Expired');
    });

    test('under a minute', () {
      expect(left(const Duration(seconds: 20)), 'Less than a minute');
    });

    test('minutes', () {
      expect(left(const Duration(minutes: 1, seconds: 30)), '1 minute left');
      expect(left(const Duration(minutes: 5, seconds: 30)), '5 minutes left');
    });

    test('hours', () {
      expect(left(const Duration(hours: 1, minutes: 5)), '1 hour left');
      expect(left(const Duration(hours: 2, minutes: 30)), '2 hours left');
    });

    test('days', () {
      expect(left(const Duration(days: 1, hours: 1)), '1 day left');
      expect(left(const Duration(days: 3, hours: 1)), '3 days left');
    });
  });

  group('isToday / isYesterday', () {
    test('isToday', () {
      final now = DateTime.now();
      expect(DateFormatter.isToday(now), isTrue);
      expect(
        DateFormatter.isToday(DateTime(now.year, now.month, now.day, 23, 59)),
        isTrue,
      );
      expect(
        DateFormatter.isToday(now.subtract(const Duration(days: 2))),
        isFalse,
      );
      expect(DateFormatter.isToday(now.add(const Duration(days: 2))), isFalse);
    });

    test('isToday needs the same year, month and day', () {
      final now = DateTime.now();
      expect(
        DateFormatter.isToday(DateTime(now.year - 1, now.month, now.day)),
        isFalse,
      );
    });

    test('isYesterday', () {
      final now = DateTime.now();
      expect(
        DateFormatter.isYesterday(now.subtract(const Duration(days: 1))),
        isTrue,
      );
      expect(DateFormatter.isYesterday(now), isFalse);
      expect(
        DateFormatter.isYesterday(now.subtract(const Duration(days: 3))),
        isFalse,
      );
      expect(
        DateFormatter.isYesterday(now.add(const Duration(days: 1))),
        isFalse,
      );
    });
  });

  group('getTimeBasedGreeting', () {
    String expectedFor(int hour) => hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    test('matches the current hour', () {
      // Read the clock on both sides so an hour tick mid-call cannot flake.
      final before = DateTime.now().hour;
      final greeting = DateFormatter.getTimeBasedGreeting();
      final after = DateTime.now().hour;
      expect({expectedFor(before), expectedFor(after)}, contains(greeting));
    });

    test('is one of the three greetings', () {
      expect([
        'Good Morning',
        'Good Afternoon',
        'Good Evening',
      ], contains(DateFormatter.getTimeBasedGreeting()));
    });
  });
}
