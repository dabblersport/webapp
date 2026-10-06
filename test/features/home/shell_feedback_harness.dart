import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/core/feedback/feedback_center.dart';
import 'package:dabbler/core/feedback/toast_presenter.dart';
import 'package:dabbler/features/home/presentation/screens/main_navigation_screen.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_create_entry.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';
import 'home_test_harness.dart' show FakeFeed;

/// Where the Action Area renders land (`--dart-define=SHELL_SHOTS=1`).
const bool kShellShots = bool.fromEnvironment('SHELL_SHOTS');
const String kShellShotsDir = '$kShotsRoot/ds-action-area/app';
const Key kShotKey = Key('shell-shot');

/// The shell under a real GoRouter, the app's toast provider and the
/// feedback toast presenter, as `main.dart` mounts them.
class ShellHarness {
  ShellHarness(this.router, this.tester);
  final GoRouter router;
  final WidgetTester tester;

  ProviderContainer get container => ProviderScope.containerOf(
    tester.element(find.byType(MainNavigationScreen, skipOffstage: false)),
    listen: false,
  );
  FeedbackCenter get center => container.read(feedbackCenterProvider.notifier);
  FeedbackCenterState get state => container.read(feedbackCenterProvider);
  String get location => router.routeInformationProvider.value.uri.toString();

  DabblerNavigationStatus get status => tester.widget<DabblerNavigationStatus>(
    find.byType(DabblerNavigationStatus),
  );

  DabblerActionAreaPhase get phase =>
      tester.widget<DabblerActionArea>(find.byType(DabblerActionArea)).phase;

  /// Pumps [ms] in 50ms steps (spinners never settle).
  Future<void> advance(int ms) async {
    for (var t = 0; t < ms; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

Future<ShellHarness> pumpShell(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  bool reduceMotion = false,
  double bottomInset = 0,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(bottom: bottomInset);
  addTearDown(tester.view.reset);

  Widget branch(String label) => Center(child: DabblerEmptyState(title: label));
  GoRoute r(String p) => GoRoute(path: p, builder: (_, __) => branch('$p-b'));
  // As the app: internal routes live on the root navigator, over the shell.
  final root = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: root,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainNavigationScreen(navigationShell: shell),
        branches: [
          for (final p in [
            '/home',
            '/community',
            '/venues',
            '/games',
            '/meetups',
          ])
            StatefulShellBranch(routes: [r(p)]),
        ],
      ),
      GoRoute(
        path: '/internal',
        parentNavigatorKey: root,
        builder: (_, __) => branch('/internal-b'),
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
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(disableAnimations: reduceMotion),
            child: DabblerToastProvider(
              child: FeedbackToastPresenter(
                child: RepaintBoundary(key: kShotKey, child: child),
              ),
            ),
          );
        },
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return ShellHarness(router, tester);
}

/// Writes the shell as a PNG when [kShellShots] is on.
Future<void> shootShell(WidgetTester tester, String name) async {
  if (!kShellShots) return;
  final theme = const String.fromEnvironment('RENDER_DARK') == '1'
      ? 'dark'
      : 'light';
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(kShotKey)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(kShellShotsDir).createSync(recursive: true);
    File(
      '$kShellShotsDir/$name-$theme.png',
    ).writeAsBytesSync(png!.buffer.asUint8List());
  });
}
