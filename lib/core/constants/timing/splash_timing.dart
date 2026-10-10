/// Startup splash timing. These bound how long the launch animation may hold
/// the app; they are not motion and do not go through `DabblerMotion.durationOf`.
library;

abstract final class SplashTiming {
  const SplashTiming._();

  /// How long the splash animation may take to load before it is abandoned
  /// and the app starts as soon as bootstrap is done.
  static const Duration loadTimeout = Duration(milliseconds: 1500);

  /// The least time the animation is shown, counted from its first painted
  /// frame, before the app may replace it. A bootstrap that finishes sooner
  /// waits out the rest of this so the animation is seen, then the app opens.
  /// Not applied when the animation failed to load or under reduced motion.
  static const Duration minDisplay = Duration(milliseconds: 800);

  /// The cross-fade from the splash (frozen at its current frame) to the app.
  static const Duration crossFade = Duration(milliseconds: 200);
}
