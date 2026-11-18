/// Notification windows of the Notification Center Epic (KAN-973, W0-5).
/// Domain timing, not motion; the server owns the authoritative values and
/// the client reads these to label and schedule what it shows.
library;

abstract final class NotificationTiming {
  const NotificationTiming._();

  /// Check-in opens this long before the start (and the Live Activity
  /// starts); also the last reminder rung.
  static const Duration checkInOpens = Duration(minutes: 30);

  /// "Check-in closes soon" is sent this long before it closes.
  static const Duration checkInClosingWarning = Duration(minutes: 15);

  /// KAN-1008: check-in closes this long after the start (closes_at).
  static const Duration checkInCloses = Duration(minutes: 15);

  /// KAN-1008: the ongoing card's countdown step.
  static const Duration ongoingCountdownTick = Duration(minutes: 1);

  /// KAN-1008: the server drops a closed or cancelled event this long after
  /// the close, so the card reads again then.
  static const Duration ongoingClosedExpiry = Duration(hours: 2);

  /// KAN-1008: one retry this long after a failed ongoing read.
  static const Duration ongoingRetryAfterFailure = Duration(minutes: 1);

  /// KAN-1008: trailing debounce on notice-driven ongoing reads.
  static const Duration ongoingNoticeDebounce = Duration(milliseconds: 300);

  /// KAN-998: the check-in screen re-reads the server when its window opens
  /// or closes within this horizon, a moment after the edge.
  static const Duration checkInEdgeHorizon = Duration(hours: 1);
  static const Duration checkInEdgeGrace = Duration(seconds: 1);

  /// The 2h reminder rung (the 09:00 rung only runs when earlier than this).
  static const Duration reminderShort = Duration(hours: 2);

  /// The 24h reminder rung; also the organiser's result and auto-finalize
  /// window.
  static const Duration reminderLong = Duration(hours: 24);

  /// The no-show review window and the post-activity score and rating window.
  static const Duration reviewWindow = Duration(hours: 48);

  /// Likes, reactions, comment likes and follows group within this window.
  static const Duration aggregationWindow = Duration(hours: 1);

  /// A grouped row pushes at most once in this interval.
  static const Duration groupedPushCap = Duration(minutes: 15);

  /// Inbox rows are kept this long.
  static const Duration inboxRetention = Duration(days: 90);

  /// KAN-1002: the lifecycle card re-reads this long past a boundary, so the
  /// server's now() is past it too.
  static const Duration lifecycleBoundarySlack = Duration(seconds: 1);

  /// KAN-1005: a resume re-syncs Live Activities at most once per this.
  static const Duration liveActivityResumeThrottle = Duration(seconds: 30);
}
