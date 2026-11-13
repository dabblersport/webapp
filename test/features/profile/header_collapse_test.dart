// KAN-601: the pinned top bar's reveal point is measured, flips with
// hysteresis, and is held compact by a focused search.
import 'package:dabbler/features/profile/presentation/screens/settings/header_collapse.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/settings_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import '../home/home_test_harness.dart';
import 'settings_test_overrides.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpSettings(
  WidgetTester tester,
  Locale locale, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: settingsDataOverrides(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: const SettingsScreen(),
      ),
    ),
  );
  await _settle(tester);
}

DabblerNavigationTopBar _bar(WidgetTester tester) => tester
    .widget<DabblerNavigationTopBar>(find.byType(DabblerNavigationTopBar));

double _pixels(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

void main() {
  group('HeaderCollapseController', () {
    Future<HeaderCollapseController> pump(WidgetTester tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final controller = HeaderCollapseController(scroll);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView(
            controller: scroll,
            children: const [SizedBox(height: 3000)],
          ),
        ),
      );
      return controller;
    }

    testWidgets('a short hero is floored at the design minimum', (
      tester,
    ) async {
      final c = await pump(tester);
      c.measure(4);
      expect(c.extent, HeaderCollapseController.minExtent);
    });

    testWidgets('flips only past the hysteresis band, either way', (
      tester,
    ) async {
      final c = await pump(tester);
      c.measure(200);
      const h = HeaderCollapseController.hysteresis;

      c.scroll.jumpTo(200 + h - 1);
      expect(c.collapsed, isFalse, reason: 'inside the band stays expanded');
      c.scroll.jumpTo(200 + h + 1);
      expect(c.collapsed, isTrue);
      c.scroll.jumpTo(200 - h + 1);
      expect(c.collapsed, isTrue, reason: 'inside the band stays collapsed');
      c.scroll.jumpTo(200 - h - 1);
      expect(c.collapsed, isFalse);
    });

    testWidgets('the reveal offset sits on the far side of the band', (
      tester,
    ) async {
      final c = await pump(tester);
      c.measure(200);
      const h = HeaderCollapseController.hysteresis;
      expect(c.revealOffset, 200 + h);
      c.scroll.jumpTo(300);
      expect(c.revealOffset, 200 - h);
    });

    testWidgets('a focused search holds the bar compact without scrolling', (
      tester,
    ) async {
      final c = await pump(tester);
      c.measure(200);
      c.pinnedCompact = true;
      expect(c.revealOffset, lessThan(0));
      expect(c.scroll.position.pixels, 0);
      c.pinnedCompact = false;
      expect(c.revealOffset, 200 + HeaderCollapseController.hysteresis);
    });

    testWidgets('a re-measure inside half a pixel is ignored', (tester) async {
      final c = await pump(tester);
      c.measure(200);
      var notified = 0;
      c.addListener(() => notified++);
      c.measure(200.3);
      expect(notified, 0);
      c.measure(240);
      expect(notified, 1);
      expect(c.extent, 240);
    });
  });

  group('Settings header', () {
    setUpAll(() async {
      await initHomeTestSupabase();
      await signInFakeUser();
      await loadRenderFonts();
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

      testWidgets('reveal offset is the measured hero height — $dir', (
        tester,
      ) async {
        await _pumpSettings(tester, locale);
        final hero = tester.getSize(find.byType(DabblerSettingsHeader)).height;
        expect(
          _bar(tester).titleRevealOffset,
          hero + HeaderCollapseController.hysteresis,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('large text moves the reveal offset with the hero — $dir', (
        tester,
      ) async {
        await _pumpSettings(tester, locale);
        final normal = _bar(tester).titleRevealOffset;
        await _pumpSettings(tester, locale, textScale: 1.6);
        final hero = tester.getSize(find.byType(DabblerSettingsHeader)).height;
        expect(
          _bar(tester).titleRevealOffset,
          hero + HeaderCollapseController.hysteresis,
        );
        expect(_bar(tester).titleRevealOffset, greaterThan(normal));
        expect(tester.takeException(), isNull);
      });

      testWidgets('scrolling past the hero collapses, back up expands — $dir', (
        tester,
      ) async {
        await _pumpSettings(tester, locale);
        final hero = tester.getSize(find.byType(DabblerSettingsHeader)).height;
        final scrollable = find.byType(Scrollable).first;

        await tester.drag(scrollable, Offset(0, -(hero + 40)));
        await _settle(tester);
        expect(
          _bar(tester).titleRevealOffset,
          hero - HeaderCollapseController.hysteresis,
        );

        await tester.drag(scrollable, Offset(0, hero + 40));
        await _settle(tester);
        expect(
          _bar(tester).titleRevealOffset,
          hero + HeaderCollapseController.hysteresis,
        );
      });

      testWidgets('a focused search keeps the bar compact, no jump — $dir', (
        tester,
      ) async {
        await _pumpSettings(tester, locale);
        final before = _pixels(tester);
        await tester.tap(find.byType(EditableText));
        await _settle(tester);
        expect(_bar(tester).titleRevealOffset, lessThan(0));
        expect(_pixels(tester), before);

        // Blur returns the measured state.
        FocusManager.instance.primaryFocus?.unfocus();
        await _settle(tester);
        final hero = tester.getSize(find.byType(DabblerSettingsHeader)).height;
        expect(
          _bar(tester).titleRevealOffset,
          hero + HeaderCollapseController.hysteresis,
        );
      });

      testWidgets('the search stays pinned while the list scrolls — $dir', (
        tester,
      ) async {
        await _pumpSettings(tester, locale);
        final scrollable = find.byType(Scrollable).first;
        final top = tester.getTopLeft(find.byType(EditableText)).dy;
        await tester.drag(scrollable, const Offset(0, -700));
        await _settle(tester);
        final pinned = tester.getTopLeft(find.byType(EditableText)).dy;
        expect(find.byType(EditableText), findsOneWidget);
        expect(pinned, lessThan(top));
        expect(pinned, greaterThan(0));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
