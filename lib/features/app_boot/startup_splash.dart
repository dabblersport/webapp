import 'dart:async';

import 'package:dabbler/core/constants/timing/splash_timing.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

/// Loads the splash animation. A seam so tests can drive it without the asset
/// bundle.
typedef SplashCompositionLoader = Future<LottieComposition> Function();

/// Plays the launch animation (`assets/Splash.lottie`) over a plain brand
/// ground while [bootstrap] runs, looping its draw-in (frames 0 to 89 of 132)
/// until the app is ready, then cross-fades to the widget [bootstrap] resolves
/// to.
///
/// ## One continuous splash
///
/// The native launch surfaces show only the ground — the app's welcome /
/// first-screen background in the device's light or dark appearance
/// ([groundFor]) — which is the animation's own start frame. On iOS a native
/// lottie-ios overlay (see `AppDelegate.swift`) plays the same animation from
/// the first native frame; when this widget has painted its own first frame it
/// calls [nativeHandoff], which returns the overlay's loop phase and removes
/// it, and the loop continues here from that phase, so there is no restart.
/// Android's system splash cannot play a `.lottie`, so Android shows the ground
/// until this widget's first frame.
///
/// It is not a route: nothing here touches the router, so the platform's
/// initial location (a deep link or a web URL) is what the app's router reads
/// when it is built after the splash.
///
/// The app replaces the splash when [bootstrap] is done AND the animation has
/// been shown for [SplashTiming.minDisplay]; there is no wait for a full play.
/// If the animation fails to load, or under reduced motion (the mark is shown
/// still), bootstrap alone gates.
class StartupSplash extends StatefulWidget {
  const StartupSplash({
    super.key,
    required this.bootstrap,
    this.compositionLoader = defaultLoader,
    this.nativeHandoff = defaultNativeHandoff,
  });

  /// Completes with the app to show once the splash is done. Must not fail;
  /// resolve to an error app instead.
  final Future<Widget> bootstrap;
  final SplashCompositionLoader compositionLoader;

  /// Asks the native overlay (iOS) to hand over: returns its loop phase
  /// (0..1 of the draw-in loop) and removes it, or null when there is none.
  final Future<double?> Function() nativeHandoff;

  static const String asset = 'assets/Splash.lottie';

  /// The progress (0..1) of `Splash.lottie` shown still under reduced motion:
  /// frame 89 of 132, the last one with the whole mark drawn, just before it
  /// fades to the bare ground.
  static const double stillFrame = 89 / 132;

  /// The splash ground for [brightness]: the welcome / first-screen background,
  /// [DabblerColors.bgPrimary] of the main theme (`#F5F0E6` light, `#141414`
  /// dark) — what [DabblerPage] paints. The native launch resources
  /// (`splash_background` on Android, `LaunchGround` on iOS, `index.html` on
  /// the web) carry the same two values.
  static Color groundFor(Brightness brightness) => DabblerColors.resolve(
    theme: DabblerTheme.main,
    brightness: brightness,
  ).bgPrimary;

  static Future<LottieComposition> defaultLoader() => AssetLottie(asset).load();

  static const MethodChannel _channel = MethodChannel('dabbler/startup');

  /// The `dabbler/startup` channel's `handoff` (iOS only; null elsewhere or if
  /// the native side has no overlay).
  static Future<double?> defaultNativeHandoff() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      return await _channel.invokeMethod<double>('handoff');
    } catch (_) {
      return null;
    }
  }

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(vsync: this);
  // Completes when the animation no longer holds the app: at once if it failed
  // or is still (reduced motion), else minDisplay after its first painted frame.
  final Completer<void> _animationGate = Completer<void>();
  Timer? _minDisplay;
  LottieComposition? _composition;
  bool _started = false;
  bool _handedOff = false;
  Widget? _app;

  late Brightness _brightness = _deviceBrightness;

  Brightness get _deviceBrightness =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_waitForBoth());
  }

  // No MediaQuery or theme exists above the splash, so it follows the device's
  // automatic light/dark appearance directly, the same one the native launch
  // surfaces follow.
  @override
  void didChangePlatformBrightness() {
    if (mounted) setState(() => _brightness = _deviceBrightness);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_start(DabblerMotion.reduceMotion(context)));
  }

  Future<void> _start(bool reduceMotion) async {
    try {
      final LottieComposition composition = await widget
          .compositionLoader()
          .timeout(SplashTiming.loadTimeout);
      if (!mounted) return _openGate();
      _controller.duration = composition.duration;
      setState(() => _composition = composition);
      // The first painted frame of the animation: hand the native overlay over
      // (continuing from its phase), then count the minimum display from here.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return _openGate();
      final double? phase = await widget.nativeHandoff();
      _handedOff = true;
      if (!mounted) return _openGate();
      if (reduceMotion) {
        // The mark fully drawn, still, no playback. (The animation ends on
        // the bare ground, so its last frame is not a useful still.)
        _controller.value = StartupSplash.stillFrame;
        return _openGate();
      }
      // Loop only the draw-in, from where the native overlay was.
      final double end = StartupSplash.stillFrame;
      _controller.value = (phase ?? 0).clamp(0.0, 1.0) * end;
      unawaited(
        _controller
            .repeat(min: 0, max: end, period: composition.duration * end)
            .catchError((Object _) {}),
      );
      _minDisplay = Timer(SplashTiming.minDisplay, _openGate);
    } catch (_) {
      // Load or play failed (or the ticker was cancelled by dispose): bootstrap
      // alone gates now, and any native overlay goes.
      _openGate();
    } finally {
      if (!_handedOff) {
        _handedOff = true;
        unawaited(widget.nativeHandoff());
      }
    }
  }

  void _openGate() {
    if (!_animationGate.isCompleted) _animationGate.complete();
  }

  Future<void> _waitForBoth() async {
    final Widget app = await widget.bootstrap;
    await _animationGate.future;
    if (!mounted) return;
    _minDisplay?.cancel();
    // Cross-fade from the splash frozen at its current frame.
    _controller.stop();
    setState(() => _app = app);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minDisplay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _splash() {
    final LottieComposition? composition = _composition;
    return Directionality(
      key: const ValueKey<String>('startup-splash'),
      textDirection: TextDirection.ltr,
      // Same colour as the native and web launch backgrounds, so launch ->
      // animation has no visible seam.
      child: ColoredBox(
        color: StartupSplash.groundFor(_brightness),
        child: composition == null
            ? const SizedBox.expand()
            : Center(
                key: const ValueKey('startup-splash-animation'),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: composition.bounds.width.toDouble(),
                  ),
                  child: AspectRatio(
                    aspectRatio:
                        composition.bounds.width / composition.bounds.height,
                    child: Lottie(
                      composition: composition,
                      controller: _controller,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget? app = _app;
    return AnimatedSwitcher(
      duration: SplashTiming.crossFade,
      child: app == null
          ? _splash()
          : KeyedSubtree(
              key: const ValueKey<String>('startup-app'),
              child: app,
            ),
    );
  }
}
