import 'package:dabbler/features/auth_onboarding/presentation/screens/welcome_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-681: onboarding clears its data before it opens the welcome, so the
/// Contributor welcome variant has to come from the route extra.
Future<void> _pump(WidgetTester tester, Object? extra) async {
  tester.view.physicalSize = const Size(700, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/',
    initialExtra: extra,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => WelcomeScreen(
          displayName: 'Sam',
          personaType: 'player',
          isFirstTime: true,
          savedSportLoader: () async => null,
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: const Locale('en'),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
  });

  testWidgets('connect_play extra shows the connect copy', (tester) async {
    await _pump(tester, {'onboardingIntention': 'connect_play'});
    expect(find.text('Your sports circle starts here.'), findsOneWidget);
  });

  testWidgets('organise extra shows the organise copy', (tester) async {
    await _pump(tester, {'onboardingIntention': 'organise'});
    expect(find.text('Time to bring the game together.'), findsOneWidget);
  });

  testWidgets('play_organise and missing extra keep the default copy', (
    tester,
  ) async {
    await _pump(tester, {'onboardingIntention': 'play_organise'});
    expect(find.text('You’re in. Let’s play.'), findsOneWidget);
    await _pump(tester, null);
    expect(find.text('You’re in. Let’s play.'), findsOneWidget);
  });
}
