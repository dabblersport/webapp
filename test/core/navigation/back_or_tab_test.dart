// A screen opened straight from a notification (a cold start: the only route)
// goes back to its tab; one pushed on top of a screen pops as before.

import 'package:dabbler/core/navigation/back_or_tab.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _screen(String label) => Builder(
  builder: (context) => BackOrTabScope(
    child: Scaffold(
      body: TextButton(
        key: const ValueKey('back'),
        onPressed: () => backOrTab(context),
        child: Text(label),
      ),
    ),
  ),
);

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(path: RoutePaths.home, builder: (_, __) => const Text('HOME')),
    GoRoute(path: RoutePaths.gamesTab, builder: (_, __) => const Text('GAMES')),
    GoRoute(
      path: RoutePaths.meetups,
      builder: (_, __) => const Text('MEETUPS'),
    ),
    GoRoute(path: '/sports/games/:id', builder: (_, __) => _screen('game')),
    GoRoute(path: '/meetups/:id', builder: (_, __) => _screen('meetup')),
    GoRoute(path: '/check-in/:id', builder: (_, __) => _screen('check-in')),
  ],
);

void main() {
  test('fallback tab per route', () {
    expect(fallbackTabFor('/sports/games/g1'), RoutePaths.gamesTab);
    expect(fallbackTabFor('/game/g1'), RoutePaths.gamesTab);
    expect(fallbackTabFor('/meetups/m1'), RoutePaths.meetups);
    expect(fallbackTabFor('/check-in/e1'), RoutePaths.home);
    expect(fallbackTabFor('/attendance/e1'), RoutePaths.home);
    expect(fallbackTabFor('/security/review/new_sign_in'), RoutePaths.home);
  });

  for (final (path, tab) in [
    ('/sports/games/g1', 'GAMES'),
    ('/meetups/m1', 'MEETUPS'),
    ('/check-in/e1', 'HOME'),
  ]) {
    testWidgets('cold start on $path: app-bar back lands on $tab', (t) async {
      await t.pumpWidget(MaterialApp.router(routerConfig: _router(path)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('back')));
      await t.pumpAndSettle();
      expect(find.text(tab), findsOneWidget);
    });

    testWidgets('cold start on $path: system back lands on $tab', (t) async {
      await t.pumpWidget(MaterialApp.router(routerConfig: _router(path)));
      await t.pumpAndSettle();
      final handled = await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.text(tab), findsOneWidget);
    });
  }

  testWidgets('pushed on top of home, back pops to home', (t) async {
    final router = _router(RoutePaths.home);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    router.push('/sports/games/g1');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('back')));
    await t.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('GAMES'), findsNothing);
  });
}
