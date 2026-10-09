import 'dart:async';

import 'package:dabbler/core/constants/timing/splash_timing.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

/// Loads the splash animation. A seam so tests can drive it without the asset
/// bundle.
typedef SplashCompositionLoader = Future<LottieComposition> Function();

/// Plays the launch animation (`assets/Splash.lottie`) once over a plain brand
/// ground while [bootstrap] runs, then shows the widget [bootstrap] resolves
/// to.
///
/// ## One continuous splash
///
/// The OS launch screens cannot play a `.lottie`: Android's system splash is a
/// static icon on a colour and an iOS launch storyboard cannot run code. So
/// the native launch screens show only the ground ([DabblerPalette.mainP600],
/// `splash_purple` on Android, the storyboard colour on iOS, `index.html` on
/// the web) — which is the animation's own start frame (the mark is a stroke
/// that draws in from nothing) — and this widget then plays the animation once
/// on the same ground. There is no second route, no replay and no added delay.
///
/// It is not a route: nothing here touches the router, so the platform's
/// initial location (a deep link or a web URL) is what the app's router reads
/// when it is built after the splash.
///
/// The app is shown when the animation has finished AND bootstrap is done. If
/// bootstrap is slower, the animation holds its final frame (it never
/// replays). The animation is abandoned immediately (bootstrap alone gates) if
/// it fails to load or play, and is not waited on past its duration plus
/// [SplashTiming.endedGrace]. Under reduced motion the mark is shown still,
/// without waiting for playback.
class StartupSplash extends StatefulWidget {
  const StartupSplash({
    super.key,
    required this.bootstrap,
    this.compositionLoader = defaultLoader,
  });

  /// Completes with the app to show once the splash is done. Must not fail;
  /// resolve to an error app instead.
  final Future<Widget> bootstrap;
  final SplashCompositionLoader compositionLoader;

  static const String asset = 'assets/Splash.lottie';

  /// The progress (0..1) of `Splash.lottie` shown still under reduced motion:
  /// frame 89 of 132, the last one with the whole mark drawn, just before it
  /// fades to the bare ground.
  static const double stillFrame = 89 / 132;

  static Future<LottieComposition> defaultLoader() => AssetLottie(asset).load();

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  final Completer<void> _animationDone = Completer<void>();
  Timer? _cap;
  LottieComposition? _composition;
  bool _started = false;
  Widget? _app;

  @override
  void initState() {
    super.initState();
    unawaited(_waitForBoth());
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
      if (!mounted) return _finish();
      _controller.duration = composition.duration;
      setState(() => _composition = composition);
      if (reduceMotion) {
        // The mark fully drawn, still, no playback. (The animation ends on
        // the bare ground, so its last frame is not a useful still.)
        _controller.value = StartupSplash.stillFrame;
        return _finish();
      }
      _cap = Timer(composition.duration + SplashTiming.endedGrace, _finish);
      // Once: the controller stops at its end and holds the last frame.
      await _controller.forward().orCancel;
      _finish();
    } catch (_) {
      // Load or play failed (or the ticker was cancelled by dispose): bootstrap
      // alone gates now.
      _finish();
    }
  }

  void _finish() {
    if (!_animationDone.isCompleted) _animationDone.complete();
  }

  Future<void> _waitForBoth() async {
    final Widget app = await widget.bootstrap;
    await _animationDone.future;
    if (!mounted) return;
    _cap?.cancel();
    setState(() => _app = app);
  }

  @override
  void dispose() {
    _cap?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget? app = _app;
    if (app != null) return app;
    final LottieComposition? composition = _composition;
    return Directionality(
      textDirection: TextDirection.ltr,
      // Same colour as the native and web launch backgrounds, so launch ->
      // animation has no visible seam.
      child: ColoredBox(
        color: DabblerPalette.mainP600,
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
}
