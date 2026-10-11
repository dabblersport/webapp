import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/auth_onboarding/presentation/screens/welcome_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/welcome_sport_poster.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';

/// Welcome Back layout (welcome-back-text): avatar at the start/top, one white
/// card under it with the greeting and the persona's line, Continue at the
/// bottom, the sport poster (KAN-490) behind it unchanged.
/// Renders: `--dart-define=WELCOME_BACK_DIR=<dir>` (+ `RENDER_DARK=1`).
const String _dir = String.fromEnvironment('WELCOME_BACK_DIR');
final bool _dark = const String.fromEnvironment('RENDER_DARK') == '1';

Future<void> _pump(
  WidgetTester tester, {
  String persona = 'player',
  String? sport,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  addTearDown(tester.view.resetPadding);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            RepaintBoundary(key: const Key('shot'), child: child!),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: WelcomeScreen(
          displayName: 'Sam Player',
          personaType: persona,
          isFirstTime: false,
          savedSportLoader: () async => sport,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final asset = welcomePosterAsset(sport);
  if (asset != null) {
    await tester.runAsync(() async {
      await precacheImage(
        AssetImage(asset),
        tester.element(find.byType(WelcomeScreen)),
      );
    });
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _shoot(WidgetTester tester, String name) async {
  if (_dir.isEmpty) return;
  await tester.runAsync(() async {
    final b =
        tester.renderObject(find.byKey(const Key('shot')))
            as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_dir).createSync(recursive: true);
    File('$_dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await loadRenderFonts();
  });

  final String mode = _dark ? 'dark' : 'light';
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  Rect rectOf(WidgetTester t, Finder f) => t.getRect(f.first);

  for (final (String lang, Locale locale, bool rtl) in <(String, Locale, bool)>[
    ('en', const Locale('en'), false),
    ('ar', const Locale('ar'), true),
  ]) {
    for (final sport in <String?>['football', 'cricket', 'swimming', null]) {
      testWidgets('structure: avatar at the start, card under it, Continue at '
          'the bottom - $lang ${sport ?? 'no poster'}', (tester) async {
        await _pump(tester, sport: sport, locale: locale);
        final l = rtl ? ar : en;
        final avatar = find.byType(DabblerAvatar);
        final card = find.ancestor(
          of: find.text(l.auth_welcome_back_title('Sam')),
          matching: find.byType(DabblerCard),
        );
        final button = find.byType(DabblerButton);
        expect(avatar, findsOneWidget);
        expect(card, findsOneWidget);
        final a = rectOf(tester, avatar);
        final c = rectOf(tester, card);
        final b = rectOf(tester, button);
        // Avatar near the top, under the status bar, on the start side.
        expect(a.top, greaterThan(59));
        expect(a.top, lessThan(140));
        if (rtl) {
          expect(a.right, closeTo(c.right, 1), reason: 'avatar top-right');
        } else {
          expect(a.left, closeTo(c.left, 1), reason: 'avatar top-left');
        }
        // Card directly under the avatar; Continue pinned at the bottom.
        expect(c.top, greaterThan(a.bottom));
        expect(c.top - a.bottom, lessThan(48));
        expect(c.bottom, lessThan(b.top - 200), reason: 'poster fills the gap');
        expect(b.bottom, greaterThan(874 - 34 - 80));
        // Heading and quote live in the same single card.
        expect(find.byType(DabblerCard), findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.text(l.persona_player_principle),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _shoot(tester, 'wb-${sport ?? 'plain'}-$lang-$mode');
      });
    }
  }

  group('persona quote', () {
    final cases = <String, String Function(AppLocalizations)>{
      'socialiser': (l) => l.persona_socialiser_principle,
      'player': (l) => l.persona_player_principle,
      'organiser': (l) => l.persona_organiser_principle,
      'host': (l) => l.persona_host_principle,
    };
    for (final lang in <(String, Locale, AppLocalizations)>[
      ('en', const Locale('en'), en),
      ('ar', const Locale('ar'), ar),
    ]) {
      for (final e in cases.entries) {
        testWidgets('${e.key} shows its own quote - ${lang.$1}', (
          tester,
        ) async {
          await _pump(
            tester,
            persona: e.key,
            sport: 'football',
            locale: lang.$2,
          );
          expect(find.text(e.value(lang.$3)), findsOneWidget);
          for (final other in cases.entries.where((o) => o.key != e.key)) {
            expect(find.text(other.value(lang.$3)), findsNothing);
          }
          await _shoot(tester, 'wb-quote-${e.key}-${lang.$1}-$mode');
        });
      }
    }

    for (final unknown in <String>['', 'robot', 'guest']) {
      testWidgets('unknown persona "$unknown" shows no quote', (tester) async {
        await _pump(tester, persona: unknown, sport: 'football');
        expect(find.text(en.auth_welcome_back_title('Sam')), findsOneWidget);
        for (final q in <String>[
          en.persona_socialiser_principle,
          en.persona_player_principle,
          en.persona_organiser_principle,
          en.persona_host_principle,
        ]) {
          expect(find.text(q), findsNothing);
        }
      });
    }
  });

  testWidgets('the poster behind is exactly the KAN-490 poster', (
    tester,
  ) async {
    await _pump(tester, sport: 'football');
    final bg = tester.widget<DabblerSportBackground>(
      find.byType(DabblerSportBackground),
    );
    expect(bg.artwork!.assetPath, welcomeSportPosters['football']);
    expect(bg.fit, BoxFit.cover);
    expect(bg.alignment, Alignment.center);
    // Full bleed: the poster fills the whole screen.
    expect(
      tester.getRect(find.byType(DabblerSportBackground)).size,
      const Size(402, 874),
    );
  });

  testWidgets('Continue label and action are unchanged', (tester) async {
    await _pump(tester);
    expect(find.text(en.auth_welcome_continue), findsOneWidget);
  });
}
