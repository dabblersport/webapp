import 'dart:async';

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
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// KAN-591 drew the page as Sport Overview v2: no tab strip. The Overview is a
/// bento of counter tiles and rails; a tile or a "See all" opens a sub-view
/// with an "Overview" back link.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settle(tester);
}

Future<void> _tapText(WidgetTester tester, String text) =>
    _tap(tester, find.text(text).first);

Future<void> _openGames(WidgetTester tester) =>
    _tapText(tester, 'Games & meetups');

Future<void> _openVenues(WidgetTester tester) => _tapText(tester, 'Venues');

Future<void> _openSpaces(WidgetTester tester) => _tapText(tester, 'Spaces');

Future<void> _openPosts(WidgetTester tester) => _tapText(tester, 'Posts');

Future<void> _back(WidgetTester tester) => _tapText(tester, 'Overview');

const SportVenue _ratedArena = SportVenue(
  id: 'v1',
  nameEn: 'Rated Arena',
  areaName: 'Marina',
  rating: 4.6,
);

void main() {
  setUpAll(loadRenderFonts);

  group('AC1/AC2 route, identity and header', () {
    testWidgets('shows the identity block and no tab strip', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);

      expect(find.text('Football'), findsWidgets);
      expect(find.text('Sport · 5-a-side, 7-a-side'), findsOneWidget);
      expect(find.text('Public sport page'), findsOneWidget);
      expect(find.text('Dubai'), findsOneWidget);
      expect(find.text('1,204'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Create game or meetup'), findsOneWidget);
      // The design has no tab strip, and Places and News have no readable
      // source: neither is drawn, and Share/More stay out until their
      // destination is decided (no dead control).
      expect(find.byType(DabblerTabs), findsNothing);
      expect(find.textContaining('Place'), findsNothing);
      expect(find.text('News'), findsNothing);
      expect(find.text('Share'), findsNothing);
      expect(find.text('More'), findsNothing);
      expect(h.repo.calls, contains('sport:$kFootball'));
    });

    testWidgets(
      'an unfollowed sport can be browsed and says what Follow does',
      (tester) async {
        final SportHarness h = SportHarness(following: <String>[kFootball]);
        h.repo.sportResult = const Ok(_tennis);
        await pumpSport(tester, h, sportId: kTennis);
        expect(find.text('Tennis'), findsWidgets);
        expect(find.text('Follow'), findsOneWidget);
        expect(find.text('Sport'), findsOneWidget);
        // The note belongs to the Following state, not to the browse state.
        expect(find.textContaining('your sports profile'), findsNothing);
      },
    );

    testWidgets('Following says Follow never adds the sport to the profile', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      expect(
        find.text(
          'Football posts, games and news will show in your feed. '
          'This doesn’t add Football to your sports profile.',
        ),
        findsOneWidget,
      );
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
      expect(find.text('Next 7 days'), findsNothing);
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

  group('AC3 overview tiles and navigation', () {
    testWidgets('tiles show the RPC counts; venues and spaces are not summed', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      expect(find.text('Play Football in Dubai'), findsOneWidget);
      expect(find.text('Next 7 days'), findsOneWidget);
      // Hero: games + meetups, spelled out under it.
      expect(find.text('Games & meetups'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3 games · 2 meetups'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('To book'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('Inside venues'), findsOneWidget);
      // Posts: the header counter and the tile.
      expect(find.text('17'), findsNWidgets(2));
      expect(find.text('13'), findsNothing, reason: 'venues + spaces summed');
    });

    testWidgets('a tile opens its view and "Overview" returns', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.gamesResult = Ok([game('g1')]);
      h.repo.meetupsResult = Ok([meetup('m1')]);
      await pumpSport(tester, h);

      await _openGames(tester);
      expect(find.text('Friday five-a-side'), findsOneWidget);
      expect(find.text('Sunday kickabout'), findsOneWidget);
      expect(find.text('1 game · 1 meetup'), findsOneWidget);
      expect(find.text('Play Football in Dubai'), findsNothing);

      await _back(tester);
      expect(find.text('Play Football in Dubai'), findsOneWidget);

      await _openSpaces(tester);
      expect(find.text('0 bookable spaces'), findsOneWidget);
      await _back(tester);

      await _openVenues(tester);
      expect(find.text('0 venues'), findsOneWidget);
    });

    testWidgets('a rail shows at most three and "See all" opens the list', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.gamesResult = Ok([
        for (int i = 1; i <= 4; i++) game('g$i', title: 'Game $i'),
      ]);
      await pumpSport(tester, h);
      expect(find.text('Next games'), findsOneWidget);
      expect(find.text('Game 1'), findsOneWidget);
      expect(find.text('Game 3'), findsOneWidget);
      expect(find.text('Game 4'), findsNothing);

      await _tapText(tester, 'See all');
      expect(find.text('Game 4'), findsOneWidget);
    });

    testWidgets('a rail with nothing in it is not drawn', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      expect(find.text('Next games'), findsNothing);
      expect(find.text('Top venues'), findsNothing);
    });

    testWidgets('top venues rail uses real venues only', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.venuesResult = const Ok(<SportVenue>[_ratedArena]);
      await pumpSport(tester, h);
      expect(find.text('Top venues'), findsOneWidget);
      expect(find.text('Rated Arena'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
    });

    testWidgets('a failed aggregate shows the banner, never a sample number', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.overviewResult = const Err(Failure(message: 'offline'));
      await pumpSport(tester, h);
      expect(find.text('Couldn’t load Football in Dubai'), findsOneWidget);
      expect(find.text('Games & meetups'), findsNothing);
      expect(find.text('Followers'), findsNothing);

      h.repo.overviewResult = Ok(counts(games: 5));
      await _tapText(tester, 'Try again');
      expect(find.text('Games & meetups'), findsOneWidget);
      expect(find.text('Couldn’t load Football in Dubai'), findsNothing);
    });

    testWidgets('every count at zero shows the empty card with Change city', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.overviewResult = Ok(
        counts(games: 0, meetups: 0, venues: 0, spaces: 0, posts: 0),
      );
      await pumpSport(tester, h);
      expect(find.text('Nothing for Football in Dubai yet'), findsOneWidget);
      expect(find.text('Change city'), findsOneWidget);
      expect(find.text('Games & meetups'), findsNothing);
    });

    testWidgets('while the counts load a skeleton shows, not zeros', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.overviewGate = Completer<void>();
      await pumpSport(tester, h);
      expect(find.text('Games & meetups'), findsNothing);
      expect(find.byType(DabblerSkeleton), findsWidgets);
      h.repo.overviewGate!.complete();
      await settle(tester);
      expect(find.text('Games & meetups'), findsOneWidget);
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
      await _openGames(tester);
      expect(find.text('Priced game'), findsOneWidget);
      expect(find.text('Unpriced game'), findsOneWidget);
      expect(find.text('Free'), findsNothing);
      expect(find.text('Ask'), findsNothing);
    });

    testWidgets('a game opens the real detail route', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.gamesResult = Ok([game('g1', title: 'Priced game')]);
      await pumpSport(tester, h);
      await _openGames(tester);
      await _tapText(tester, 'Priced game');
      expect(h.pushed, contains(RoutePaths.gameDetail('g1')));
    });

    testWidgets('a rail game opens the real detail route', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.gamesResult = Ok([game('g1', title: 'Priced game')]);
      await pumpSport(tester, h);
      await _tapText(tester, 'Priced game');
      expect(h.pushed, contains(RoutePaths.gameDetail('g1')));
    });

    testWidgets('a meetup opens the real detail route', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.meetupsResult = Ok([meetup('m1')]);
      await pumpSport(tester, h);
      await _openGames(tester);
      await _tapText(tester, 'Sunday kickabout');
      expect(h.pushed, contains(RoutePaths.meetupDetail('m1')));
    });

    testWidgets('empty states name the sport and the city', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      await _openGames(tester);
      expect(find.text('No Football games in Dubai'), findsOneWidget);
      await _back(tester);
      await _openVenues(tester);
      expect(find.text('No Football venues in Dubai'), findsOneWidget);
      await _openSpaces(tester);
      expect(find.text('No Football spaces in Dubai'), findsOneWidget);
    });

    testWidgets('a failing list shows error with Retry and recovers', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.gamesResult = const Err(Failure(message: 'offline'));
      await pumpSport(tester, h);
      await _openGames(tester);
      expect(find.text("Couldn't load this"), findsOneWidget);
      expect(find.text('No Football games in Dubai'), findsNothing);

      h.repo.gamesResult = Ok([game('g1', title: 'Back online')]);
      await _tapText(tester, 'Retry');
      expect(find.text('Back online'), findsOneWidget);
    });

    testWidgets('Venues and Spaces are separate lists behind a switch', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.venuesResult = const Ok(<SportVenue>[
        _ratedArena,
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
      await _openVenues(tester);

      expect(find.text('2 venues'), findsOneWidget);
      expect(find.text('Unrated Hall'), findsOneWidget);
      expect(find.text('Court 1'), findsNothing);
      // A venue without a rating draws none (not 0.0).
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('0.0'), findsNothing);

      // The pill switch moves to Spaces and back; the two are never merged.
      await _openSpaces(tester);
      expect(find.text('2 bookable spaces'), findsOneWidget);
      expect(find.text('Court 1'), findsOneWidget);
      expect(find.text('Court 2'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('Unrated Hall'), findsOneWidget);

      await _openVenues(tester);
      expect(find.text('2 venues'), findsOneWidget);
      expect(find.text('Court 1'), findsNothing);
    });

    testWidgets('the Spaces tile opens the Spaces side directly', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.spacesResult = const Ok(<SportSpace>[
        SportSpace(
          id: 's1',
          venueId: 'v1',
          nameEn: 'Court 1',
          venueNameEn: 'Rated Arena',
        ),
      ]);
      await pumpSport(tester, h);
      await _openSpaces(tester);
      expect(find.text('1 bookable space'), findsOneWidget);
      expect(find.text('Court 1'), findsOneWidget);
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
      await _openPosts(tester);
      expect(find.text('17 posts'), findsOneWidget);
      expect(find.text('Tennis post one'), findsOneWidget);
      expect(find.text('Tennis post two'), findsOneWidget);
      expect(h.repo.calls, contains('postIds:$kTennis:0'));
    });

    testWidgets('the Overview previews posts and "See all" opens them', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.postIdsResult = const Ok(<String>['p1']);
      h.postsToReturn = [post('p1', body: 'Preview post')];
      await pumpSport(tester, h);
      expect(find.text('Preview post'), findsOneWidget);
      await _tapText(tester, 'See all');
      expect(find.text('17 posts'), findsOneWidget);
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
      await _openPosts(tester);
      final double newer = tester.getTopLeft(find.text('Newer post')).dy;
      final double older = tester.getTopLeft(find.text('Older post')).dy;
      expect(newer, lessThan(older));
    });

    testWidgets('posts do not wait for a city', (tester) async {
      final SportHarness h = SportHarness(
        following: <String>[kFootball],
        city: null,
      );
      h.repo.postIdsResult = const Ok(<String>['p1']);
      h.postsToReturn = [post('p1', body: 'City-free post')];
      await pumpSport(tester, h);
      await _openPosts(tester);
      expect(find.text('City-free post'), findsOneWidget);
    });

    testWidgets('empty posts show the empty state', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      await _openPosts(tester);
      expect(find.text('No posts yet'), findsOneWidget);
    });

    testWidgets('a failing feed shows Retry and does not apply a filter', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.postIdsResult = const Err(Failure(message: 'offline'));
      await pumpSport(tester, h);
      await _openPosts(tester);
      expect(find.text("Couldn't load this"), findsOneWidget);
      h.repo.postIdsResult = const Ok(<String>['p1']);
      h.postsToReturn = [post('p1', body: 'Recovered post')];
      await _tapText(tester, 'Retry');
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

      await _tapText(tester, 'Follow');
      expect(h.follow.follows, <String>['me:$kTennis']);
      expect(find.text('Following'), findsOneWidget);
      expect(h.repo.createdProfiles, isEmpty);
      expect(h.follow.unfollows, isEmpty);
    });

    testWidgets('Unfollow asks first; Cancel keeps it and writes nothing', (
      tester,
    ) async {
      final SportHarness h = SportHarness(
        following: <String>[kFootball, kTennis],
      );
      h.repo.sportResult = const Ok(_tennis);
      await pumpSport(tester, h, sportId: kTennis);
      await _tapText(tester, 'Following');
      expect(find.text('Unfollow Tennis?'), findsOneWidget);
      await _tapText(tester, 'Cancel');
      expect(h.follow.unfollows, isEmpty);
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('Unfollow removes from Following only', (tester) async {
      final SportHarness h = SportHarness(
        following: <String>[kFootball, kTennis],
      );
      h.repo.sportResult = const Ok(_tennis);
      h.profile.interestsOnRefresh = <String>[kFootball];
      await pumpSport(tester, h, sportId: kTennis);
      await _tapText(tester, 'Following');
      await _tapText(tester, 'Unfollow');
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
        await _tapText(tester, 'Following');
        await _tapText(tester, 'Unfollow');
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
        await _tapText(tester, 'Follow');
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
      await _openGames(tester);
      return h;
    }

    testWidgets('with a sport profile, Join goes straight to the real join', (
      tester,
    ) async {
      final SportHarness h = await pumpWithGame(tester, hasProfile: true);
      await _tapText(tester, 'Join');
      expect(find.text('Do you want to create profile?'), findsNothing);
      expect(h.joinedGames, <String>['g1']);
    });

    testWidgets('a rail card joins the same way', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      h.repo.gamesResult = Ok([game('g1', title: 'Join me')]);
      await pumpSport(tester, h);
      await _tapText(tester, 'Join');
      expect(h.joinedGames, <String>['g1']);
    });

    testWidgets('No performs no join and creates no profile', (tester) async {
      final SportHarness h = await pumpWithGame(tester, hasProfile: false);
      await _tapText(tester, 'Join');
      expect(find.text('Do you want to create profile?'), findsOneWidget);
      await _tapText(tester, 'No');
      expect(h.repo.createdProfiles, isEmpty);
      expect(h.joinedGames, isEmpty);
      expect(h.follow.follows, isEmpty);
      // The button is usable again.
      expect(find.text('Join'), findsOneWidget);
    });

    testWidgets('Yes creates the profile, adds Following, then joins', (
      tester,
    ) async {
      final SportHarness h = await pumpWithGame(tester, hasProfile: false);
      await _tapText(tester, 'Join');
      await _tapText(tester, 'Yes');
      expect(h.repo.createdProfiles, <String>['me:$kFootball']);
      expect(h.follow.follows, <String>['me:$kFootball']);
      expect(h.joinedGames, <String>['g1']);
    });

    testWidgets('a failed profile create stops the join and says so', (
      tester,
    ) async {
      final SportHarness h = await pumpWithGame(tester, hasProfile: false);
      h.repo.createProfileResult = const Err(Failure(message: 'nope'));
      await _tapText(tester, 'Join');
      await _tapText(tester, 'Yes');
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
      await _openGames(tester);
      await _tap(tester, find.byType(DabblerRsvpCta).first);
      expect(find.text('Do you want to create profile?'), findsOneWidget);
      await _tapText(tester, 'No');
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

    testWidgets('no city shows the designed card and queries every city', (
      tester,
    ) async {
      final SportHarness h = SportHarness(
        following: <String>[kFootball],
        city: null,
      );
      await pumpSport(tester, h);
      expect(
        find.text('Select a city to see Football near you'),
        findsOneWidget,
      );
      // The header chip and the card's button both say it.
      expect(find.text('Select city'), findsNWidgets(2));
      expect(find.text('Games & meetups'), findsNothing);
      expect(h.repo.overviewCities, <String?>[null]);
    });

    testWidgets('the no-city button opens the city sheet', (tester) async {
      final SportHarness h = SportHarness(
        following: <String>[kFootball],
        city: null,
      );
      await pumpSport(tester, h);
      await _tapText(tester, 'Select city');
      expect(find.text('Choose city'), findsOneWidget);
      expect(
        find.text(
          'Changes this page only. Your location on this device isn’t changed.',
        ),
        findsOneWidget,
      );
    });

    Future<void> pickAbuDhabi(WidgetTester tester, SportHarness h) async {
      h.repo.cityCodes['Abu Dhabi'] = 'abu-dhabi';
      await _tapText(tester, 'Dubai');
      await tester.enterText(find.byType(EditableText).last, 'abu');
      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      await _tapText(tester, 'Abu Dhabi');
    }

    final List<Override> abuDhabiResults = <Override>[
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
    ];

    testWidgets('picking another city re-queries this page only', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h, overrides: abuDhabiResults);
      await pickAbuDhabi(tester, h);

      expect(h.repo.overviewCities.last, 'abu-dhabi');
      expect(find.text('Abu Dhabi'), findsOneWidget);
      expect(find.text('Play Football in Abu Dhabi'), findsOneWidget);
      // Device location, saved places and the profile are untouched.
      expect(h.location.manualCityCalls, 0);
      expect(h.profile.refreshes, 0);
      expect(h.follow.follows, isEmpty);
      expect(h.follow.unfollows, isEmpty);
    });

    testWidgets('"Use my location" goes back to the device city', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h, overrides: abuDhabiResults);
      await pickAbuDhabi(tester, h);
      expect(h.repo.overviewCities.last, 'abu-dhabi');

      await _tapText(tester, 'Abu Dhabi');
      await _tapText(tester, 'Use my location · Dubai');
      expect(h.repo.overviewCities.last, 'dubai');
      expect(find.text('Play Football in Dubai'), findsOneWidget);
      expect(h.location.manualCityCalls, 0);
    });

    testWidgets('a sub-view keeps the chosen city', (tester) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h, overrides: abuDhabiResults);
      await pickAbuDhabi(tester, h);
      await _openGames(tester);
      expect(h.repo.calls, contains('games:$kFootball:abu-dhabi'));
      expect(find.text('No Football games in Abu Dhabi'), findsOneWidget);
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

    testWidgets('Create game or meetup opens the existing create flow', (
      tester,
    ) async {
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(tester, h);
      await _tapText(tester, 'Create game or meetup');
      expect(h.pushed.single, startsWith(RoutePaths.createGame));
      expect(h.pushed.single, contains('sport='));
    });
  });

  group('AC11 EN/AR, light/dark, no overflow', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final Brightness b in Brightness.values) {
        for (final Size size in const <Size>[Size(360, 640), Size(390, 844)]) {
          testWidgets(
            'every view at ${size.width.toInt()}x${size.height.toInt()} '
            '${locale.languageCode} ${b.name}',
            (tester) async {
              final AppLocalizations l = lookupAppLocalizations(locale);
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
                Directionality.of(
                  tester.element(find.text(l.sport_overview_next_7_days)),
                ),
                rtl ? TextDirection.rtl : TextDirection.ltr,
              );
              expect(tester.takeException(), isNull, reason: 'overview');

              final List<String> tiles = <String>[
                l.sport_overview_tile_games_meetups,
                l.sport_overview_stat_posts,
                l.sport_overview_stat_venues,
                l.sport_overview_stat_spaces,
              ];
              for (final String label in tiles) {
                await _tap(tester, find.text(label).first);
                expect(tester.takeException(), isNull, reason: label);
                await _tap(
                  tester,
                  find.text(l.sport_overview_tab_overview).first,
                );
                expect(tester.takeException(), isNull, reason: 'back $label');
              }
            },
          );
        }
      }
    }

    testWidgets('Arabic labels render on the page', (tester) async {
      final AppLocalizations l = lookupAppLocalizations(const Locale('ar'));
      final SportHarness h = SportHarness(following: <String>[kFootball]);
      await pumpSport(
        tester,
        h,
        locale: const Locale('ar'),
        brightness: Brightness.dark,
      );
      expect(find.text('كرة القدم'), findsWidgets);
      expect(find.text('تتابعها'), findsOneWidget);
      expect(find.text(l.sport_overview_tile_games_meetups), findsOneWidget);
      expect(find.text(l.sport_overview_public_chip), findsOneWidget);
    });
  });
}
