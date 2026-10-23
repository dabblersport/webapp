import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/providers/mapbox_geocode_provider.dart';
import 'package:dabbler/features/sports/data/sport_follow_repository.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/presentation/widgets/sport_page_link.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';
import 'sport_test_harness.dart';

const SportInfo _tennis = SportInfo(
  id: kTennis,
  nameEn: 'Tennis',
  nameAr: 'التنس',
  sportKey: 'tennis',
);

Finder _tab(String label) => find.descendant(
  of: find.byType(DabblerTabs).first,
  matching: find.text(label),
);

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(_tab(label));
  await settle(tester);
}

void main() {
  setUpAll(loadRenderFonts);

  group('AC1/AC2 route, identity, header and tabs', () {
    testWidgets('shows identity, follower count and exactly the five tabs', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);

      expect(find.text('Football'), findsWidgets);
      expect(find.text('5-a-side · 7-a-side'), findsOneWidget);
      expect(find.text('1204 followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      for (final String label in <String>[
        'Overview',
        'Games',
        'Meetups',
        'Venues',
        'Posts',
      ]) {
        expect(_tab(label), findsOneWidget, reason: label);
      }
      // No Places tab or tile, no News tab (no readable source), and none of
      // the unspecified controls is drawn as a dead button.
      expect(find.textContaining('Places'), findsNothing);
      expect(find.textContaining('Place'), findsNothing);
      expect(find.text('News'), findsNothing);
      expect(find.text('Share'), findsNothing);
      expect(find.text('More'), findsNothing);
      expect(h.repo.calls, contains('sport:$kFootball'));
    });

    testWidgets('an unfollowed sport can be browsed', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.sportResult = const Ok(_tennis);
      await pumpSport(tester, h, sportId: kTennis);
      expect(find.text('Tennis'), findsWidgets);
      expect(find.text('Follow'), findsOneWidget);
      expect(_tab('Overview'), findsOneWidget);
    });

    testWidgets('an unknown sport id shows the error state, not a crash', (
      tester,
    ) async {
      final SportHarness h = SportHarness();
      h.repo.sportResult = const Err(
        Failure(category: FailureCode.notFound, message: 'Sport not found'),
      );
      await pumpSport(tester, h, sportId: 'not-a-sport');
      expect(find.text("This sport isn't available"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(DabblerTabs), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sport page is behind the sportOverview route pattern', (
      tester,
    ) async {
      expect(RoutePaths.sportOverviewFor(kFootball), '/sport/$kFootball');
      final GoRouter router = GoRouter(
        initialLocation: RoutePaths.sportOverviewFor(kTennis),
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.sportOverview,
            builder: (_, GoRouterState s) =>
                Text('page:${s.pathParameters['sportId']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      expect(find.text('page:$kTennis'), findsOneWidget);
    });

    testWidgets('a sport tile opens the page by id, only for a known sport', (
      tester,
    ) async {
      final List<String> pushed = <String>[];
      final GoRouter router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: Column(
                children: <Widget>[
                  SportPageLink(sportName: 'Football'),
                  SportPageLink(sportName: 'Quidditch'),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/:rest(.*)',
            builder: (_, GoRouterState s) {
              pushed.add(s.uri.toString());
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
        ),
      );
      await tester.pump();
      // The unknown sport draws nothing.
      expect(find.byType(DabblerButton), findsOneWidget);
      await tester.tap(find.byType(DabblerButton));
      await tester.pumpAndSettle();
      expect(pushed, <String>['/sport/$kFootball']);
    });
  });

  group('AC3 counts and navigation', () {
    testWidgets('tiles show the RPC counts, separately for venues and spaces', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      for (final String v in <String>['3', '2', '4', '9', '17']) {
        expect(find.text(v), findsWidgets, reason: v);
      }
      expect(find.text('Venues'), findsWidgets);
      expect(find.text('Spaces'), findsOneWidget);
      expect(find.text('Games in 7 days'), findsOneWidget);
      expect(find.text('Meetups in 7 days'), findsOneWidget);
    });

    testWidgets('tapping a counter tile or See all opens that tab', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.gamesResult = Ok([game('g1')]);
      h.repo.meetupsResult = Ok([meetup('m1')]);
      await pumpSport(tester, h);

      await tester.tap(find.text('Meetups in 7 days'));
      await settle(tester);
      expect(find.text('Sunday kickabout'), findsOneWidget);

      await _openTab(tester, 'Overview');
      await tester.tap(find.text('Spaces'));
      await settle(tester);
      // Spaces side of the Venues tab: its switch is on screen.
      expect(find.text('No spaces yet'), findsOneWidget);

      await _openTab(tester, 'Overview');
      await tester.tap(find.text('See all').first);
      await settle(tester);
      expect(find.text('Friday five-a-side'), findsOneWidget);
    });

    testWidgets('a failed aggregate shows Retry, never a sample number', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.overviewResult = const Err(Failure(message: 'offline'));
      await pumpSport(tester, h);
      expect(find.text("Couldn't load this"), findsOneWidget);
      expect(find.text('Games in 7 days'), findsNothing);
      expect(find.textContaining('followers'), findsNothing);

      h.repo.overviewResult = Ok(counts(games: 5));
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('5'), findsWidgets);
      expect(find.text("Couldn't load this"), findsNothing);
    });
  });

  group('AC4 lists', () {
    testWidgets('games show real data only; a missing price is not drawn', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.gamesResult = Ok([
        game('g1', title: 'Priced game', price: 40),
        game('g2', title: 'Unpriced game'),
      ]);
      await pumpSport(tester, h);
      await _openTab(tester, 'Games');
      expect(find.text('Priced game'), findsOneWidget);
      expect(find.text('Unpriced game'), findsOneWidget);
      expect(find.textContaining('40'), findsWidgets);
      // The unpriced game draws no price at all: not "Free", not "Ask".
      expect(find.text('Ask'), findsNothing);
      expect(find.text('Free'), findsNothing);
      expect(find.text('Al Wasl Club'), findsWidgets);
    });

    testWidgets('a game opens the real detail route', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.gamesResult = Ok([game('g1', title: 'Priced game')]);
      await pumpSport(tester, h);
      await _openTab(tester, 'Games');
      await tester.tap(find.text('Priced game'));
      await settle(tester);
      expect(h.pushed, contains(RoutePaths.gameDetail('g1')));
    });

    testWidgets('a meetup opens the real detail route', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.meetupsResult = Ok([meetup('m1')]);
      await pumpSport(tester, h);
      await _openTab(tester, 'Meetups');
      await tester.tap(find.text('Sunday kickabout'));
      await settle(tester);
      expect(h.pushed, contains(RoutePaths.meetupDetail('m1')));
    });

    testWidgets('empty states are per section', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      await _openTab(tester, 'Games');
      expect(find.text('No games in the next 7 days'), findsOneWidget);
      await _openTab(tester, 'Meetups');
      expect(find.text('No meetups in the next 7 days'), findsOneWidget);
      await _openTab(tester, 'Venues');
      expect(find.text('No venues yet'), findsOneWidget);
    });

    testWidgets('a failing list shows error with Retry and recovers', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.gamesResult = const Err(Failure(message: 'offline'));
      await pumpSport(tester, h);
      await _openTab(tester, 'Games');
      expect(find.text("Couldn't load this"), findsOneWidget);
      expect(find.text('No games in the next 7 days'), findsNothing);

      h.repo.gamesResult = Ok([game('g1', title: 'Back online')]);
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Back online'), findsOneWidget);
    });

    testWidgets('Venues and Spaces are separate lists behind a switch', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.venuesResult = const Ok(<SportVenue>[
        SportVenue(
          id: 'v1',
          nameEn: 'Rated Arena',
          areaName: 'Marina',
          rating: 4.6,
        ),
        SportVenue(id: 'v2', nameEn: 'Unrated Hall'),
      ]);
      h.repo.spacesResult = const Ok(<SportSpace>[
        SportSpace(
          id: 's1',
          venueId: 'v1',
          nameEn: 'Court 1',
          venueNameEn: 'Rated Arena',
          pricePerHour: 120,
          capacity: 10,
        ),
        SportSpace(
          id: 's2',
          venueId: 'v2',
          nameEn: 'Court 2',
          venueNameEn: 'Unrated Hall',
        ),
      ]);
      await pumpSport(tester, h);
      await _openTab(tester, 'Venues');

      expect(find.text('Rated Arena'), findsOneWidget);
      expect(find.text('Unrated Hall'), findsOneWidget);
      expect(find.text('Court 1'), findsNothing);
      expect(find.text('4.6'), findsOneWidget);
      // A venue without a rating draws none (not 0.0).
      expect(find.text('0.0'), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byType(DabblerTabs).last,
          matching: find.text('Spaces'),
        ),
      );
      await settle(tester);
      expect(find.text('Court 1'), findsOneWidget);
      expect(find.text('Court 2'), findsOneWidget);
      expect(find.text('Rated Arena'), findsOneWidget);
      expect(find.text('120 AED / hour'), findsOneWidget);
      expect(find.textContaining('AED'), findsOneWidget);
      expect(find.text('Unrated Hall'), findsOneWidget);
    });
  });

  group('AC5 posts', () {
    testWidgets('lists the sport posts without the Following filter', (
      tester,
    ) async {
      // The viewer follows Football only; Tennis posts still list.
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.sportResult = const Ok(_tennis);
      h.repo.postIdsResult = const Ok(<String>['p1', 'p2']);
      h.postsToReturn = [
        post('p1', body: 'Tennis post one'),
        post('p2', body: 'Tennis post two'),
      ];
      await pumpSport(tester, h, sportId: kTennis);
      await _openTab(tester, 'Posts');
      expect(find.text('Tennis post one'), findsOneWidget);
      expect(find.text('Tennis post two'), findsOneWidget);
      expect(h.repo.calls, contains('postIds:$kTennis:0'));
    });

    testWidgets('posts keep the order the query gave, newest first', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.postIdsResult = const Ok(<String>['new', 'old']);
      // The fetcher answers in the opposite order.
      h.postsToReturn = [
        post('old', body: 'Older post'),
        post('new', body: 'Newer post'),
      ];
      await pumpSport(tester, h);
      await _openTab(tester, 'Posts');
      final double newer = tester.getTopLeft(find.text('Newer post')).dy;
      final double older = tester.getTopLeft(find.text('Older post')).dy;
      expect(newer, lessThan(older));
    });

    testWidgets('empty posts show the empty state', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      await _openTab(tester, 'Posts');
      expect(find.text('No posts yet'), findsOneWidget);
    });

    testWidgets('a failing feed shows Retry and does not apply a filter', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.postIdsResult = const Err(Failure(message: 'offline'));
      await pumpSport(tester, h);
      await _openTab(tester, 'Posts');
      expect(find.text("Couldn't load this"), findsOneWidget);
      h.repo.postIdsResult = const Ok(<String>['p1']);
      h.postsToReturn = [post('p1', body: 'Recovered post')];
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Recovered post'), findsOneWidget);
    });
  });

  group('AC6 Follow control', () {
    testWidgets('Follow adds to Following; no sport profile is created', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.sportResult = const Ok(_tennis);
      h.profile.interestsOnRefresh = <String>[kFootball, kTennis];
      await pumpSport(tester, h, sportId: kTennis);
      expect(find.text('Follow'), findsOneWidget);

      await tester.tap(find.text('Follow'));
      await settle(tester);
      expect(h.follow.follows, <String>['me:$kTennis']);
      expect(find.text('Following'), findsOneWidget);
      expect(h.repo.createdProfiles, isEmpty);
      expect(h.follow.unfollows, isEmpty);
    });

    testWidgets('Unfollow removes from Following only', (tester) async {
      final SportHarness h = SportHarness(
        following: <String>[kFootball, kTennis],
      );
      h.repo.sportResult = const Ok(_tennis);
      h.profile.interestsOnRefresh = <String>[kFootball];
      await pumpSport(tester, h, sportId: kTennis);
      await tester.tap(find.text('Following'));
      await settle(tester);
      expect(h.follow.unfollows, <String>['me:$kTennis']);
      expect(find.text('Follow'), findsOneWidget);
      expect(h.repo.createdProfiles, isEmpty);
    });

    for (final (SportFollowOutcome, String) c in <(SportFollowOutcome, String)>[
      (SportFollowOutcome.blockedLast, 'You must follow at least one sport.'),
      (
        SportFollowOutcome.blockedPracticing,
        "You play this sport, so you can't unfollow it.",
      ),
      (
        SportFollowOutcome.blockedPrimary,
        "This is your primary sport, so you can't unfollow it.",
      ),
    ]) {
      testWidgets('a blocked unfollow (${c.$1.name}) keeps it and says why', (
        tester,
      ) async {
        final SportHarness h = SportHarness(following: <String>[kFootball]);
        h.follow.unfollowResult = Ok(c.$1);
        await pumpSport(tester, h);
        await tester.tap(find.text('Following'));
        await settle(tester);
        expect(find.text(c.$2), findsOneWidget);
        expect(find.text('Following'), findsOneWidget);
        // Nothing was reloaded or written: the guard refused first.
        expect(h.profile.refreshes, 0);
        expect(h.repo.createdProfiles, isEmpty);
      });
    }

    testWidgets(
      'a failed follow shows the error with Retry and does not flip',
      (tester) async {
        final SportHarness h = SportHarness(following: <String>[kFootball]);
        h.repo.sportResult = const Ok(_tennis);
        h.follow.followResult = const Err(Failure(message: 'offline'));
        await pumpSport(tester, h, sportId: kTennis);
        await tester.tap(find.text('Follow'));
        await settle(tester);
        expect(
          find.text("Couldn't update your Following. Try again."),
          findsOneWidget,
        );
        expect(find.text('Follow'), findsOneWidget);
        expect(find.text('Following'), findsNothing);

        h.follow.followResult = const Ok(SportFollowOutcome.followed);
        h.profile.interestsOnRefresh = <String>[kFootball, kTennis];
        // The toast's Retry action: what a tap on it runs.
        tester
            .widget<DabblerToast>(find.byType(DabblerToast))
            .action!
            .onPressed!();
        await settle(tester);
        expect(h.follow.follows.length, 2);
        expect(find.text('Following'), findsOneWidget);
      },
    );
  });

  group('AC7 join', () {
    Future<SportHarness> pumpWithGame(
      WidgetTester tester, {
      required bool hasProfile,
    }) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.hasProfileResult = Ok(hasProfile);
      h.repo.gamesResult = Ok([game('g1', title: 'Join me')]);
      await pumpSport(tester, h);
      await _openTab(tester, 'Games');
      return h;
    }

    testWidgets('with a sport profile, Join goes straight to the real join', (
      tester,
    ) async {
      final SportHarness h = await pumpWithGame(tester, hasProfile: true);
      await tester.tap(find.text('Join game'));
      await settle(tester);
      expect(find.text('Do you want to create profile?'), findsNothing);
      expect(h.joinedGames, <String>['g1']);
    });

    testWidgets('No performs no join and creates no profile', (tester) async {
      final SportHarness h = await pumpWithGame(tester, hasProfile: false);
      await tester.tap(find.text('Join game'));
      await settle(tester);
      expect(find.text('Do you want to create profile?'), findsOneWidget);
      await tester.tap(find.text('No'));
      await settle(tester);
      expect(h.repo.createdProfiles, isEmpty);
      expect(h.joinedGames, isEmpty);
      expect(h.follow.follows, isEmpty);
      // The button is usable again.
      expect(find.text('Join game'), findsOneWidget);
    });

    testWidgets('Yes creates the profile, adds Following, then joins', (
      tester,
    ) async {
      final SportHarness h = await pumpWithGame(tester, hasProfile: false);
      await tester.tap(find.text('Join game'));
      await settle(tester);
      await tester.tap(find.text('Yes'));
      await settle(tester);
      expect(h.repo.createdProfiles, <String>['me:$kFootball']);
      expect(h.follow.follows, <String>['me:$kFootball']);
      expect(h.joinedGames, <String>['g1']);
    });

    testWidgets('a failed profile create stops the join and says so', (
      tester,
    ) async {
      final SportHarness h = await pumpWithGame(tester, hasProfile: false);
      h.repo.createProfileResult = const Err(Failure(message: 'nope'));
      await tester.tap(find.text('Join game'));
      await settle(tester);
      await tester.tap(find.text('Yes'));
      await settle(tester);
      expect(h.joinedGames, isEmpty);
      expect(
        find.text(
          "Couldn't create your profile, so you haven't joined. Try again.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('a meetup RSVP asks the same question first', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.hasProfileResult = const Ok(false);
      h.repo.meetupsResult = Ok([meetup('m1')]);
      await pumpSport(tester, h);
      await _openTab(tester, 'Meetups');
      await tester.tap(find.text('Join meetup'));
      await settle(tester);
      expect(find.text('Do you want to create profile?'), findsOneWidget);
      await tester.tap(find.text('No'));
      await settle(tester);
      expect(h.rsvpMeetups, isEmpty);
      expect(h.repo.createdProfiles, isEmpty);
    });
  });

  group('AC8 city', () {
    testWidgets('defaults to the device city and queries with its code', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      expect(find.text('Dubai'), findsOneWidget);
      expect(h.repo.overviewCities, <String?>['dubai']);
      expect(h.repo.calls, contains('games:$kFootball:dubai'));
    });

    testWidgets('a city without data says so and shows every city', (
      tester,
    ) async {
      final SportHarness h = SportHarness(
        following: <String>[kFootball],
        city: 'Atlantis',
      );
      await pumpSport(tester, h);
      expect(h.repo.overviewCities, <String?>[null]);
      expect(
        find.text(
          'No listings are grouped under Atlantis yet, so this shows every city.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no city shows the designed CTA and queries every city', (
      tester,
    ) async {
      final SportHarness h = SportHarness(
        following: <String>[kFootball],
        city: null,
      );
      await pumpSport(tester, h);
      expect(find.text("Pick a city to see what's on"), findsOneWidget);
      expect(find.text('Choose a city'), findsOneWidget);
      expect(h.repo.overviewCities, <String?>[null]);
    });

    testWidgets('Clear city returns to the no-city state', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      await tester.tap(find.text('Clear city'));
      await settle(tester);
      expect(find.text("Pick a city to see what's on"), findsOneWidget);
      expect(h.repo.overviewCities.last, isNull);
      expect(h.location.manualCityCalls, 0);
    });

    testWidgets('picking another city re-queries this page only', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.cityCodes['Abu Dhabi'] = 'abu-dhabi';
      await pumpSport(
        tester,
        h,
        overrides: [
          mapboxCityProvider.overrideWith(
            (ref, String q) async => <MapboxPlace>[
              const MapboxPlace(
                id: 'place.1',
                name: 'Abu Dhabi',
                fullAddress: 'Abu Dhabi, UAE',
                lat: 24.45,
                lng: 54.37,
                country: 'United Arab Emirates',
                countryCode: 'AE',
              ),
            ],
          ),
        ],
      );
      await tester.tap(find.text('Dubai'));
      await settle(tester);
      await tester.enterText(find.byType(EditableText).last, 'abu');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      await tester.tap(find.text('Abu Dhabi'));
      await settle(tester);

      expect(h.repo.overviewCities.last, 'abu-dhabi');
      expect(find.text('Abu Dhabi'), findsOneWidget);
      // Device location, saved places and the profile are untouched.
      expect(h.location.manualCityCalls, 0);
      expect(h.profile.refreshes, 0);
      expect(h.follow.follows, isEmpty);
      expect(h.follow.unfollows, isEmpty);
    });
  });

  group('AC9 mutual followers and Create game', () {
    testWidgets('the line shows up to three names', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.overviewResult = Ok(
        counts(
          mutual: const <MutualFollower>[
            MutualFollower(displayName: 'Aisha'),
            MutualFollower(displayName: 'Omar'),
            MutualFollower(username: 'lina'),
          ],
        ),
      );
      await pumpSport(tester, h);
      expect(find.text('Followed by Aisha, Omar and lina'), findsOneWidget);
    });

    testWidgets('the line is hidden when none or when the field is absent', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      expect(find.textContaining('Followed by'), findsNothing);
      expect(
        SportOverviewCounts.fromJson(const <String, dynamic>{
          'followers': 1,
        }).mutualFollowers,
        isEmpty,
      );
    });

    testWidgets('Create game opens the existing create flow', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      await tester.tap(find.text('Create game'));
      await settle(tester);
      expect(h.pushed.single, startsWith(RoutePaths.createGame));
    });
  });

  group('AC11 EN/AR, light/dark, no overflow', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final Brightness b in Brightness.values) {
        for (final Size size in const <Size>[Size(360, 640), Size(390, 844)]) {
          testWidgets(
            'every tab at ${size.width.toInt()}x${size.height.toInt()} '
            '${locale.languageCode} ${b.name}',
            (tester) async {
              final SportHarness h = SportHarness(
                following: <String>[kFootball],
              );
              h.repo.gamesResult = Ok([game('g1', price: 25)]);
              h.repo.meetupsResult = Ok([meetup('m1')]);
              h.repo.venuesResult = const Ok(<SportVenue>[
                SportVenue(
                  id: 'v1',
                  nameEn: 'A venue with a rather long name for the row',
                  areaName: 'Marina',
                  rating: 4.2,
                ),
              ]);
              h.repo.spacesResult = const Ok(<SportSpace>[
                SportSpace(
                  id: 's1',
                  venueId: 'v1',
                  nameEn: 'Court 1',
                  venueNameEn: 'Venue',
                  pricePerHour: 90,
                  capacity: 8,
                  indoor: true,
                ),
              ]);
              h.repo.postIdsResult = const Ok(<String>['p1']);
              h.postsToReturn = [post('p1')];
              h.repo.overviewResult = Ok(
                counts(
                  mutual: const <MutualFollower>[
                    MutualFollower(displayName: 'Aisha'),
                  ],
                ),
              );
              await pumpSport(
                tester,
                h,
                locale: locale,
                brightness: b,
                size: size,
              );
              final bool rtl = locale.languageCode == 'ar';
              expect(
                Directionality.of(tester.element(find.byType(DabblerTabs))),
                rtl ? TextDirection.rtl : TextDirection.ltr,
              );
              expect(tester.takeException(), isNull, reason: 'overview');

              final List<String> labels = rtl
                  ? <String>['المباريات', 'اللقاءات', 'الأماكن', 'المنشورات']
                  : <String>['Games', 'Meetups', 'Venues', 'Posts'];
              for (final String label in labels) {
                await _openTab(tester, label);
                expect(tester.takeException(), isNull, reason: label);
              }
            },
          );
        }
      }
    }

    testWidgets('Arabic labels render on the page', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(
        tester,
        h,
        locale: const Locale('ar'),
        brightness: Brightness.dark,
      );
      expect(find.text('كرة القدم'), findsWidgets);
      expect(find.text('تتابعها'), findsOneWidget);
      expect(_tab('نظرة عامة'), findsOneWidget);
      expect(_tab('المباريات'), findsOneWidget);
    });
  });
}
