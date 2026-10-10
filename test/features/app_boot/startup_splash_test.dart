import 'dart:async';
import 'dart:io';

import 'package:dabbler/core/constants/timing/splash_timing.dart';
import 'package:dabbler/features/app_boot/startup_splash.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

const _appKey = ValueKey('the-app');
const Widget _app = Directionality(
  textDirection: TextDirection.ltr,
  child: SizedBox(key: _appKey),
);

/// The real supplied artwork, decoded from the repository file.
Future<LottieComposition> _real() =>
    LottieComposition.fromBytes(File('assets/Splash.lottie').readAsBytesSync());

Duration _duration = Duration.zero;

Future<void> _pump(
  WidgetTester tester,
  Future<Widget> bootstrap, {
  SplashCompositionLoader? loader,
  Future<double?> Function()? handoff,
}) async {
  final LottieComposition composition = (await tester.runAsync(_real))!;
  _duration = composition.duration;
  await tester.pumpWidget(
    StartupSplash(
      bootstrap: bootstrap,
      compositionLoader: loader ?? () async => composition,
      nativeHandoff: handoff ?? () async => null,
    ),
  );
  await tester.pump();
}

double _progress(WidgetTester tester) =>
    tester.widget<Lottie>(find.byType(Lottie)).controller!.value;

void main() {
  final Duration minDisplay = SplashTiming.minDisplay;
  Color ground(WidgetTester tester) => tester
      .widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(StartupSplash),
              matching: find.byType(ColoredBox),
            )
            .first,
      )
      .color;

  for (final Brightness b in Brightness.values) {
    testWidgets('the splash ground is the welcome background, ${b.name}', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = b;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final bootstrap = Completer<Widget>();
      await _pump(tester, bootstrap.future);
      final DabblerColors c = DabblerColors.resolve(
        theme: DabblerTheme.main,
        brightness: b,
      );
      expect(ground(tester), c.bgPrimary);
      expect(
        ground(tester),
        b == Brightness.dark
            ? const Color(0xFF141414)
            : const Color(0xFFF5F0E6),
      );
      expect(ground(tester), isNot(DabblerPalette.mainP600));
      // Finish the splash so no timer outlives the test.
      bootstrap.complete(_app);
      await tester.pump(SplashTiming.minDisplay);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('the ground follows a device appearance change', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final bootstrap = Completer<Widget>();
    await _pump(tester, bootstrap.future);
    expect(ground(tester), const Color(0xFFF5F0E6));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    expect(ground(tester), const Color(0xFF141414));
    bootstrap.complete(_app);
    await tester.pump(minDisplay);
    await tester.pumpAndSettle();
  });

  testWidgets('the animation loops while loading, never stopping at its end', (
    tester,
  ) async {
    final boot = Completer<Widget>();
    await _pump(tester, boot.future);
    expect(find.byType(Lottie), findsOneWidget);
    // The loop covers the draw-in only: it wraps before the artwork's fade-out.
    double maxSeen = 0;
    int wraps = 0;
    double last = _progress(tester);
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      final double p = _progress(tester);
      if (p < last - 0.2) wraps++;
      if (p > maxSeen) maxSeen = p;
      last = p;
    }
    expect(wraps, greaterThanOrEqualTo(3), reason: 'looped for 8 s');
    expect(maxSeen, lessThanOrEqualTo(StartupSplash.stillFrame + 1e-6));
    expect(
      find.byKey(_appKey),
      findsNothing,
      reason: 'bootstrap still loading',
    );
    boot.complete(_app);
    await tester.pumpAndSettle();
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('bootstrap faster than 0.8 s -> the app opens at the minimum '
      'display, not after a full play', (tester) async {
    await _pump(tester, Future.value(_app));
    await tester.pump(minDisplay - const Duration(milliseconds: 100));
    expect(find.byKey(_appKey), findsNothing, reason: 'minimum not reached');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
    expect(
      minDisplay,
      lessThan(_duration),
      reason: 'the full play (2.2 s) is no longer waited for',
    );
  });

  testWidgets('bootstrap slower than 0.8 s -> opens as soon as it is ready', (
    tester,
  ) async {
    final boot = Completer<Widget>();
    await _pump(tester, boot.future);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(_appKey), findsNothing);
    boot.complete(_app);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget, reason: 'no extra wait');
  });

  testWidgets('hand-off is a cross-fade from the splash held at its frame', (
    tester,
  ) async {
    await _pump(tester, Future.value(_app));
    await tester.pump(minDisplay + const Duration(milliseconds: 20));
    await tester.pump();
    // Mid-fade: both the splash and the app are in the tree.
    await tester.pump(SplashTiming.crossFade ~/ 2);
    expect(find.byKey(_appKey), findsOneWidget);
    expect(find.byType(Lottie), findsOneWidget);
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.byType(Lottie), findsNothing, reason: 'splash gone after fade');
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('the native overlay is handed over once, and the loop continues '
      'from its phase', (tester) async {
    int calls = 0;
    final boot = Completer<Widget>();
    await _pump(
      tester,
      boot.future,
      handoff: () async {
        calls++;
        return 0.5;
      },
    );
    expect(calls, 1);
    final double p0 = _progress(tester);
    expect(
      p0,
      closeTo(0.5 * StartupSplash.stillFrame, 0.06),
      reason: 'continues from the native phase, no restart at 0',
    );
    boot.complete(_app);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('animation fails to load -> immediate fallback, native overlay '
      'released', (tester) async {
    int calls = 0;
    await _pump(
      tester,
      Future.value(_app),
      loader: () async => throw StateError('decode'),
      handoff: () async {
        calls++;
        return null;
      },
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byKey(_appKey), findsOneWidget);
    expect(find.byType(Lottie), findsNothing);
    expect(calls, 1);
  });

  testWidgets('animation load hangs -> abandoned after the load timeout', (
    tester,
  ) async {
    await _pump(
      tester,
      Future.value(_app),
      loader: () => Completer<LottieComposition>().future,
    );
    expect(find.byKey(_appKey), findsNothing);
    await tester.pump(SplashTiming.loadTimeout);
    await tester.pumpAndSettle();
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('reduced motion -> mark still, not played, no minimum wait', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final boot = Completer<Widget>();
    await _pump(tester, boot.future);
    expect(find.byType(Lottie), findsOneWidget);
    expect(_progress(tester), StartupSplash.stillFrame);
    await tester.pump(const Duration(seconds: 1));
    expect(_progress(tester), StartupSplash.stillFrame, reason: 'not played');

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
    await _pump(tester, Future.value(MaterialApp.router(routerConfig: router)));
    await tester.pump(SplashTiming.minDisplay);
    await tester.pumpAndSettle();
    expect(find.text('game 42'), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });

  test('Splash.lottie holds no solid #7328CE fill (no purple flash)', () async {
    final LottieComposition c = await _real();
    // Decoded JSON text of the archive's animation: no fill of the old purple
    // (0.451, 0.1569, 0.8078) remains.
    final String json = Process.runSync('unzip', <String>[
      '-p',
      'assets/Splash.lottie',
      'a/Splash.json',
    ]).stdout.toString();
    expect(c.duration, const Duration(milliseconds: 2200));
    expect(json.replaceAll(' ', '').contains('0.451,0.1569,0.8078'), isFalse);
    expect(json.contains('0.5922'), isTrue, reason: 'strokes kept');
  });

  test('startup no longer plays video; both assets are bundled unchanged', () {
    final String splash = File(
      'lib/features/app_boot/startup_splash.dart',
    ).readAsStringSync();
    expect(splash.contains('Splash.mp4'), isFalse);
    expect(splash.contains('video_player'), isFalse);
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/Splash.lottie'));
    expect(pubspec, contains('- assets/Splash.mp4'));
    // Source bytes of the supplied artwork and the retained video.
    String sha(String f) => Process.runSync('shasum', <String>[
      f,
    ]).stdout.toString().split(' ').first;
    expect(
      sha('assets/Splash.lottie'),
      '926c0ebefbb7259caf28142526c566c94a305920',
    );
    expect(
      sha('assets/Splash.mp4'),
      '9e764c856090b89be2958522a68bc0179a4fc843',
    );
  });
}
