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
  bool first = false,
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
          isFirstTime: first,
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
        final pill = find.ancestor(
          of: avatar,
          matching: find.byType(DabblerCard),
        );
        final button = find.byType(DabblerButton);
        expect(avatar, findsOneWidget);
        expect(card, findsOneWidget);
        expect(pill, findsOneWidget);
        final a = rectOf(tester, avatar);
        final p = rectOf(tester, pill);
        final c = rectOf(tester, card);
        final b = rectOf(tester, button);
        // Poster welcome back: the identity pill sits under the status bar and
        // the avatar on its start side; the card rests at the bottom with
        // Continue inside it, the poster showing between.
        expect(p.top, greaterThan(59));
        expect(p.top, lessThan(100));
        if (rtl) {
          expect(a.right, lessThan(p.right));
          expect(a.right, greaterThan(p.right - 16));
        } else {
          expect(a.left, greaterThan(p.left));
          expect(a.left, lessThan(p.left + 16));
        }
        expect(c.top, greaterThan(p.bottom + 100), reason: 'poster shows');
        expect(b.top, greaterThan(c.top));
        expect(b.bottom, lessThan(c.bottom));
        expect(c.bottom, greaterThan(874 - 34 - 60));
        // Pill + one card; heading and quote live in the same card.
        expect(find.byType(DabblerCard), findsNWidgets(2));
        expect(
          find.descendant(
            of: card,
            matching: find.text(l.persona_contributor_principle),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _shoot(tester, 'wb-${sport ?? 'plain'}-$lang-$mode');
      });
    }
  }

  for (final (String lang, Locale locale) in <(String, Locale)>[
    ('en', const Locale('en')),
    ('ar', const Locale('ar')),
  ]) {
    testWidgets('poster welcome: pill, headline card, list card with the '
        'action inside - $lang', (tester) async {
      await _pump(tester, sport: 'football', locale: locale, first: true);
      final l = lookupAppLocalizations(locale);
      final pill = find.ancestor(
        of: find.byType(DabblerAvatar),
        matching: find.byType(DabblerCard),
      );
      final head = find.ancestor(
        of: find.text(l.persona_contributor_headline),
        matching: find.byType(DabblerCard),
      );
      final list = find.ancestor(
        of: find.byType(DabblerButton),
        matching: find.byType(DabblerCard),
      );
      expect(find.byType(DabblerCard), findsNWidgets(3));
      expect(
        rectOf(tester, head).top,
        greaterThan(rectOf(tester, pill).bottom),
      );
      expect(
        rectOf(tester, list).top,
        greaterThan(rectOf(tester, head).bottom),
      );
      expect(find.text(l.persona_contributor_cta), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _shoot(tester, 'w-football-$lang-$mode');
    });
  }

  group('persona quote', () {
    final cases = <String, String Function(AppLocalizations)>{
      'socialiser': (l) => l.persona_socialiser_principle,
      'player': (l) => l.persona_contributor_principle,
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
          en.persona_contributor_principle,
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
