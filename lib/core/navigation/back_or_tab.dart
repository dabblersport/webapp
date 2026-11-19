// A screen a notification or deep link opens can be the only route on the
// stack (a cold start lands straight on it). Back then goes to the tab the
// screen belongs to instead of doing nothing: games for a game, meetups for a
// meetup, home for everything else.

import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The tab behind [path] when there is no route to pop back to.
String fallbackTabFor(String path) {
  if (path.startsWith(RoutePaths.gamesTab) ||
      path.startsWith('/game/') ||
      path.startsWith('${RoutePaths.games}/')) {
    return RoutePaths.gamesTab;
  }
  if (path.startsWith('${RoutePaths.meetups}/')) return RoutePaths.meetups;
  return RoutePaths.home;
}

/// Pops when there is a previous route, else goes to [fallbackTabFor] the
/// current location.
void backOrTab(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).maybePop();
    return;
  }
  if (router.canPop()) {
    router.pop();
    return;
  }
  router.go(
    fallbackTabFor(router.routerDelegate.currentConfiguration.uri.path),
  );
}

/// Routes the system back gesture through [backOrTab] when the screen is the
/// only route, so Android back never closes the app from a notification
/// landing.
class BackOrTabScope extends StatelessWidget {
  const BackOrTabScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null || router.canPop()) return child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) backOrTab(context);
      },
      child: child,
    );
  }
}
