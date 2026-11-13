// KAN-933: every search result card opens its detail by the app's own route,
// and the legacy singular `/meetup/:id` link redirects to `/meetups/:id`.

import 'package:dabbler/app/routes/meetups_routes.dart';
import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/data/models/search/meetup_search_result.dart';
import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/features/social/presentation/widgets/search_cards.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';

final _meetup = MeetupSearchResult(
  id: 'm1',
  title: 'Football community meetup',
  startAt: DateTime(2026, 12, 1, 18),
);

final _game = GameModel.fromJson({
  'id': 'g1',
  'title': 'Football night',
  'sport': 'football',
  'start_at': DateTime(2026, 12, 1, 18).toIso8601String(),
  'max_players': 10,
  'current_players': 3,
});

GoRoute _stub(String path) =>
    GoRoute(path: path, builder: (_, s) => Text('opened ${s.uri.path}'));

GoRouter _router(Widget card) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => Scaffold(body: Center(child: card)),
    ),
    legacyMeetupRedirectRoute,
    _stub('/meetups/:meetupId'),
    _stub('/sports/games/:gameId'),
    _stub('/sports/venues/:venueId'),
  ],
);

Future<GoRouter> _pump(WidgetTester tester, Widget card) async {
  final router = _router(card);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tapOpens(
  WidgetTester tester,
  Widget card,
  String title,
  String path,
) async {
  await _pump(tester, card);
  await tester.tap(find.textContaining(title).first);
  await tester.pumpAndSettle();
  expect(find.text('opened $path'), findsOneWidget);
}

void main() {
  testWidgets('meetup card opens /meetups/:id', (tester) async {
    await _tapOpens(
      tester,
      SearchMeetupCard(meetup: _meetup, query: ''),
      'Football community',
      '/meetups/m1',
    );
  });

  testWidgets('meetup events-row card opens /meetups/:id', (tester) async {
    await _tapOpens(
      tester,
      SearchMeetupEventCard(meetup: _meetup, query: ''),
      'Football community',
      '/meetups/m1',
    );
  });

  testWidgets('game card opens the game detail', (tester) async {
    await _tapOpens(
      tester,
      SearchGameCard(game: _game, query: ''),
      'Football night',
      '/sports/games/g1',
    );
  });

  testWidgets('game events-row card opens the game detail', (tester) async {
    await _tapOpens(
      tester,
      SearchGameEventCard(game: _game, query: ''),
      'Football night',
      '/sports/games/g1',
    );
  });

  testWidgets('venue card opens the venue detail', (tester) async {
    await _tapOpens(
      tester,
      SearchVenueCard(
        venue: const Venue(id: 'v1', name: 'Marina Courts'),
        query: '',
      ),
      'Marina Courts',
      '/sports/venues/v1',
    );
  });

  testWidgets('person card calls its onTap', (tester) async {
    var tapped = 0;
    await _pump(
      tester,
      SearchPersonCard(
        profile: const Profile(
          id: 'p1',
          userId: 'u1',
          profileType: 'player',
          username: 'ahmed_fc',
          displayName: 'Ahmed Football',
        ),
        query: '',
        onTap: () => tapped++,
      ),
    );
    await tester.tap(find.textContaining('Ahmed Football').first);
    expect(tapped, 1);
  });

  testWidgets('legacy /meetup/:id redirects to /meetups/:id', (tester) async {
    final router = await _pump(tester, const SizedBox());
    router.go('/meetup/m1');
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/meetups/m1');
    expect(find.text('opened /meetups/m1'), findsOneWidget);
  });
}
