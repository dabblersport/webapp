import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/intent_selection_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/welcome_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// KAN-681: renders the three Contributor welcome variants (Connect,
/// Play & organise, Organise) and step 2 in EN and AR. PNGs are written only
/// when `--dart-define=WELCOME_VARIANTS_DIR=<dir>` is passed (+ `RENDER_DARK=1`).
const String _dir = String.fromEnvironment('WELCOME_VARIANTS_DIR');
const Key _key = Key('shot');

Future<void> _shoot(WidgetTester tester, String name) async {
  if (_dir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject(find.byKey(_key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_dir).createSync(recursive: true);
    File('$_dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pump(
  WidgetTester tester,
  Locale locale,
  RouterConfig<Object> router,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 50);
  tester.view.viewPadding = const FakeViewPadding(top: 50);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: _key, child: child),
        ),
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
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await _settle(tester);
}

GoRouter _welcomeRouter(String intention) => GoRouter(
  initialLocation: '/',
  initialExtra: {'onboardingIntention': intention},
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const WelcomeScreen(
        displayName: 'Marcus Adeyemi',
        personaType: 'player',
        isFirstTime: true,
        primarySportKey: 'football',
      ),
    ),
  ],
);

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);
  final dark = const String.fromEnvironment('RENDER_DARK') == '1';
  final mode = dark ? 'dark' : 'light';

  const variants = <String, String>{
    'connect': 'connect_play',
    'play-organise': 'play_organise',
    'organise': 'organise',
  };

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final lang = locale.languageCode;
    for (final e in variants.entries) {
      testWidgets('welcome ${e.key} — $lang $mode', (tester) async {
        DabblerSportBackgroundRegistry.registerConventionalMainArtwork(
          DabblerSportBackgroundRegistry.mainPopulated,
          DabblerSportBackgroundRegistry.assetPackage,
        );
        await _pump(tester, locale, _welcomeRouter(e.value));
        expect(tester.takeException(), isNull);
        await _shoot(tester, 'welcome-${e.key}-$lang-$mode');
      }, variant: desktop);
    }
  }

  testWidgets('step 2 intention — ar $mode', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const IntentSelectionScreen(),
        ),
      ],
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(onboardingDataProvider.notifier)
        .initWithEmail('aisha@example.com');
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 50);
    tester.view.viewPadding = const FakeViewPadding(top: 50);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          builder: (context, child) => DabblerToastProvider(
            child: RepaintBoundary(key: _key, child: child),
          ),
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DabblerDesignSystemTheme.withFonts(
            DabblerDesignSystemTheme.withTokens(renderThemeBase()),
            locale: const Locale('ar'),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await _shoot(tester, 'step2-intention-ar-$mode');
  }, variant: desktop);
}
