import 'package:dabbler/app/app_router.dart';
import 'package:dabbler/features/messaging/presentation/game_chat_route.dart';
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

  test('redirect matches the existing disabled-messaging behaviour (home)', () {
    expect(gameChatRedirect(), RoutePaths.home);
    expect(gameChatRedirect(messaging: true, gameChat: false), RoutePaths.home);
    expect(gameChatRedirect(messaging: true, gameChat: true), isNull);
  });

  test('with all flags false the app router does not register the route', () {
    expect(
      _hasPath(AppRouter.router.configuration.routes, gameChatRoutePath),
      isFalse,
    );
  });

  testWidgets('navigating to the route with flags false ends on home', (
    tester,
  ) async {
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
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/messaging/game/g1');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, RoutePaths.home);
    expect(find.byKey(const ValueKey('home')), findsOneWidget);
    expect(find.byKey(GameChatPlaceholder.placeholderKey), findsNothing);
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
