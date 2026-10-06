import 'dart:async';

import 'package:dabbler/core/constants/timing/splash_timing.dart';
import 'package:dabbler/features/app_boot/startup_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeSplashVideo extends ChangeNotifier implements SplashVideo {
  FakeSplashVideo({this.failInit = false, this.hangInit = false});

  final bool failInit;
  final bool hangInit;
  bool played = false;
  double? volumeAtPlay;
  double volume = 1;
  bool _ended = false;
  bool _error = false;
  bool disposed = false;

  @override
  Future<void> initialize() async {
    if (hangInit) return Completer<void>().future;
    if (failInit) throw StateError('codec');
  }

  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Future<void> play() async {
    played = true;
    volumeAtPlay = volume;
  }

  @override
  Size get size => const Size(160, 350);
  @override
  Duration get duration => const Duration(seconds: 2);
  @override
  bool get hasEnded => _ended;
  @override
  bool get hasError => _error;
  @override
  Widget buildView() => const SizedBox.expand(key: ValueKey('fake-video'));

  void end() {
    _ended = true;
    notifyListeners();
  }

  void fail() {
    _error = true;
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

const _appKey = ValueKey('the-app');
const Widget _app = Directionality(
  textDirection: TextDirection.ltr,
  child: SizedBox(key: _appKey),
);

Future<void> _pump(
  WidgetTester tester,
  FakeSplashVideo video,
  Future<Widget> bootstrap,
) async {
  await tester.pumpWidget(
    StartupSplash(bootstrap: bootstrap, videoFactory: () => video),
  );
  await tester.pump();
}

void main() {
  testWidgets('video ended -> shows the app once bootstrap is done', (
    tester,
  ) async {
    final video = FakeSplashVideo();
    await _pump(tester, video, Future.value(_app));
    expect(video.played, isTrue);
    expect(video.volumeAtPlay, 0, reason: 'muted before play (web autoplay)');
    expect(find.byKey(const ValueKey('fake-video')), findsOneWidget);
    expect(find.byKey(_appKey), findsNothing);

    video.end();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
    expect(video.disposed, isTrue);
  });

  testWidgets('bootstrap slower than video -> waits for bootstrap', (
    tester,
  ) async {
    final video = FakeSplashVideo();
    final boot = Completer<Widget>();
    await _pump(tester, video, boot.future);
    video.end();
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(_appKey), findsNothing);

    boot.complete(_app);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('video never reports ended -> capped at duration + grace', (
    tester,
  ) async {
    final video = FakeSplashVideo();
    await _pump(tester, video, Future.value(_app));
    await tester.pump(video.duration);
    expect(find.byKey(_appKey), findsNothing);
    await tester.pump(SplashTiming.endedGrace);
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('video fails to load -> immediate fallback to bootstrap', (
    tester,
  ) async {
    final video = FakeSplashVideo(failInit: true);
    await _pump(tester, video, Future.value(_app));
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
    expect(video.played, isFalse);
  });

  testWidgets('play error (autoplay blocked) -> immediate fallback', (
    tester,
  ) async {
    final video = FakeSplashVideo();
    await _pump(tester, video, Future.value(_app));
    video.fail();
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('video load hangs -> abandoned after the load timeout', (
    tester,
  ) async {
    final video = FakeSplashVideo(hangInit: true);
    await _pump(tester, video, Future.value(_app));
    expect(find.byKey(_appKey), findsNothing);
    await tester.pump(SplashTiming.loadTimeout);
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('reduced motion -> still frame, not played', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final video = FakeSplashVideo();
    final boot = Completer<Widget>();
    await _pump(tester, video, boot.future);
    expect(video.played, isFalse);
    expect(find.byKey(const ValueKey('fake-video')), findsOneWidget);

    boot.complete(_app);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('deep link resolves to its target after the splash', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/games/42';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/games/:id',
          builder: (_, s) => Text('game ${s.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    final video = FakeSplashVideo();
    await _pump(
      tester,
      video,
      Future.value(MaterialApp.router(routerConfig: router)),
    );
    video.end();
    await tester.pumpAndSettle();
    expect(find.text('game 42'), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });
}
