/// Startup splash timing. These bound how long the launch video may hold the
/// app; they are not motion and do not go through `DabblerMotion.durationOf`.
library;

abstract final class SplashTiming {
  const SplashTiming._();

  /// How long the splash video may take to load before it is abandoned and
  /// the app starts as soon as bootstrap is done.
  static const Duration loadTimeout = Duration(milliseconds: 1500);

  /// Grace added to the video's own duration before the splash stops waiting
  /// for the "ended" event (a stalled or throttled player).
  static const Duration endedGrace = Duration(milliseconds: 500);
}
