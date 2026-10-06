import 'dart:async';

import 'package:dabbler/core/constants/timing/splash_timing.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

/// The launch video, behind a seam so tests can drive it without a platform
/// player.
abstract class SplashVideo implements Listenable {
  Future<void> initialize();
  Future<void> setVolume(double volume);
  Future<void> play();

  /// Natural size of the video, valid after [initialize].
  Size get size;

  /// Length of the video, valid after [initialize].
  Duration get duration;

  bool get hasEnded;
  bool get hasError;

  Widget buildView();
  void dispose();
}

/// [SplashVideo] backed by the official `video_player` package.
class VideoPlayerSplashVideo implements SplashVideo {
  VideoPlayerSplashVideo(String asset)
    : _controller = VideoPlayerController.asset(
        asset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

  final VideoPlayerController _controller;

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);
  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);
  @override
  Future<void> initialize() => _controller.initialize();
  @override
  Future<void> setVolume(double volume) => _controller.setVolume(volume);
  @override
  Future<void> play() => _controller.play();
  @override
  Size get size => _controller.value.size;
  @override
  Duration get duration => _controller.value.duration;
  @override
  bool get hasEnded => _controller.value.isCompleted;
  @override
  bool get hasError => _controller.value.hasError;
  @override
  Widget buildView() => VideoPlayer(_controller);
  @override
  void dispose() => unawaited(_controller.dispose());
}

/// Plays the launch video once over a plain brand ground while [bootstrap]
/// runs, then shows the widget [bootstrap] resolves to.
///
/// It is not a route: nothing here touches the router, so the platform's
/// initial location (a deep link or a web URL) is what the app's router reads
/// when it is built after the splash.
///
/// The app is shown when the video has ended AND bootstrap is done. The video
/// is abandoned immediately (bootstrap alone gates) if it fails to load or
/// play, and is not waited on past its duration plus
/// [SplashTiming.endedGrace]. Under reduced motion the first frame is shown
/// still instead of playing.
class StartupSplash extends StatefulWidget {
  const StartupSplash({
    super.key,
    required this.bootstrap,
    this.videoFactory = defaultVideo,
  });

  /// Completes with the app to show once the splash is done. Must not fail;
  /// resolve to an error app instead.
  final Future<Widget> bootstrap;
  final SplashVideo Function() videoFactory;

  static const String asset = 'assets/Splash.mp4';

  static SplashVideo defaultVideo() => VideoPlayerSplashVideo(asset);

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash> {
  late final SplashVideo _video = widget.videoFactory();
  final Completer<void> _videoDone = Completer<void>();
  Timer? _cap;
  bool _ready = false;
  bool _started = false;
  Widget? _app;

  @override
  void initState() {
    super.initState();
    _video.addListener(_onVideo);
    unawaited(_waitForBoth());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_startVideo(DabblerMotion.reduceMotion(context)));
  }

  Future<void> _startVideo(bool reduceMotion) async {
    try {
      await _video.initialize().timeout(SplashTiming.loadTimeout);
      if (!mounted || _video.hasError) return _finishVideo();
      // Muted before play: web autoplay is only allowed for muted media.
      await _video.setVolume(0);
      if (!mounted) return;
      setState(() => _ready = true);
      if (reduceMotion) return _finishVideo();
      _cap = Timer(_video.duration + SplashTiming.endedGrace, _finishVideo);
      await _video.play();
    } catch (_) {
      _finishVideo();
    }
  }

  void _onVideo() {
    if (_video.hasError) {
      // Fall back to the plain ground; bootstrap alone gates now.
      if (mounted && _ready) setState(() => _ready = false);
      _finishVideo();
    } else if (_video.hasEnded) {
      _finishVideo();
    }
  }

  void _finishVideo() {
    if (!_videoDone.isCompleted) _videoDone.complete();
  }

  Future<void> _waitForBoth() async {
    final app = await widget.bootstrap;
    await _videoDone.future;
    if (!mounted) return;
    setState(() => _app = app);
    _cap?.cancel();
    _video.removeListener(_onVideo);
    _video.dispose();
  }

  @override
  void dispose() {
    _cap?.cancel();
    if (_app == null) {
      _video.removeListener(_onVideo);
      _video.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app != null) return app;
    final size = _video.size;
    return Directionality(
      textDirection: TextDirection.ltr,
      // Same colour as the native and web launch backgrounds and the video's
      // own ground, so launch -> splash -> video has no visible seam.
      child: ColoredBox(
        color: DabblerPalette.mainP600,
        child: _ready && !size.isEmpty
            ? Center(
                key: const ValueKey('startup-splash-video'),
                child: FittedBox(
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: _video.buildView(),
                  ),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}
