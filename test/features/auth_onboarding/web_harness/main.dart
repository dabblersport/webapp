// Chrome harness for KAN-489 (run: flutter run -d web-server -t this file).
// Real WelcomeScreen / LocationIntroScreen / routes / browser permission
// adapter; only auth is faked (fixed user id, no sign-in, no live writes).
// Query: ?mode=back|first  &lang=en|ar  &dark=1  &reset=1 (clear the flag).
import 'package:dabbler/app/app_router.dart' show rootNavigatorKey;
import 'package:dabbler/app/routes/identity_routes.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/welcome_screen.dart';
import 'package:dabbler/features/location/location_intro/location_intro.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: 'https://harness.invalid', anonKey: 'x');
  final q = Uri.base.queryParameters;
  final returning = q['mode'] != 'first';
  final locale = Locale(q['lang'] ?? 'en');
  final dark = q['dark'] == '1';
  if (q['reset'] == '1') {
    (await SharedPreferences.getInstance()).remove(
      'location_intro_seen_harness-user',
    );
  }
  routerRefreshNotifier.requirePostLoginWelcome();
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.welcome,
    refreshListenable: routerRefreshNotifier,
    redirect: (context, state) async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
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
          primarySportKey: returning ? null : 'football',
        ),
      ),
      locationIntroRoute,
      GoRoute(
        path: RoutePaths.home,
        builder: (_, __) => const Scaffold(body: Center(child: Text('HOME'))),
      ),
    ],
  );
  runApp(
    ProviderScope(
      overrides: [
        locationIntroUserIdProvider.overrideWithValue('harness-user'),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: DabblerDesignSystemTheme.withTokens(
          ThemeData(brightness: Brightness.light),
        ),
        darkTheme: DabblerDesignSystemTheme.withTokens(
          ThemeData(brightness: Brightness.dark),
        ),
      ),
    ),
  );
}
