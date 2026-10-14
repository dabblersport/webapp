import 'package:dabbler/app/app_router.dart';
import 'package:dabbler/features/messaging/presentation/game_chat_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_access_state.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

bool _hasPath(List<RouteBase> routes, String path) {
  for (final r in routes) {
    if (r is GoRoute && r.path == path) return true;
    if (_hasPath(r.routes, path)) return true;
  }
  return false;
}

void main() {
  test('gating: enabled only when messaging AND gameChat', () {
    expect(gameChatRouteEnabled(), isFalse); // committed flags
    expect(gameChatRouteEnabled(messaging: true, gameChat: false), isFalse);
    expect(gameChatRouteEnabled(messaging: false, gameChat: true), isFalse);
    expect(gameChatRouteEnabled(messaging: true, gameChat: true), isTrue);
  });

  test('disabled route body is the unavailable state (KAN-518, D19)', () {
    expect(gameChatRouteBody(gameId: 'g1'), isA<GameChatAccessState>());
    expect(
      (gameChatRouteBody(gameId: 'g1', messaging: true, gameChat: false)
              as GameChatAccessState)
          .kind,
      GameChatAccessKind.unavailable,
    );
    expect(
      gameChatRouteBody(gameId: 'g1', messaging: true, gameChat: true),
      isA<GameChatScreen>(),
    );
  });

  test('real app router registers the route unconditionally', () {
    expect(
      _hasPath(AppRouter.router.configuration.routes, gameChatRoutePath),
      isTrue,
    );
  });

  GoRouter buildRouter({required bool messaging, required bool gameChat}) =>
      GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(path: '/start', builder: (c, s) => const SizedBox()),
          GoRoute(
            path: RoutePaths.home,
            builder: (c, s) => const SizedBox(key: ValueKey('home')),
          ),
          gameChatRoute(messaging: messaging, gameChat: gameChat),
        ],
      );

  Widget app(GoRouter router) => ProviderScope(
    overrides: [gameChatPollIntervalProvider.overrideWithValue(null)],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
    ),
  );

  testWidgets(
    'real route entry with committed flags (all false) shows unavailable',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(path: '/start', builder: (c, s) => const SizedBox()),
          GoRoute(
            path: RoutePaths.home,
            builder: (c, s) => const SizedBox(key: ValueKey('home')),
          ),
          gameChatRoute(),
        ],
      );
      await tester.pumpWidget(app(router));
      router.go('/messaging/game/g1');
      await tester.pumpAndSettle();
      expect(find.byKey(GameChatAccessState.unavailableKey), findsOneWidget);
      expect(find.byKey(GameChatPlaceholder.placeholderKey), findsNothing);
      expect(find.byType(GameChatScreen), findsNothing);
      // The action goes back (no history after go: home).
      await tester.tap(find.byKey(GameChatAccessState.actionKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home')), findsOneWidget);
    },
  );

  for (final c in const [(false, false), (true, false), (false, true)]) {
    testWidgets('flags messaging=${c.$1} gameChat=${c.$2} show unavailable', (
      tester,
    ) async {
      final router = buildRouter(messaging: c.$1, gameChat: c.$2);
      await tester.pumpWidget(app(router));
      router.go('/messaging/game/g1');
      await tester.pumpAndSettle();
      expect(find.byKey(GameChatAccessState.unavailableKey), findsOneWidget);
      expect(find.byKey(GameChatPlaceholder.placeholderKey), findsNothing);
      expect(find.byType(GameChatScreen), findsNothing);
    });
  }

  testWidgets('both flags true shows the game chat screen with no redirect', (
    tester,
  ) async {
    final router = buildRouter(messaging: true, gameChat: true);
    await tester.pumpWidget(app(router));
    router.go('/messaging/game/g1');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/messaging/game/g1',
    );
    expect(find.byType(GameChatScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('home')), findsNothing);
  });

  testWidgets('placeholder body has no text', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: GameChatPlaceholder(),
      ),
    );
    expect(find.byKey(GameChatPlaceholder.placeholderKey), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });
}
