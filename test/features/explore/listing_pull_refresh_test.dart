import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/features/location/providers/listing_city.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/explore/presentation/screens/games_screen.dart';
import 'package:dabbler/features/explore/presentation/screens/venues_screen.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_refresh.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_filters.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_providers.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetups_screen.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
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
import '../meetups/meetup_screens_harness.dart';

/// KAN-598: the feed's pull-to-refresh (DabblerRefresh) on the Games, Venues
/// and Meetups listings: short, empty and failed lists refresh; the refresh
/// waits for the real query and dismisses the loader on success or error;
/// an active filter survives (asserted on Games); one refresh runs at a time
/// (asserted on the runner).

const List<Sport> _sports = <Sport>[
  Sport(
    id: 's1',
    nameEn: 'Football',
    nameAr: 'كرة القدم',
    sportKey: 'football',
  ),
  Sport(id: 's2', nameEn: 'Padel', nameAr: 'بادل', sportKey: 'padel'),
];

NearbyGameModel _game(String id, String title) => NearbyGameModel(
  id: id,
  title: title,
  sportName: 'Football',
  scheduledAt: DateTime.now().add(const Duration(days: 1)),
  status: 'upcoming',
  venueName: 'Dubai Sports City',
  distanceMeters: 3100,
  playerCount: 7,
  spotsRemaining: 3,
  isPublic: true,
);

VenueWithSportModel _venue(String id, String name) => VenueWithSportModel(
  id: id,
  sportId: 's1',
  nameEn: name,
  city: 'Dubai',
  isIndoor: false,
  pricePerHour: 180,
);

class _Denied extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationCityOnly('Dubai');
}

class _Ready extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    ActiveLocation(
      lat: 25.2,
      lng: 55.3,
      area: const Area(
        id: 'a1',
        name: 'Al Barsha',
        district: 'Dubai',
        city: 'Dubai',
        country: 'AE',
        centerLat: 25.2,
        centerLng: 55.3,
      ),
      source: ActiveLocationSource.manual,
    ),
  );
}

/// A data source the test steers: how many times it was queried, what it
/// answers next, and an optional gate it holds the answer behind.
class _Source<T> {
  int calls = 0;
  Object? failure;
  List<T> rows = <T>[];
  Completer<void>? gate;

  Future<List<T>> fetch() async {
    calls++;
    await gate?.future;
    if (failure != null) throw failure!;
    return List<T>.of(rows);
  }
}

Future<void> _mount(
  WidgetTester tester,
  Widget home,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const Locale locale = Locale('en');
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(ThemeData.light()),
          locale: locale,
        ),
        home: home,
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The listing's vertical scrollable (the tab rails scroll sideways).
Finder get _list =>
    find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical);

Future<void> _pull(WidgetTester tester) async {
  await tester.drag(_list.first, const Offset(0, 340));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

bool get _loaderShown =>
    find.byKey(DabblerRefresh.indicatorKey).evaluate().isNotEmpty;

/// Lets the gated query answer, then runs the settle beat out.
Future<void> _release(WidgetTester tester, _Source<Object?> source) async {
  source.gate?.complete();
  source.gate = null;
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  // The pull is a touch drag: run it under Android's clamping and iOS's
  // bouncing scroll physics as well as the desktop web's (the engine-level
  // device behaviour itself is not executed here; see the ticket report).
  final desktop = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  });

  // ---------------------------------------------------------------- Games --
  group('Games', () {
    List<Override> overrides(_Source<NearbyGameModel> games) => [
      activeLocationProvider.overrideWith(_Denied.new),
      activeChallengeSportsByProfileCountryProvider.overrideWith(
        (ref) async => _sports,
      ),
      activeSportsByProfileCountryProvider.overrideWith((ref) async => _sports),
      nearbyGamesProvider.overrideWith((ref, params) => games.fetch()),
      myPinnedGamesProvider.overrideWith(
        (ref, sportId) async => const <NearbyGameModel>[],
      ),
    ];

    testWidgets('a short list refreshes: re-queries, loader turns while the '
        'query runs, is gone after, filters kept', (tester) async {
      final games = _Source<NearbyGameModel>()
        ..rows = [_game('g1', 'Only game')];
      await _mount(tester, const GamesScreen(), overrides(games));
      expect(find.text('Only game'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GamesScreen)),
      );
      // An active, non-default filter: Nearest sort. A refresh must not reset it.
      container.read(nearbyGameSortProvider.notifier).state =
          NearbySortOrder.nearest;
      await _settle(tester);
      final callsBefore = games.calls;

      games.gate = Completer<void>();
      games.rows = [_game('g1', 'Only game'), _game('g2', 'New game')];
      await _pull(tester);
      expect(games.calls, greaterThan(callsBefore)); // the current data source
      expect(_loaderShown, isTrue); // turning while the query is pending
      await _release(tester, games);
      expect(_loaderShown, isFalse);
      expect(find.text('New game'), findsOneWidget);
      expect(find.text('Only game'), findsOneWidget); // no duplicate card
      expect(
        container.read(nearbyGameSortProvider),
        NearbySortOrder.nearest,
      ); // the active filter survived the refresh
    }, variant: desktop);

    testWidgets(
      'an empty list refreshes and shows what the query now returns',
      (tester) async {
        final games = _Source<NearbyGameModel>();
        await _mount(tester, const GamesScreen(), overrides(games));
        expect(find.text('Tuesday'), findsNothing);
        games.gate = Completer<void>();
        games.rows = [_game('g9', 'Late game')];
        await _pull(tester);
        expect(_loaderShown, isTrue);
        await _release(tester, games);
        expect(_loaderShown, isFalse);
        expect(find.text('Late game'), findsOneWidget);
      },
      variant: desktop,
    );

    testWidgets('a failed list refreshes; a failing refresh dismisses the '
        'loader and keeps the error', (tester) async {
      final games = _Source<NearbyGameModel>()..failure = Exception('boom');
      await _mount(tester, const GamesScreen(), overrides(games));
      expect(find.byType(DabblerEmptyState), findsOneWidget); // the error
      // Still failing: loader turns, then is dismissed, error stays.
      games.gate = Completer<void>();
      await _pull(tester);
      expect(_loaderShown, isTrue);
      await _release(tester, games);
      expect(_loaderShown, isFalse);
      expect(find.byType(DabblerEmptyState), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Recovered: the next pull shows the list.
      games.failure = null;
      games.rows = [_game('g1', 'Back again')];
      await _pull(tester);
      await _release(tester, games);
      expect(find.text('Back again'), findsOneWidget);
    }, variant: desktop);
  });

  // --------------------------------------------------------------- Venues --
  group('Venues', () {
    List<Override> overrides(_Source<VenueWithSportModel> venues) => [
      activeLocationProvider.overrideWith(_Denied.new),
      activeSportsByProfileCountryProvider.overrideWith((ref) async => _sports),
      venuesBySportWithFiltersProvider.overrideWith((ref, f) => venues.fetch()),
    ];

    testWidgets('a short list refreshes and waits for the query', (
      tester,
    ) async {
      final venues = _Source<VenueWithSportModel>()
        ..rows = [_venue('v1', 'Pitch One')];
      await _mount(tester, const VenuesScreen(), overrides(venues));
      expect(find.text('Pitch One'), findsOneWidget);
      final before = venues.calls;
      venues.gate = Completer<void>();
      venues.rows = [_venue('v1', 'Pitch One'), _venue('v2', 'Pitch Two')];
      await _pull(tester);
      expect(venues.calls, greaterThan(before));
      expect(_loaderShown, isTrue);
      await _release(tester, venues);
      expect(_loaderShown, isFalse);
      expect(find.text('Pitch Two'), findsOneWidget);
      expect(find.text('Pitch One'), findsOneWidget);
    }, variant: desktop);

    testWidgets('an empty list refreshes', (tester) async {
      final venues = _Source<VenueWithSportModel>();
      await _mount(tester, const VenuesScreen(), overrides(venues));
      venues.gate = Completer<void>();
      venues.rows = [_venue('v3', 'Fresh Court')];
      await _pull(tester);
      expect(_loaderShown, isTrue);
      await _release(tester, venues);
      expect(_loaderShown, isFalse);
      expect(find.text('Fresh Court'), findsOneWidget);
    }, variant: desktop);

    testWidgets('a failing refresh dismisses the loader', (tester) async {
      final venues = _Source<VenueWithSportModel>()
        ..failure = Exception('boom');
      await _mount(tester, const VenuesScreen(), overrides(venues));
      venues.gate = Completer<void>();
      await _pull(tester);
      expect(_loaderShown, isTrue);
      await _release(tester, venues);
      expect(_loaderShown, isFalse);
      expect(find.byType(DabblerEmptyState), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: desktop);
  });

  // -------------------------------------------------------------- Meetups --
  group('Meetups', () {
    final DateTime now = DateTime(2030, 1, 15, 12);

    MeetupListItem row(String id, String title) => meetupRow(
      id,
      title: title,
      startsIn: const Duration(days: 1),
      anchor: now,
      going: 5,
      faces: const <MeetupAvatar>[],
    );

    List<Override> overrides(_CountingRepo repo) => [
      meetupRepositoryProvider.overrideWithValue(repo),
      meetupClockProvider.overrideWithValue(() => now),
      activePersonaProvider.overrideWithValue(PersonaType.player),
      activeLocationProvider.overrideWith(_Ready.new),
      listingCityAreaIdsProvider.overrideWith(
        (ref, city) async => <String>['a1'],
      ),
      myProfileIdProvider.overrideWith((ref) async => 'me'),
    ];

    Widget screen() => const DabblerPage(body: MeetupsScreen());

    testWidgets('a short list refreshes and waits for the query', (
      tester,
    ) async {
      final repo = _CountingRepo()..list = [row('m1', 'Sunrise run')];
      await _mount(tester, screen(), overrides(repo));
      expect(find.text('Sunrise run'), findsOneWidget);
      final before = repo.fetches;
      repo.listGate = Completer<void>();
      repo.list = [row('m1', 'Sunrise run'), row('m2', 'Evening yoga')];
      await _pull(tester);
      expect(repo.fetches, greaterThan(before));
      expect(_loaderShown, isTrue);
      repo.listGate!.complete();
      repo.listGate = null;
      await _settle(tester);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_loaderShown, isFalse);
      expect(find.text('Evening yoga'), findsOneWidget);
      expect(find.text('Sunrise run'), findsOneWidget);
    }, variant: desktop);

    testWidgets('an empty list refreshes', (tester) async {
      final repo = _CountingRepo();
      await _mount(tester, screen(), overrides(repo));
      repo.listGate = Completer<void>();
      repo.list = [row('m3', 'Late meetup')];
      await _pull(tester);
      expect(_loaderShown, isTrue);
      repo.listGate!.complete();
      repo.listGate = null;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_loaderShown, isFalse);
      expect(find.text('Late meetup'), findsOneWidget);
    }, variant: desktop);

    testWidgets('a failing refresh dismisses the loader', (tester) async {
      final repo = _CountingRepo()..listError = 'boom';
      await _mount(tester, screen(), overrides(repo));
      repo.listGate = Completer<void>();
      await _pull(tester);
      expect(_loaderShown, isTrue);
      repo.listGate!.complete();
      repo.listGate = null;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_loaderShown, isFalse);
      expect(find.byType(DabblerEmptyState), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: desktop);
  });

  // ---------------------------------------------------------- the runner --
  group('ListingRefresher', () {
    test(
      'a refresh requested while one runs joins it: one query, one run',
      () async {
        final refresher = ListingRefresher();
        final gate = Completer<void>();
        var runs = 0;
        Future<void> body() async {
          runs++;
          await gate.future;
        }

        final a = refresher.run(body);
        final b = refresher.run(body);
        expect(identical(a, b), isTrue);
        gate.complete();
        await Future.wait(<Future<void>>[a, b]);
        expect(runs, 1);
        await refresher.run(body); // the next pull runs again
        expect(runs, 2);
      },
    );

    test(
      'an error never escapes the pull gesture and frees the slot',
      () async {
        final refresher = ListingRefresher();
        await refresher.run(() async => throw StateError('boom')); // no throw
        var ran = false;
        await refresher.run(() async => ran = true);
        expect(ran, isTrue);
      },
    );
  });
}

/// Counts list queries.
class _CountingRepo extends FakeMeetupRepository {
  int fetches = 0;

  @override
  Future<Result<List<MeetupListItem>, Failure>> fetchMeetups({
    String? sportId,
    int limit = 20,
    int offset = 0,
  }) {
    fetches++;
    return super.fetchMeetups(sportId: sportId, limit: limit, offset: offset);
  }
}
