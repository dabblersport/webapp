import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/auth_onboarding/presentation/screens/location_intro_screen.dart';
import 'package:dabbler/features/location/location_intro/location_intro.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-489: the location introduction. The OS prompt is requested ONLY by the
/// "Use my location" tap. Renders: `--dart-define=LOCATION_INTRO_DIR=<dir>`
/// (`RENDER_DARK=1` for dark).
const String _dir = String.fromEnvironment('LOCATION_INTRO_DIR');
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

class FakeGateway implements LocationPermissionGateway {
  FakeGateway({
    this.current = LocationPermission.denied,
    this.afterRequest = LocationPermission.whileInUse,
    this.services = true,
  });

  LocationPermission current;
  LocationPermission afterRequest;
  bool services;
  int requests = 0;
  int checks = 0;
  int appSettings = 0;
  int locationSettings = 0;

  @override
  Future<LocationPermission> check() async {
    checks++;
    return current;
  }

  @override
  Future<LocationPermission> request() async {
    requests++;
    current = afterRequest;
    return current;
  }

  @override
  Future<bool> servicesEnabled() async => services;

  @override
  Future<bool> openAppSettings() async {
    appSettings++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettings++;
    return true;
  }
}

LocationIntroController _controller(
  FakeGateway g, {
  bool lookupOk = true,
  void Function()? onLookup,
}) => LocationIntroController(g, () async {
  onLookup?.call();
  return lookupOk;
});

Future<void> _shoot(WidgetTester tester, String name) async {
  if (_dir.isEmpty) return;
  await tester.runAsync(() async {
    final b =
        tester.renderObject(find.byKey(const Key('shot')))
            as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_dir).createSync(recursive: true);
    File('$_dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _pump(
  WidgetTester tester,
  FakeGateway gateway,
  Locale locale, {
  VoidCallback? onFinish,
  String? userId = 'user-1',
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationPermissionGatewayProvider.overrideWithValue(gateway),
        locationIntroControllerProvider.overrideWith(
          (ref) => LocationIntroController(gateway, () async => true),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            RepaintBoundary(key: const Key('shot'), child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: LocationIntroScreen(userId: userId, onFinish: onFinish),
      ),
    ),
  );
  // Let the bundled artwork decode before the frame is captured.
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage(LocationIntroScreen.artAsset),
      tester.element(find.byType(LocationIntroScreen)),
    );
  });
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('eligibility (reads the permission, never requests it)', () {
    final store = const LocationIntroStore();

    test('shown once per user, then never again', () async {
      final g = FakeGateway();
      expect(
        await shouldShowLocationIntro(userId: 'a', gateway: g, store: store),
        isTrue,
      );
      await store.markSeen('a');
      expect(
        await shouldShowLocationIntro(userId: 'a', gateway: g, store: store),
        isFalse,
      );
      // Another account on the same device has its own flag.
      expect(
        await shouldShowLocationIntro(userId: 'b', gateway: g, store: store),
        isTrue,
      );
      expect(g.requests, 0);
    });

    test('skipped when the permission is already granted', () async {
      for (final p in [
        LocationPermission.whileInUse,
        LocationPermission.always,
      ]) {
        final g = FakeGateway(current: p);
        expect(
          await shouldShowLocationIntro(userId: 'a', gateway: g, store: store),
          isFalse,
        );
        expect(g.requests, 0);
      }
    });

    test('not for a signed-out user', () async {
      expect(
        await shouldShowLocationIntro(
          userId: null,
          gateway: FakeGateway(),
          store: store,
        ),
        isFalse,
      );
    });

    test('shown after a previous denial (never asked automatically)', () async {
      final g = FakeGateway(current: LocationPermission.deniedForever);
      expect(
        await shouldShowLocationIntro(userId: 'a', gateway: g, store: store),
        isTrue,
      );
      expect(g.requests, 0);
    });
  });

  group('controller', () {
    test('starts idle and asks nothing', () {
      final g = FakeGateway();
      final c = _controller(g);
      expect(c.state.phase, LocationIntroPhase.idle);
      expect(g.requests, 0);
    });

    test('Use my location: prompts once, then looks up and finishes', () async {
      final g = FakeGateway();
      var looked = 0;
      final c = _controller(g, onLookup: () => looked++);
      await c.useMyLocation();
      expect(g.requests, 1);
      expect(looked, 1);
      expect(c.state.phase, LocationIntroPhase.done);
    });

    test('denied at the prompt: guidance, no second prompt', () async {
      final g = FakeGateway(afterRequest: LocationPermission.denied);
      final c = _controller(g);
      await c.useMyLocation();
      expect(c.state.phase, LocationIntroPhase.denied);
      expect(g.requests, 1);
    });

    test('permanently denied: no prompt, settings offered', () async {
      final g = FakeGateway(current: LocationPermission.deniedForever);
      final c = _controller(g);
      await c.useMyLocation();
      expect(c.state.phase, LocationIntroPhase.deniedForever);
      expect(c.state.canOpenSettings, isTrue);
      expect(g.requests, 0);
      await c.openSettings();
      expect(g.appSettings, 1);
    });

    test('services off: no prompt, location settings offered', () async {
      final g = FakeGateway(services: false);
      final c = _controller(g);
      await c.useMyLocation();
      expect(c.state.phase, LocationIntroPhase.serviceOff);
      expect(g.requests, 0);
      await c.openSettings();
      expect(g.locationSettings, 1);
    });

    test('granted but no position: guidance, user can still skip', () async {
      final g = FakeGateway();
      final c = _controller(g, lookupOk: false);
      await c.useMyLocation();
      expect(c.state.phase, LocationIntroPhase.lookupFailed);
    });

    test('returning from settings re-checks without requesting', () async {
      final g = FakeGateway(current: LocationPermission.deniedForever);
      final c = _controller(g);
      await c.useMyLocation();
      // Still blocked: guidance stays.
      await c.recheckAfterSettings();
      expect(c.state.phase, LocationIntroPhase.deniedForever);
      // Enabled in settings: finishes.
      g.current = LocationPermission.whileInUse;
      await c.recheckAfterSettings();
      expect(c.state.phase, LocationIntroPhase.done);
      expect(g.requests, 0);
    });

    test('a second tap while working is ignored', () async {
      final g = FakeGateway();
      final c = _controller(g);
      await Future.wait([c.useMyLocation(), c.useMyLocation()]);
      expect(g.requests, 1);
    });
  });

  final String mode = _dark ? 'dark' : 'light';
  for (final (String dir, Locale locale) in <(String, Locale)>[
    ('en', const Locale('en')),
    ('ar', const Locale('ar')),
  ]) {
    final l = lookupAppLocalizations(locale);

    testWidgets('intro screen: copy, no prompt on show, Maybe later - $dir', (
      tester,
    ) async {
      final g = FakeGateway();
      var finished = 0;
      await _pump(tester, g, locale, onFinish: () => finished++);
      expect(find.text(l.location_intro_headline), findsOneWidget);
      expect(find.text(l.location_intro_body), findsOneWidget);
      expect(find.text(l.location_intro_cta), findsOneWidget);
      expect(find.text(l.location_intro_later), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(g.requests, 0, reason: 'showing the page must not prompt');
      // Presented: recorded for this user.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(await const LocationIntroStore().seen('user-1'), isTrue);
      await _shoot(tester, 'intro-$dir-$mode');

      await tester.tap(find.text(l.location_intro_later));
      await tester.pump();
      expect(finished, 1);
      expect(g.requests, 0, reason: 'Maybe later must not prompt');
    });

    testWidgets(
      'intro screen: Use my location prompts, then continues - $dir',
      (tester) async {
        final g = FakeGateway();
        var finished = 0;
        await _pump(tester, g, locale, onFinish: () => finished++);
        await tester.tap(find.text(l.location_intro_cta));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(g.requests, 1);
        expect(finished, 1);
      },
    );

    testWidgets('intro screen: denied guidance keeps Maybe later - $dir', (
      tester,
    ) async {
      final g = FakeGateway(afterRequest: LocationPermission.denied);
      var finished = 0;
      await _pump(tester, g, locale, onFinish: () => finished++);
      await tester.tap(find.text(l.location_intro_cta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(l.location_intro_denied), findsOneWidget);
      expect(finished, 0);
      await _shoot(tester, 'denied-$dir-$mode');
      await tester.tap(find.text(l.location_intro_later));
      await tester.pump();
      expect(finished, 1);
      expect(g.requests, 1);
    });

    testWidgets('intro screen: blocked offers settings - $dir', (tester) async {
      final g = FakeGateway(current: LocationPermission.deniedForever);
      await _pump(tester, g, locale, onFinish: () {});
      await tester.tap(find.text(l.location_intro_cta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(l.location_intro_denied_forever), findsOneWidget);
      expect(find.text(l.location_intro_open_settings), findsOneWidget);
      await _shoot(tester, 'blocked-$dir-$mode');
      await tester.tap(find.text(l.location_intro_open_settings));
      await tester.pump();
      expect(g.appSettings, 1);
      expect(g.requests, 0);
    });

    testWidgets('intro screen: services off - $dir', (tester) async {
      final g = FakeGateway(services: false);
      await _pump(tester, g, locale, onFinish: () {});
      await tester.tap(find.text(l.location_intro_cta));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(l.location_intro_service_off), findsOneWidget);
      await _shoot(tester, 'service-off-$dir-$mode');
    });
  }

  test('copy matches the approved English text exactly', () {
    final l = lookupAppLocalizations(const Locale('en'));
    expect(l.location_intro_headline, 'See what’s playing nearby.');
    expect(
      l.location_intro_body,
      'Your location is used to show nearby games and venues. '
      'Turn it on and we’ll keep things local.',
    );
    expect(l.location_intro_cta, 'Use my location');
    expect(l.location_intro_later, 'Maybe later');
  });

  test('supplied artwork bytes are preserved in the bundled PNG copy', () {
    final a = File('assets/images/Location.md').readAsBytesSync();
    final b = File('assets/images/location_intro.png').readAsBytesSync();
    expect(a, b);
  });

  test('background location init never prompts (source guard)', () {
    final s = File(
      'lib/features/location/providers/active_location_provider.dart',
    ).readAsStringSync();
    expect(
      RegExp(
        r'getCurrentLocation\(requestPermission: false\)',
      ).allMatches(s).length,
      2,
    );
  });
}
