import 'dart:async';

import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
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

/// KAN-606: a failed refresh never replaces a populated Games, Venues or
/// Meetups listing with the error answer. The rows stay, the active filter
/// stays, and a transient toast says the refresh failed; the error answer is
/// only for a list with nothing to show. The pinned games section never reads
/// a failed fetch as "no games".

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
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
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

/// Lets the gated query answer, then runs the settle beat out.
Future<void> _release(WidgetTester tester, _Source<Object?> source) async {
  source.gate?.complete();
  source.gate = null;
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String get _refreshFailed =>
    lookupAppLocalizations(const Locale('en')).offline_refresh_failed;

String get _gamesFailed =>
    lookupAppLocalizations(const Locale('en')).listing_load_games_failed;

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  // ---------------------------------------------------------------- Games --
  group('Games', () {
    List<Override> overrides(
      _Source<NearbyGameModel> games, [
      _Source<NearbyGameModel>? pinned,
    ]) => [
      activeLocationProvider.overrideWith(_Denied.new),
      activeChallengeSportsByProfileCountryProvider.overrideWith(
        (ref) async => _sports,
      ),
      activeSportsByProfileCountryProvider.overrideWith((ref) async => _sports),
      nearbyGamesProvider.overrideWith((ref, params) => games.fetch()),
      myPinnedGamesProvider.overrideWith(
        (ref, sportId) =>
            pinned?.fetch() ?? Future.value(const <NearbyGameModel>[]),
      ),
    ];

    testWidgets('populated + failed refresh keeps the rows and the filter, '
        'and toasts', (tester) async {
      final games = _Source<NearbyGameModel>()
        ..rows = [_game('g1', 'Kept game')];
      await _mount(tester, const GamesScreen(), overrides(games));
      expect(find.text('Kept game'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GamesScreen)),
      );
      container.read(nearbyGameSortProvider.notifier).state =
          NearbySortOrder.nearest;
      await _settle(tester);

      games.failure = Exception('offline');
      games.gate = Completer<void>();
      await _pull(tester);
      await _release(tester, games);

      expect(find.text('Kept game'), findsOneWidget);
      expect(find.text(_gamesFailed), findsNothing);
      expect(find.text(_refreshFailed), findsOneWidget);
      expect(container.read(nearbyGameSortProvider), NearbySortOrder.nearest);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty + failed load shows the error answer', (tester) async {
      final games = _Source<NearbyGameModel>()..failure = Exception('offline');
      await _mount(tester, const GamesScreen(), overrides(games));
      expect(find.text(_gamesFailed), findsOneWidget);
      expect(find.text(_refreshFailed), findsNothing);
    });

    testWidgets('a pinned fetch that fails with nothing listed is the error '
        'answer, not "no games"', (tester) async {
      final games = _Source<NearbyGameModel>();
      final pinned = _Source<NearbyGameModel>()..failure = Exception('offline');
      await _mount(tester, const GamesScreen(), overrides(games, pinned));
      final l = lookupAppLocalizations(const Locale('en'));
      expect(find.text(_gamesFailed), findsOneWidget);
      expect(find.text(l.listing_games_none_title), findsNothing);
    });

    testWidgets('a pinned refetch that fails keeps the pinned games', (
      tester,
    ) async {
      final games = _Source<NearbyGameModel>()
        ..rows = [_game('g1', 'Listed game')];
      final pinned = _Source<NearbyGameModel>()
        ..rows = [_game('p1', 'My pinned game')];
      await _mount(tester, const GamesScreen(), overrides(games, pinned));
      expect(find.text('My pinned game'), findsOneWidget);

      pinned.failure = Exception('offline');
      await _pull(tester);
      await _release(tester, pinned);

      expect(find.text('My pinned game'), findsOneWidget);
      expect(find.text('Listed game'), findsOneWidget);
      expect(find.text(_refreshFailed), findsOneWidget);
    });
  });

  // --------------------------------------------------------------- Venues --
  group('Venues', () {
    List<Override> overrides(_Source<VenueWithSportModel> venues) => [
      activeLocationProvider.overrideWith(_Denied.new),
      activeSportsByProfileCountryProvider.overrideWith((ref) async => _sports),
      venuesBySportWithFiltersProvider.overrideWith((ref, f) => venues.fetch()),
    ];

    testWidgets('populated + failed refresh keeps the rows and toasts', (
      tester,
    ) async {
      final venues = _Source<VenueWithSportModel>()
        ..rows = [_venue('v1', 'Kept Pitch')];
      await _mount(tester, const VenuesScreen(), overrides(venues));
      expect(find.text('Kept Pitch'), findsOneWidget);
      venues.failure = Exception('offline');
      venues.gate = Completer<void>();
      await _pull(tester);
      await _release(tester, venues);
      expect(find.text('Kept Pitch'), findsOneWidget);
      expect(find.text(_refreshFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty + failed load shows the error answer', (tester) async {
      final venues = _Source<VenueWithSportModel>()
        ..failure = Exception('offline');
      await _mount(tester, const VenuesScreen(), overrides(venues));
      final l = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l.listing_load_venues_failed), findsOneWidget);
    });
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

    List<Override> overrides(FakeMeetupRepository repo) => [
      meetupRepositoryProvider.overrideWithValue(repo),
      meetupClockProvider.overrideWithValue(() => now),
      activePersonaProvider.overrideWithValue(PersonaType.player),
      activeLocationProvider.overrideWith(_Ready.new),
      myProfileIdProvider.overrideWith((ref) async => 'me'),
    ];

    Widget screen() => const DabblerPage(body: MeetupsScreen());

    testWidgets('populated + failed refresh keeps the rows and toasts', (
      tester,
    ) async {
      final repo = FakeMeetupRepository()..list = [row('m1', 'Kept run')];
      await _mount(tester, screen(), overrides(repo));
      expect(find.text('Kept run'), findsOneWidget);
      repo.listError = 'offline';
      await _pull(tester);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Kept run'), findsOneWidget);
      expect(find.text(_refreshFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty + failed load shows the error answer', (tester) async {
      final repo = FakeMeetupRepository()..listError = 'offline';
      await _mount(tester, screen(), overrides(repo));
      final l = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l.meetups_load_failed), findsOneWidget);
    });
  });

  // ------------------------------------------------------------- helpers --
  group('keepsRows / refreshFailedWithRows', () {
    test('only a failure that still holds rows keeps them', () {
      const rows = AsyncValue<List<int>>.data(<int>[1]);
      final failedWithRows = const AsyncValue<List<int>>.error(
        'x',
        StackTrace.empty,
      ).copyWithPrevious(rows);
      final failedEmpty = const AsyncValue<List<int>>.error(
        'x',
        StackTrace.empty,
      ).copyWithPrevious(const AsyncValue<List<int>>.data(<int>[]));
      const failedFirst = AsyncValue<List<int>>.error('x', StackTrace.empty);

      expect(keepsRows(failedWithRows), isTrue);
      expect(refreshFailedWithRows(failedWithRows), isTrue);
      expect(keepsRows(failedEmpty), isFalse);
      expect(keepsRows(failedFirst), isFalse);
      expect(refreshFailedWithRows(rows), isFalse);
    });
  });
}
