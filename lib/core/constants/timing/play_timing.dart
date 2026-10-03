/// Domain timing for the play area (social, games, venues, home, location,
/// explore, news). These are data, not design: they are not motion and do not
/// go through `DabblerMotion.durationOf`.
library;

abstract final class PlayTiming {
  const PlayTiming._();

  /// Simulated latency of a mock lookup (list fetch, single user read).
  static const Duration mockLatencyBrief = Duration(milliseconds: 100);

  /// Simulated latency of a mock mutual-friends lookup.
  static const Duration mockLatencyShortish = Duration(milliseconds: 150);

  /// Simulated latency of a mock light write or batched user lookup.
  static const Duration mockLatencyShort = Duration(milliseconds: 200);

  /// Simulated latency of a mock fetch/search call.
  static const Duration mockLatencyMedium = Duration(milliseconds: 300);

  /// Simulated latency of a mock write (accept, decline, send, check-in).
  static const Duration mockLatencyLong = Duration(milliseconds: 500);

  /// Window in which a second back press exits the app.
  static const Duration backExitWindow = Duration(seconds: 2);

  /// Interval at which friends' online status is refreshed.
  static const Duration onlineStatusRefresh = Duration(seconds: 30);
}
