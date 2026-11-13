import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/games_screen.dart';
import 'package:dabbler/features/explore/presentation/screens/venues_screen.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/location/presentation/widgets/city_required_sheet.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/presentation/providers/venues_with_sports_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';
import '../location/manual_location_surfaces_support.dart';

/// KAN-588 on Games and Venues: no city -> "Choose city" and "Select city";
/// a city -> that city's list, A to Z when only the city is known; a change of
/// city leaves nothing of the old one.

class _Loc extends ActiveLocationNotifier {
  _Loc(this.initial);
  final ActiveLocationState initial;

  @override
  Future<ActiveLocationState> build() async => initial;

  void set(ActiveLocationState s) => state = AsyncData(s);
}

const List<Sport> _sports = <Sport>[
  Sport(
    id: 's1',
    nameEn: 'Football',
    nameAr: 'كرة القدم',
    sportKey: 'football',
  ),
];

NearbyGameModel _game(String id, String title, int days) => NearbyGameModel(
  id: id,
  title: title,
  sportName: 'Football',
  scheduledAt: DateTime.now().add(Duration(days: days)),
  status: 'upcoming',
  venueName: 'Sports City',
  distanceMeters: 0,
  playerCount: 5,
  spotsRemaining: 5,
  isPublic: true,
  endAt: DateTime.now().add(Duration(days: days, hours: 1)),
);

VenueWithSportModel _venue(String id, String name, String city) =>
    VenueWithSportModel(
      id: id,
      sportId: 's1',
      nameEn: name,
      city: city,
      isIndoor: true,
      pricePerHour: 100,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  ActiveLocationState location, {
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeLocationProvider.overrideWith(() => _Loc(location)),
        activeChallengeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        activeSportsByProfileCountryProvider.overrideWith(
          (ref) async => _sports,
        ),
        myPinnedGamesProvider.overrideWith(
          (ref, sportId) async => const <NearbyGameModel>[],
        ),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: const Locale('en'),
        ),
        home: screen,
      ),
    ),
  );
  await frames(tester);
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  group('Games', () {
    testWidgets('no city: Choose city, and Select city opens the city picker', (
      tester,
    ) async {
      installGeo(asked: false);
      await _pump(tester, const GamesScreen(), ActiveLocationDenied());
      expect(find.text('Choose city'), findsOneWidget);
      expect(find.text('Select city'), findsOneWidget);

      await tester.tap(find.text('Select city'));
      await frames(tester);
      expect(find.byType(CityRequiredSheet), findsOneWidget);
    }, variant: desktop);

    testWidgets('only a city: that city\'s games, A to Z, no point sent', (
      tester,
    ) async {
      installGeo();
      final calls = <NearbyGamesParams>[];
      await _pump(
        tester,
        const GamesScreen(),
        ActiveLocationCityOnly('Dubai', country: 'AE'),
        overrides: [
          nearbyGamesProvider.overrideWith((ref, params) async {
            calls.add(params);
            return [
              _game('g1', 'Zumba night', 1),
              _game('g2', 'Aikido kids', 2),
            ];
          }),
        ],
      );
      expect(calls, isNotEmpty);
      expect(calls.first.city?.name, 'Dubai');
      expect(calls.first.lat, isNull);
      expect(calls.first.lng, isNull);
      expect(calls.first.radiusMeters, isNull);
      final aikido = tester.getTopLeft(find.text('Aikido kids')).dy;
      final zumba = tester.getTopLeft(find.text('Zumba night')).dy;
      expect(aikido, lessThan(zumba));
    }, variant: desktop);

    testWidgets('a change of city shows none of the old city\'s games', (
      tester,
    ) async {
      installGeo();
      await _pump(
        tester,
        const GamesScreen(),
        ActiveLocationCityOnly('Dubai', country: 'AE'),
        overrides: [
          nearbyGamesProvider.overrideWith((ref, params) async {
            return params.city?.name == 'Dubai'
                ? [_game('g1', 'Dubai only game', 1)]
                : [_game('g2', 'Doha only game', 1)];
          }),
        ],
      );
      expect(find.text('Dubai only game'), findsOneWidget);

      final c = ProviderScope.containerOf(
        tester.element(find.byType(GamesScreen)),
      );
      (c.read(activeLocationProvider.notifier) as _Loc).set(
        ActiveLocationCityOnly('Doha', country: 'QA'),
      );
      await frames(tester);
      expect(find.text('Dubai only game'), findsNothing);
      expect(find.text('Doha only game'), findsOneWidget);
    }, variant: desktop);
  });

  testWidgets('a change of city keeps the filters the viewer applied', (
    tester,
  ) async {
    installGeo();
    await _pump(
      tester,
      const GamesScreen(),
      ActiveLocationCityOnly('Dubai', country: 'AE'),
      overrides: [nearbyGamesProvider.overrideWith((ref, params) async => [])],
    );
    final c = ProviderScope.containerOf(
      tester.element(find.byType(GamesScreen)),
    );
    c.read(gamesDateFilterProvider.notifier).state = GamesDateFilter.thisWeek;
    c.read(gamesSkillFilterProvider.notifier).state = GamesSkillFilter.beginner;
    (c.read(activeLocationProvider.notifier) as _Loc).set(
      ActiveLocationCityOnly('Doha', country: 'QA'),
    );
    await frames(tester);
    expect(c.read(gamesDateFilterProvider), GamesDateFilter.thisWeek);
    expect(c.read(gamesSkillFilterProvider), GamesSkillFilter.beginner);
  }, variant: desktop);

  group('Venues', () {
    testWidgets('no city: Choose city and Select city', (tester) async {
      installGeo(asked: false);
      await _pump(tester, const VenuesScreen(), ActiveLocationDenied());
      expect(find.text('Choose city'), findsOneWidget);
      expect(find.text('Select city'), findsOneWidget);
    }, variant: desktop);

    testWidgets('only a city: the query is that city\'s, no point', (
      tester,
    ) async {
      installGeo();
      final asked = <VenuesBySportFilters>[];
      await _pump(
        tester,
        const VenuesScreen(),
        ActiveLocationCityOnly('Dubai', country: 'AE'),
        overrides: [
          venuesBySportWithFiltersProvider.overrideWith((ref, f) async {
            asked.add(f);
            return [
              _venue('v1', 'Zayed Indoor Arena', 'Dubai'),
              _venue('v2', 'Al Quoz Courts', 'Dubai'),
            ];
          }),
        ],
      );
      expect(asked, isNotEmpty);
      expect(asked.first.city, 'Dubai');
      expect(find.text('Zayed Indoor Arena'), findsOneWidget);
    }, variant: desktop);

    testWidgets('a change of city asks for the new city', (tester) async {
      installGeo();
      final asked = <String?>[];
      await _pump(
        tester,
        const VenuesScreen(),
        ActiveLocationCityOnly('Dubai', country: 'AE'),
        overrides: [
          venuesBySportWithFiltersProvider.overrideWith((ref, f) async {
            asked.add(f.city);
            return [_venue('v-${f.city}', 'Venue of ${f.city}', f.city ?? '')];
          }),
        ],
      );
      expect(find.text('Venue of Dubai'), findsOneWidget);
      final c = ProviderScope.containerOf(
        tester.element(find.byType(VenuesScreen)),
      );
      (c.read(activeLocationProvider.notifier) as _Loc).set(
        ActiveLocationCityOnly('Doha', country: 'QA'),
      );
      await frames(tester);
      expect(asked.last, 'Doha');
      expect(find.text('Venue of Dubai'), findsNothing);
      expect(find.text('Venue of Doha'), findsOneWidget);
    }, variant: desktop);
  });
}
