import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/games_screen.dart';
import 'package:dabbler/features/explore/presentation/screens/venues_screen.dart';
import 'package:dabbler/features/explore/presentation/widgets/manual_location_drawer.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import '../home/home_test_harness.dart';
import '../location/manual_location_surfaces_support.dart';
import '../../support/render_mode.dart';

const String _shotsDir = String.fromEnvironment(
  'KAN526_SHOTS_DIR',
  defaultValue: '$kShotsRoot/kan526',
);
const Key _shotKey = Key('kan526-shot');

/// KAN-526 on Games and Venues (the Sports/Venues surface): denied -> the
/// "Set location" drawer, never an OS prompt.
class _Denied extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

class _Ready extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    const ActiveLocation(
      lat: 25.2,
      lng: 55.3,
      area: Area(
        id: 'a1',
        name: 'Al Barsha',
        district: 'Dubai',
        city: 'Dubai',
        country: 'AE',
        centerLat: 25.2,
        centerLng: 55.3,
      ),
      source: ActiveLocationSource.gps,
    ),
  );
}

const List<Sport> _sports = <Sport>[
  Sport(
    id: 's1',
    nameEn: 'Football',
    nameAr: 'كرة القدم',
    sportKey: 'football',
  ),
];

NearbyGameModel _game() => NearbyGameModel(
  id: 'g1',
  title: 'Friday 5-a-side',
  sportName: 'Football',
  scheduledAt: DateTime.now().add(const Duration(days: 1)),
  status: 'live',
  venueName: 'Sports City',
  distanceMeters: 800,
  playerCount: 5,
  spotsRemaining: 5,
  isPublic: true,
  endAt: DateTime.now().add(const Duration(days: 1, hours: 1)),
);

const List<VenueWithSportModel> _venues = <VenueWithSportModel>[
  VenueWithSportModel(
    id: 'v1',
    sportId: 's1',
    nameEn: 'Zayed Indoor Arena',
    city: 'Dubai',
    isIndoor: true,
    pricePerHour: 100,
  ),
];

Future<List<NearbyGamesParams>> _pump(
  WidgetTester tester,
  Widget screen, {
  bool ready = false,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = <NearbyGamesParams>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fakeCatalogOverride,
        fakeCountryOverride,
        activeLocationProvider.overrideWith(ready ? _Ready.new : _Denied.new),
        activeChallengeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        activeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        nearbyGamesFilterEnabledProvider.overrideWith((ref) => true),
        nearbyGamesProvider.overrideWith((ref, params) async {
          calls.add(params);
          return [_game()];
        }),
        myPinnedGamesProvider.overrideWith(
          (ref, sportId) async => const <NearbyGameModel>[],
        ),
        venuesBySportWithFiltersProvider.overrideWith(
          (ref, f) async => _venues,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: _shotKey, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(
            brightness == Brightness.dark
                ? ThemeData.dark()
                : renderThemeBase(),
          ),
          locale: locale,
        ),
        home: screen,
      ),
    ),
  );
  return calls;
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(_shotKey)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);
  final games = find.byType(GamesScreen);
  final venues = find.byType(VenuesScreen);

  testWidgets('Games denied: drawer once, a pick drives the nearby query', (
    tester,
  ) async {
    final fake = installGeo();
    final calls = await _pump(tester, const GamesScreen());
    await expectPickFlow(tester, fake, games);
    expect(
      calls.any((p) => p.lat == 25.1972 && p.lng == 55.2744),
      isTrue,
      reason: 'the games query runs for the chosen point',
    );
  }, variant: desktop);

  testWidgets('Games denied: dismiss keeps Set location, no loop', (
    tester,
  ) async {
    final fake = installGeo();
    await _pump(tester, const GamesScreen());
    await expectDismissFlow(tester, fake, games);
  }, variant: desktop);

  testWidgets('Games granted: no drawer', (tester) async {
    final fake = installGeo(permission: LocationPermission.whileInUse);
    await _pump(tester, const GamesScreen(), ready: true);
    await expectNoDrawer(tester, fake);
  }, variant: desktop);

  testWidgets('Venues denied: drawer once, a pick drives the surface', (
    tester,
  ) async {
    final fake = installGeo();
    await _pump(tester, const VenuesScreen());
    await expectPickFlow(tester, fake, venues);
  }, variant: desktop);

  testWidgets('Venues denied: dismiss keeps Set location, no loop', (
    tester,
  ) async {
    final fake = installGeo();
    await _pump(tester, const VenuesScreen());
    await expectDismissFlow(tester, fake, venues);
  }, variant: desktop);

  testWidgets('Venues granted: no drawer', (tester) async {
    final fake = installGeo(permission: LocationPermission.whileInUse);
    await _pump(tester, const VenuesScreen(), ready: true);
    await expectNoDrawer(tester, fake);
  }, variant: desktop);

  testWidgets('denied but the OS prompt never used: nothing opens by itself', (
    tester,
  ) async {
    final fake = installGeo(asked: false);
    await _pump(tester, const GamesScreen());
    await expectNoDrawer(tester, fake);
  }, variant: desktop);

  // Evidence: the drawer opened by itself on Games, EN/AR x light/dark.
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final b in Brightness.values) {
      final name = 'games-set-location-${locale.languageCode}-${b.name}';
      testWidgets('render $name', (tester) async {
        final fake = installGeo();
        await _pump(tester, const GamesScreen(), locale: locale, brightness: b);
        await frames(tester);
        await settleImages(tester);
        expect(find.byType(ManualLocationDrawer), findsOneWidget);
        await _shoot(tester, name);
        expect(fake.requestCalls, 0);
      }, variant: desktop);
    }
  }
}
