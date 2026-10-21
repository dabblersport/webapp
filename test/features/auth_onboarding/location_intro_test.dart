import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/features/location/presentation/widgets/city_required_sheet.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/location_intro_screen.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/mapbox_geocode_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
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
  bool failChecks = false;

  @override
  Future<LocationPermission> check() async {
    checks++;
    if (failChecks) throw StateError('unreadable');
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

const Area _area = Area(
  id: 'area-1',
  name: 'Test Area',
  district: 'Test District',
  city: 'Test City',
  country: 'TC',
  centerLat: 1,
  centerLng: 2,
);

/// A GPS whose fixes the test controls. Records how it was called.
class FakeGps extends GpsService {
  FakeGps({this.lastKnown});

  LocationSuccess? lastKnown;

  /// Completes the pending fresh fix; never completed = a GPS that hangs.
  Completer<LocationResult> fresh = Completer<LocationResult>();
  final List<({bool requestPermission, Duration? cap})> calls = [];

  @override
  Future<LocationResult> getCurrentLocation({
    bool requestPermission = true,
    Duration? cap,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    calls.add((requestPermission: requestPermission, cap: cap));
    return fresh.future;
  }

  @override
  Future<LocationSuccess?> getLastKnownLocation() async => lastKnown;
}

class FakeAreas implements AreaRepository {
  @override
  Future<List<Area>> loadAll() async => const [_area];

  @override
  Future<Area?> resolveNearest(double lat, double lng) async => _area;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class NoSavedLocations extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => const [];
}

LocationIntroController _controller(
  FakeGateway g, {
  void Function()? onLookup,
}) => LocationIntroController(g, () => onLookup?.call());

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
  FakeGps? gps,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationPermissionGatewayProvider.overrideWithValue(gateway),
        gpsServiceProvider.overrideWithValue(gps ?? FakeGps()),
        areaRepositoryV2Provider.overrideWithValue(FakeAreas()),
        profileLocationNotifierProvider.overrideWith(NoSavedLocations.new),
        // KAN-587: the City step searches the map service, worldwide.
        mapboxCityProvider.overrideWith(
          (ref, q) async => q.toLowerCase().startsWith('par')
              ? const <MapboxPlace>[
                  MapboxPlace(
                    id: 'p1',
                    name: 'Paris',
                    fullAddress: 'Paris, France',
                    lat: 48.85,
                    lng: 2.35,
                  ),
                ]
              : const <MapboxPlace>[],
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => RepaintBoundary(
          key: const Key('shot'),
          child: DabblerToastProvider(child: child!),
        ),
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

  group('controller (answers at once, never waits for GPS)', () {
    test('starts idle and asks nothing', () {
      final g = FakeGateway();
      final c = _controller(g);
      expect(c.state.phase, LocationIntroPhase.idle);
      expect(g.requests, 0);
    });

    test('granted: prompts once, starts the background lookup, done', () async {
      final g = FakeGateway();
      var started = 0;
      final c = _controller(g, onLookup: () => started++);
      await c.useMyLocation();
      expect(g.requests, 1);
      expect(started, 1);
      expect(c.state.phase, LocationIntroPhase.done);
      expect(c.state.outcome, LocationIntroOutcome.granted);
    });

    test(
      'denied at the prompt: done at once, no lookup, no 2nd prompt',
      () async {
        final g = FakeGateway(afterRequest: LocationPermission.denied);
        var started = 0;
        final c = _controller(g, onLookup: () => started++);
        await c.useMyLocation();
        expect(c.state.phase, LocationIntroPhase.done);
        expect(c.state.outcome, LocationIntroOutcome.denied);
        expect(g.requests, 1);
        expect(started, 0);
      },
    );

    test('permanently denied: done at once, no prompt', () async {
      final g = FakeGateway(current: LocationPermission.deniedForever);
      final c = _controller(g);
      await c.useMyLocation();
      expect(c.state.phase, LocationIntroPhase.done);
      expect(c.state.outcome, LocationIntroOutcome.deniedForever);
      expect(g.requests, 0);
    });

    test('services off: done at once, no prompt, no lookup', () async {
      final g = FakeGateway(services: false);
      var started = 0;
      final c = _controller(g, onLookup: () => started++);
      await c.useMyLocation();
      expect(c.state.phase, LocationIntroPhase.done);
      expect(c.state.outcome, LocationIntroOutcome.serviceOff);
      expect(g.requests, 0);
      expect(started, 0);
    });

    test('an unreadable permission still finishes (never traps)', () async {
      final g = FakeGateway()..failChecks = true;
      final c = _controller(g);
      await c.useMyLocation();
      expect(c.state.phase, LocationIntroPhase.done);
      expect(c.state.outcome, LocationIntroOutcome.unavailable);
    });

    test('a lookup that throws never blocks the hand-off', () async {
      final c = LocationIntroController(FakeGateway(), () => throw 'boom');
      await c.useMyLocation();
      expect(c.state.phase, LocationIntroPhase.done);
    });

    test('a second tap while the prompt is up is ignored', () async {
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

      // KAN-587: Maybe later asks for a City first; nothing finishes without one.
      expect(find.text(l.listing_set_location), findsOneWidget);
      await tester.tap(find.text(l.location_intro_later));
      await tester.pumpAndSettle();
      expect(finished, 0, reason: 'Maybe later needs a city');
      expect(find.byType(CityRequiredSheet), findsOneWidget);
      expect(g.requests, 0, reason: 'Maybe later must not prompt');
      // A search with no match shows the empty state, and no area rows exist.
      await tester.enterText(find.byType(EditableText).last, 'zzzz');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(l.manual_location_empty_title), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, '');
      await tester.pumpAndSettle();
      // A city outside the UAE comes from the map service, with its country.
      await tester.enterText(find.byType(EditableText).last, 'par');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Paris, France'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).last, '');
      await tester.pumpAndSettle();
      // Dismissed without a city: still on the intro.
      Navigator.of(
        tester.element(find.byType(CityRequiredSheet)),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();
      expect(finished, 0);
      // Choosing a canonical city (City-only: no area, no GPS) finishes.
      await tester.tap(find.text(l.location_intro_later));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'par');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paris'));
      await tester.pumpAndSettle();
      expect(finished, 1);
      expect(g.requests, 0);
      final s = ProviderScope.containerOf(
        tester.element(find.byType(LocationIntroScreen)),
      ).read(activeLocationProvider).valueOrNull;
      expect(s, isA<ActiveLocationCityOnly>());
      expect((s as ActiveLocationCityOnly).city, 'Paris');
    });

    testWidgets('Use my location, GPS never answers: Home at once, nothing '
        'blocking - $dir', (tester) async {
      final g = FakeGateway();
      final gps = FakeGps(); // its fix never completes
      var finished = 0;
      await _pump(tester, g, locale, onFinish: () => finished++, gps: gps);
      await tester.tap(find.text(l.location_intro_cta));
      await tester.pump(); // one frame, no waiting
      await tester.pump();
      expect(g.requests, 1);
      expect(finished, 1, reason: 'continued with a GPS that never answers');
      expect(find.byType(DabblerBanner), findsNothing);
      expect(find.byType(DabblerSpinner), findsNothing);
      // No toast hint for an allowed permission.
      expect(find.text(l.location_intro_denied), findsNothing);
      await tester.pump(const Duration(seconds: 1)); // flush zero timers
    });

    for (final c
        in <(String, FakeGateway, String Function(AppLocalizations), bool)>[
          (
            'denied',
            FakeGateway(afterRequest: LocationPermission.denied),
            (l) => l.location_intro_denied,
            false,
          ),
          (
            'permanently denied',
            FakeGateway(current: LocationPermission.deniedForever),
            (l) => l.location_intro_denied_forever,
            true,
          ),
          (
            'services off',
            FakeGateway(services: false),
            (l) => l.location_intro_service_off,
            true,
          ),
        ]) {
      testWidgets('${c.$1}: Home at once with a one-time toast hint, no '
          'banner on the page - $dir', (tester) async {
        var finished = 0;
        await _pump(tester, c.$2, locale, onFinish: () => finished++);
        await tester.tap(find.text(l.location_intro_cta));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(finished, 1);
        expect(find.byType(DabblerBanner), findsNothing);
        expect(find.text(c.$3(l)), findsOneWidget, reason: 'toast hint');
        // Settings action only where the platform has settings.
        expect(
          find.text(l.location_intro_open_settings),
          c.$4 ? findsOneWidget : findsNothing,
        );
        await _shoot(tester, 'hint-${c.$1.replaceAll(' ', '-')}-$dir-$mode');
      });
    }
  }

  group('active location in the background (KAN-489 follow-up)', () {
    ProviderContainer make(FakeGps gps) {
      final c = ProviderContainer(
        overrides: [
          gpsServiceProvider.overrideWithValue(gps),
          areaRepositoryV2Provider.overrideWithValue(FakeAreas()),
          profileLocationNotifierProvider.overrideWith(NoSavedLocations.new),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    LocationSuccess fix(double lat) =>
        LocationSuccess(lat: lat, lng: 55, accuracyMeters: 20);

    test('first paint never waits for GPS: a hanging GPS leaves the build '
        'immediate', () async {
      final gps = FakeGps();
      final c = make(gps);
      final state = await c
          .read(activeLocationProvider.future)
          .timeout(const Duration(seconds: 2));
      expect(state, isNot(isA<ActiveLocationReady>()));
      // The silent attempt never prompts and is capped.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(gps.calls, isNotEmpty);
      expect(gps.calls.every((x) => !x.requestPermission), isTrue);
      expect(gps.calls.every((x) => x.cap == GpsService.fixCap), isTrue);
    });

    test('a late position updates the active location (last known first, '
        'then the fresh fix)', () async {
      final gps = FakeGps(lastKnown: fix(10));
      final c = make(gps);
      await c.read(activeLocationProvider.future);
      final adopt = c
          .read(activeLocationProvider.notifier)
          .adoptDeviceLocation();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      var s = c.read(activeLocationProvider).valueOrNull;
      expect(s, isA<ActiveLocationReady>(), reason: 'last known is applied');
      expect((s as ActiveLocationReady).location.lat, 10);
      expect(s.location.source, ActiveLocationSource.gps);
      gps.fresh.complete(fix(11));
      await adopt;
      s = c.read(activeLocationProvider).valueOrNull;
      expect((s as ActiveLocationReady).location.lat, 11);
      expect(gps.calls.last.requestPermission, isFalse, reason: 'no prompt');
      expect(gps.calls.last.cap, GpsService.fixCap);
    });

    test(
      'a fresh fix that fails or times out changes nothing visible',
      () async {
        final gps = FakeGps(lastKnown: fix(10));
        final c = make(gps);
        await c.read(activeLocationProvider.future);
        final adopt = c
            .read(activeLocationProvider.notifier)
            .adoptDeviceLocation();
        gps.fresh.complete(LocationTimeout());
        await adopt;
        final s = c.read(activeLocationProvider).valueOrNull;
        expect((s as ActiveLocationReady).location.lat, 10);
      },
    );

    test('no last known and a failed fix: the location stays unset', () async {
      final gps = FakeGps();
      final c = make(gps);
      await c.read(activeLocationProvider.future);
      final adopt = c
          .read(activeLocationProvider.notifier)
          .adoptDeviceLocation();
      gps.fresh.complete(LocationError('gps off'));
      await adopt;
      expect(
        c.read(activeLocationProvider).valueOrNull,
        isNot(isA<ActiveLocationReady>()),
      );
    });

    test('adopting does not await GPS for the caller: the call returns a '
        'future the UI path never awaits', () async {
      final gps = FakeGps(); // fresh never completes
      final c = make(gps);
      await c.read(activeLocationProvider.future);
      var completed = false;
      c
          .read(activeLocationProvider.notifier)
          .adoptDeviceLocation()
          .then((_) => completed = true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(completed, isFalse, reason: 'still waiting in the background');
    });

    test('explicit actions are capped too', () async {
      final gps = FakeGps();
      final c = make(gps);
      await c.read(activeLocationProvider.future);
      c.read(activeLocationProvider.notifier).useGpsLocation();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final explicit = gps.calls.where((x) => x.requestPermission);
      expect(explicit, hasLength(1));
      expect(explicit.single.cap, GpsService.fixCap);
    });
  });

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

  test('the supplied artwork source is unchanged and not bundled', () {
    // Location.md is the unchanged 3.5 MB source (a PNG); it stays in the repo
    // but must not ship a second time.
    final a = File('assets/images/Location.md').readAsBytesSync();
    expect(a.length, 3499368);
    expect(a.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('- assets/images/\n')));
    expect(pubspec.contains('Location.md'), isTrue, reason: 'explained once');
    expect(pubspec.contains('- assets/images/Location.md'), isFalse);
  });

  test('the bundled intro art is a small WebP of the same dimensions', () {
    final f = File('assets/images/location_intro.webp');
    final bytes = f.readAsBytesSync();
    expect(bytes.length, lessThan(400 * 1024));
    // RIFF....WEBP
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP');
    expect(File('assets/images/location_intro.png').existsSync(), isFalse);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/images/location_intro.webp'),
    );
  });

  test('background location init never prompts (source guard)', () {
    final s = File(
      'lib/features/location/providers/active_location_provider.dart',
    ).readAsStringSync();
    expect('requestPermission: false'.allMatches(s).length, 2);
  });
}
