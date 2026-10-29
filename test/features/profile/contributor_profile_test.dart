import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:dabbler/features/profile/presentation/models/sport_profile_route_args.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_game_counts_provider.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/contributor_games_sections.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_header.dart';
import 'package:dabbler/features/profile/presentation/widgets/profile/own_profile_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_render_support.dart';

const Locale _en = Locale('en');

Widget _scroll(Widget child) => SingleChildScrollView(child: child);

void main() {
  group('Sport profile route args', () {
    const SportProfileRouteArgs contributor = SportProfileRouteArgs(
      profileId: 'p',
      userId: 'u',
      displayName: 'C',
      personaType: 'contributor',
      sportId: 's',
      sportKey: 'football',
      sportName: 'Football',
    );

    test('a Contributor is accepted and opens the organiser view', () {
      final SportProfileRouteArgs? rebuilt =
          SportProfileRouteArgs.fromQueryParameters(
            contributor.toQueryParameters(),
          );
      expect(rebuilt, contributor);
      expect(rebuilt!.isOrganiserPersona, isTrue);
    });

    test('an unknown persona is still rejected', () {
      final Map<String, String> q = contributor.toQueryParameters();
      q['persona'] = 'partner';
      expect(SportProfileRouteArgs.fromQueryParameters(q), isNull);
    });

    test('a player is not the organiser view', () {
      final Map<String, String> q = contributor.toQueryParameters();
      q['persona'] = 'player';
      expect(
        SportProfileRouteArgs.fromQueryParameters(q)!.isOrganiserPersona,
        isFalse,
      );
    });
  });

  group('Contributor stats', () {
    testWidgets('Played, Organised and Upcoming draw; fabricated tiles do not', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(
        tester,
        _scroll(
          const OwnProfileStats(
            posts: 0,
            sportsCount: 2,
            gamesPlayed: 4,
            organised: 3,
            upcoming: 1,
            minutesPlayed: null,
            reliability: null,
          ),
        ),
        _en,
      );
      expect(find.text('Games played'), findsOneWidget);
      expect(find.text('Games organised'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Minutes played'), findsNothing);
      expect(find.text('Reliability'), findsNothing);
      expect(find.textContaining('Show-up'), findsNothing);
      expect(find.textContaining('Partners'), findsNothing);
    });

    testWidgets('no counts, no Organised or Upcoming tile', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(
        tester,
        _scroll(const OwnProfileStats(posts: 0, sportsCount: 0)),
        _en,
      );
      expect(find.text('Games organised'), findsNothing);
      expect(find.text('Upcoming'), findsNothing);
    });
  });

  group('Own profile posts counter', () {
    testWidgets('a failed fetch shows a retry, never a zero', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await pumpProfileScreen(
        tester,
        _scroll(
          OwnProfileHeader(
            profile: null,
            posts: 0,
            following: 0,
            followers: 0,
            postsFailed: true,
            onRetryPosts: () => retries++,
          ),
        ),
        _en,
      );
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('a successful zero shows 0 and no retry', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(
        tester,
        _scroll(
          const OwnProfileHeader(
            profile: null,
            posts: 0,
            following: 0,
            followers: 0,
          ),
        ),
        _en,
      );
      expect(find.text('Retry'), findsNothing);
      expect(find.text('0'), findsWidgets);
    });
  });

  group('Contributor games lists', () {
    final GameCounts counts = computeGameCounts(<GameCountRow>[
      GameCountRow(
        id: 'g1',
        title: 'Friday five-a-side',
        startAt: DateTime.now().add(const Duration(days: 3)),
        isCancelled: false,
        isOrganiser: true,
      ),
    ]);

    testWidgets('a row opens the real game detail', (
      WidgetTester tester,
    ) async {
      final List<String> opened = <String>[];
      await pumpProfileScreen(
        tester,
        _scroll(ContributorGamesSections(counts: counts, onOpenGame: opened.add)),
        _en,
      );
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Games I organise'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('contributor-game-g1')).first);
      expect(opened, <String>['g1']);
    });

    testWidgets('a visitor sees Upcoming only', (WidgetTester tester) async {
      await pumpProfileScreen(
        tester,
        _scroll(ContributorGamesSections(counts: counts, showOrganised: false)),
        _en,
      );
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Games I organise'), findsNothing);
    });
  });

  group('New Contributor (Profiles.dc.html contributorNew)', () {
    setUpAll(loadProfileFonts);
    final GameCounts none = computeGameCounts(<GameCountRow>[]);
    Widget newUser({VoidCallback? onFindGame, bool owner = true}) => _scroll(
      Column(
        children: <Widget>[
          if (owner)
            const OwnProfileStats(
              posts: 0,
              sportsCount: 1,
              newContributor: true,
            ),
          ContributorGamesSections(
            counts: none,
            showOrganised: owner,
            onFindGame: onFindGame,
          ),
        ],
      ),
    );

    testWidgets('owner sees the calendar empty state and Find a game', (
      WidgetTester tester,
    ) async {
      int found = 0;
      await pumpProfileScreen(tester, newUser(onFindGame: () => found++), _en);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(
        find.text('No games yet. Join one nearby or create your own.'),
        findsOneWidget,
      );
      expect(find.text('Find a game'), findsOneWidget);
      await tester.tap(find.text('Find a game'));
      expect(found, 1);
    });

    testWidgets('bento is the three-tile zero state', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(tester, newUser(), _en);
      expect(find.text('Games & meetups'), findsOneWidget);
      expect(find.text('Join or organise one to start your list'), findsOneWidget);
      expect(find.text('Played'), findsOneWidget);
      expect(find.text('Organised'), findsOneWidget);
      expect(find.text('Primary sports'), findsNothing);
      expect(find.text('Games played'), findsNothing);
    });

    testWidgets('a visitor sees neither the empty state nor its button', (
      WidgetTester tester,
    ) async {
      await pumpProfileScreen(tester, newUser(owner: false), _en);
      expect(
        find.text('No games yet. Join one nearby or create your own.'),
        findsNothing,
      );
      expect(find.text('Find a game'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('contributor-upcoming-empty')),
        findsNothing,
      );
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('renders in ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpProfileScreen(tester, newUser(), locale, height: 560);
        expect(
          find.byKey(const ValueKey<String>('contributor-upcoming-empty')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await shootProfile(
          tester,
          kShotKey,
          'kan682-new-contributor-${locale.languageCode}',
        );
      });
    }
  });

  group('v_game_card rows', () {
    test('own profile reads the viewer flags; others read creator and roster', () {
      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'a',
          'start_at': '2020-01-01T10:00:00Z',
          'is_cancelled': false,
          'is_creator': true,
          'is_joined': false,
          'creator_profile_id': 'other',
        },
        <String, dynamic>{
          'id': 'b',
          'start_at': '2020-01-02T10:00:00Z',
          'is_cancelled': false,
          'is_creator': false,
          'is_joined': true,
          'creator_profile_id': 'x',
        },
      ];
      final GameCounts own = computeGameCounts(
        rowsToGameCountRows(
          rows,
          isOwn: true,
          profileId: 'me',
          rostered: <String>{},
        ),
      );
      expect((own.played, own.organised), (1, 1));
      final GameCounts seen = computeGameCounts(
        rowsToGameCountRows(
          rows,
          isOwn: false,
          profileId: 'x',
          rostered: <String>{'a'},
        ),
      );
      expect((seen.played, seen.organised), (1, 1));
    });
  });
}
