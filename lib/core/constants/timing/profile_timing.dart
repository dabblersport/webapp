/// Domain durations used by the profile, notifications and transactions
/// screens. These are data (windows and offsets), not design: the only place a
/// `Duration` literal is allowed is this directory.
library;

/// Timing constants for the profile-area features.
abstract final class ProfileTiming {
  const ProfileTiming._();

  /// One day: the "yesterday" boundary and the per-day activity-chart step.
  static const Duration day = Duration(days: 1);

  /// Seven days: the "last 7 days" activity and transaction window.
  static const Duration week = Duration(days: 7);

  /// Thirty days: the "last 30 days" transaction window.
  static const Duration month = Duration(days: 30);

  /// Twelve hours: an offset in the sample transaction list.
  static const Duration halfDay = Duration(hours: 12);

  /// Two days: an offset in the sample transaction list.
  static const Duration twoDays = Duration(days: 2);

  /// Five days: an offset in the sample transaction list.
  static const Duration fiveDays = Duration(days: 5);
}
