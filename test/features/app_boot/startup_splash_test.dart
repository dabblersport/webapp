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
}) async {
  final LottieComposition composition = (await tester.runAsync(_real))!;
  _duration = composition.duration;
  await tester.pumpWidget(
    StartupSplash(
      bootstrap: bootstrap,
      compositionLoader: loader ?? () async => composition,
    ),
  );
  await tester.pump();
}

double _progress(WidgetTester tester) =>
    tester.widget<Lottie>(find.byType(Lottie)).controller!.value;

void main() {
  testWidgets('the splash draws its own launch purple, not html/body', (
    tester,
  ) async {
    final bootstrap = Completer<Widget>();
    await _pump(tester, bootstrap.future);
    final box = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(StartupSplash),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(box.color, DabblerPalette.mainP600);
    expect(box.color, const Color(0xFF7328CE));
    // Finish the splash so no timer outlives the test.
    bootstrap.complete(_app);
    await tester.pump(_duration + SplashTiming.endedGrace);
    await tester.pump();
  });

  testWidgets('animation plays once -> shows the app once bootstrap is done', (
    tester,
  ) async {
    await _pump(tester, Future.value(_app));
    expect(
      find.byKey(const ValueKey('startup-splash-animation')),
      findsOneWidget,
    );
    expect(find.byType(Lottie), findsOneWidget);
    expect(find.byKey(_appKey), findsNothing);
    expect(_progress(tester), lessThan(1));

    await tester.pump(_duration ~/ 2);
    expect(_progress(tester), inInclusiveRange(0.3, 0.7));
    expect(find.byKey(_appKey), findsNothing);

    await tester.pump(_duration);
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('bootstrap slower than the animation -> holds the final frame, '
      'no replay', (tester) async {
    final boot = Completer<Widget>();
    await _pump(tester, boot.future);
    await tester.pump(_duration + const Duration(milliseconds: 50));
    expect(_progress(tester), 1);
    // Ten more seconds: still the final frame, never restarted.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(_appKey), findsNothing);
    expect(find.byType(Lottie), findsOneWidget);
    expect(_progress(tester), 1);

    boot.complete(_app);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('bootstrap faster than the animation -> still waits for it', (
    tester,
  ) async {
    await _pump(tester, Future.value(_app));
    await tester.pump(_duration ~/ 3);
    expect(find.byKey(_appKey), findsNothing);
    await tester.pump(_duration);
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('animation fails to load -> immediate fallback to bootstrap', (
    tester,
  ) async {
    await _pump(
      tester,
      Future.value(_app),
      loader: () async => throw StateError('decode'),
    );
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
    expect(find.byType(Lottie), findsNothing);
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
    await tester.pump();
    expect(find.byKey(_appKey), findsOneWidget);
  });

  testWidgets('reduced motion -> mark still, not played, no waiting', (
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

    // Bootstrap resolves long before the animation's 2.2 seconds: the app
    // shows at once, not after full playback.
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
    await tester.pump(_duration);
    await tester.pumpAndSettle();
    expect(find.text('game 42'), findsOneWidget);
    expect(find.text('home'), findsNothing);
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
      'd988e68d2781c64d15c7bb653b43fdcdc2d68a8b',
    );
    expect(
      sha('assets/Splash.mp4'),
      '9e764c856090b89be2958522a68bc0179a4fc843',
    );
  });
}
