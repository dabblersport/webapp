import 'package:dabbler/app/app_router.dart' show rootNavigatorKey;
import 'package:dabbler/app/routes/identity_routes.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/location_intro_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/welcome_screen.dart';
import 'package:dabbler/features/location/location_intro/location_intro.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-489 on Alpha: Continue on Welcome / Welcome Back must reach the
/// location intro. The router below refreshes from the real
/// [routerRefreshNotifier] and applies the same post-login-welcome rule as
/// `app_router.dart`, so it catches the hand-off being undone by the router.

class _Gateway implements LocationPermissionGateway {
  _Gateway(this.onCheck);
  final Future<LocationPermission> Function() onCheck;
  int requests = 0;
  @override
  Future<LocationPermission> check() async {
    // A browser permission query is a JS promise: never instant.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return onCheck();
  }

  @override
  Future<LocationPermission> request() async {
    requests++;
    return LocationPermission.whileInUse;
  }

  @override
  Future<bool> servicesEnabled() async => true;
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _Gateway gateway, {
  required bool returning,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  routerRefreshNotifier.requirePostLoginWelcome();
  addTearDown(routerRefreshNotifier.clearPostLoginWelcome);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.welcome,
    refreshListenable: routerRefreshNotifier,
    redirect: (context, state) async {
      // The real redirect awaits Supabase (profile / onboarding lookups).
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (routerRefreshNotifier.needsPostLoginWelcome &&
          state.matchedLocation != RoutePaths.welcome) {
        return RoutePaths.welcome;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RoutePaths.welcome,
        redirect: (context, state) =>
            routerRefreshNotifier.needsPostLoginWelcome
            ? null
            : RoutePaths.home,
        builder: (_, __) => WelcomeScreen(
          displayName: 'Sam Player',
          personaType: 'player',
          isFirstTime: !returning,
        ),
      ),
      locationIntroRoute,
      GoRoute(
        path: RoutePaths.home,
        builder: (_, __) => const Scaffold(body: Text('HOME-SENTINEL')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationPermissionGatewayProvider.overrideWithValue(gateway),
        locationIntroUserIdProvider.overrideWithValue('web-user-1'),
        locationIntroControllerProvider.overrideWith(
          (ref) => LocationIntroController(gateway, () async => true),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  return router;
}

Future<void> _tapContinue(
  WidgetTester tester, {
  required bool returning,
}) async {
  final finder = find.byType(DabblerButton);
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // The browser's Permissions API maps to: prompt -> denied (first visit),
  // denied -> deniedForever, granted -> whileInUse, unsupported ->
  // unableToDetermine; an unexpected state throws ArgumentError.
  final Map<String, Future<LocationPermission> Function()> shown = {
    'web first visit (prompt -> denied)': () async => LocationPermission.denied,
    'web blocked (denied -> deniedForever)': () async =>
        LocationPermission.deniedForever,
    'web without Permissions API (unableToDetermine)': () async =>
        LocationPermission.unableToDetermine,
    'web permission read throws': () async =>
        throw ArgumentError('unsupported cannot be converted'),
  };

  for (final returning in <bool>[true, false]) {
    final String path = returning ? 'Welcome Back' : 'Welcome';
    for (final e in shown.entries) {
      testWidgets('$path -> Continue shows the intro: ${e.key}', (
        tester,
      ) async {
        final g = _Gateway(e.value);
        await _pump(tester, g, returning: returning);
        await _tapContinue(tester, returning: returning);
        expect(find.byType(LocationIntroScreen), findsOneWidget);
        expect(find.text('HOME-SENTINEL'), findsNothing);
        expect(g.requests, 0, reason: 'Continue must not prompt');
      });
    }

    testWidgets('$path -> Continue skips the intro when the browser/OS '
        'already granted location', (tester) async {
      final g = _Gateway(() async => LocationPermission.whileInUse);
      await _pump(tester, g, returning: returning);
      await _tapContinue(tester, returning: returning);
      expect(find.byType(LocationIntroScreen), findsNothing);
      expect(find.text('HOME-SENTINEL'), findsOneWidget);
    });
  }

  group('decideLocationIntro (why it shows or skips)', () {
    const store = LocationIntroStore();
    test(
      'skip reasons are distinguishable and a throw shows the page',
      () async {
        Future<LocationIntroDecision> d(
          String? user,
          Future<LocationPermission> Function() check,
        ) => decideLocationIntro(
          userId: user,
          gateway: _Gateway(check),
          store: store,
        );
        expect(
          await d(null, () async => LocationPermission.denied),
          LocationIntroDecision.skipNoUser,
        );
        expect(
          await d('u', () async => LocationPermission.whileInUse),
          LocationIntroDecision.skipPermissionGranted,
        );
        expect(
          await d('u', () async => throw StateError('web')),
          LocationIntroDecision.show,
        );
        await store.markSeen('u');
        expect(
          await d('u', () async => LocationPermission.denied),
          LocationIntroDecision.skipAlreadySeen,
        );
      },
    );
  });
}
