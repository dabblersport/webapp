// KAN-1052: the bottom bar hides Games without a challenge sport and Meetups
// without a can-solo sport; a hidden current branch falls back Home.

import 'package:dabbler/features/home/presentation/screens/main_navigation_screen.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_create_entry.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/sports/presentation/providers/my_sports_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart' show FakeFeed;
import 'my_sports_provider_test.dart' show catalogue;

Future<GoRouter> _pump(
  WidgetTester tester,
  MySports mine, {
  String initial = '/home',
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget branch(String label) => Center(child: DabblerEmptyState(title: label));
  GoRoute route(String path, String label) =>
      GoRoute(path: path, builder: (_, __) => branch(label));
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainNavigationScreen(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [route('/home', 'home-branch')]),
          StatefulShellBranch(routes: [route('/community', 'community')]),
          StatefulShellBranch(routes: [route('/venues', 'venues-branch')]),
          StatefulShellBranch(routes: [route('/games', 'games-branch')]),
          StatefulShellBranch(
            routes: [route(RoutePaths.meetups, 'meetups-branch')],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initializeProfileDataProvider.overrideWith((ref) async => false),
        meetupActorProfileIdProvider.overrideWithValue(null),
        activePersonaProvider.overrideWithValue(PersonaType.player),
        meetupsEnabledProvider.overrideWithValue(true),
        feedNotifierProvider.overrideWith(
          (ref) => FakeFeed(const FeedLoading()),
        ),
        mySportsNowProvider.overrideWithValue(mine),
        mySportsNavProvider.overrideWithValue(mine),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => DabblerToastProvider(child: child!),
        theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return router;
}

void main() {
  testWidgets('unscoped: Games and Meetups both show', (tester) async {
    await _pump(tester, MySports.none);
    expect(find.bySemanticsLabel('Games'), findsOneWidget);
    expect(find.bySemanticsLabel('Meetups'), findsOneWidget);
  });

  testWidgets('challenge sports only: Meetups is hidden', (tester) async {
    await _pump(tester, MySports.fromIds(catalogue, const ['fb']));
    expect(find.bySemanticsLabel('Games'), findsOneWidget);
    expect(find.bySemanticsLabel('Meetups'), findsNothing);
  });

  testWidgets('can-solo sports only: Games is hidden', (tester) async {
    await _pump(tester, MySports.fromIds(catalogue, const ['gym']));
    expect(find.bySemanticsLabel('Games'), findsNothing);
    expect(find.bySemanticsLabel('Meetups'), findsOneWidget);
    expect(find.bySemanticsLabel('Venues'), findsOneWidget);
  });

  testWidgets('a hidden current branch falls back Home', (tester) async {
    await _pump(
      tester,
      MySports.fromIds(catalogue, const ['fb']),
      initial: RoutePaths.meetups,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('home-branch'), findsOneWidget);
  });
}
