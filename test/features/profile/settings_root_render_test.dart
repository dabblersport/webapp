import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_test_harness.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/settings_screen.dart';
import '../../support/render_mode.dart';
import 'settings_test_overrides.dart';

const String _shotsDir = String.fromEnvironment('SETTINGS_SHOTS_DIR');

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

const Key _key = Key('shot');

Future<void> _pump(WidgetTester tester, Widget screen, Locale locale) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: settingsDataOverrides(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
        home: screen,
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initHomeTestSupabase();
    await signInFakeUser();
    await loadRenderFonts();
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('settings root renders — $dir', (tester) async {
      await _pump(tester, const SettingsScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerInputRow), findsWidgets);
      await _shoot(tester, _key, 'settings-root-$dir');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await _shoot(tester, _key, 'settings-about-$dir');
    });

    testWidgets('settings search lists results — $dir', (tester) async {
      await _pump(tester, const SettingsScreen(), locale);
      await tester.enterText(find.byType(EditableText), 'priv');
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerStatTile), findsNothing);
      expect(find.byType(DabblerInputRow), findsWidgets);
      await _shoot(tester, _key, 'settings-search-$dir');

      await tester.enterText(find.byType(EditableText), 'zzzz');
      await _settle(tester);
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(SettingsScreen)),
          ).settings_search_no_match,
        ),
        findsOneWidget,
      );
    });

    testWidgets('tiles show the design set with real data — $dir', (
      tester,
    ) async {
      await _pump(tester, const SettingsScreen(), locale);
      expect(find.byType(DabblerStatTile), findsNWidgets(7));
      expect(find.text('Egypt'), locale.languageCode == 'en' ? findsOneWidget : findsNothing);
    });

    testWidgets('language & region, about and organiser sheets — $dir', (
      tester,
    ) async {
      await _pump(tester, const SettingsScreen(), locale);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SettingsScreen)),
      );
      await tester.tap(find.text(l10n.settings_tile_language_region));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('العربية'), findsWidgets);
      await _shoot(tester, _key, 'settings-language-sheet-$dir');
      Navigator.of(
        tester.element(find.text('العربية').first),
        rootNavigator: true,
      ).pop();
      await _settle(tester);

      await tester.scrollUntilVisible(
        find.text(l10n.settings_organiser_title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l10n.settings_organiser_title));
      await _settle(tester);
      expect(find.text(l10n.settings_organiser_start), findsOneWidget);
      await _shoot(tester, _key, 'settings-organiser-sheet-$dir');
      Navigator.of(
        tester.element(find.text(l10n.settings_organiser_start)),
        rootNavigator: true,
      ).pop();
      await _settle(tester);

      await tester.scrollUntilVisible(
        find.text(l10n.settings_about_title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l10n.settings_about_title));
      await _settle(tester);
      expect(find.text(l10n.settings_item_licenses_title), findsOneWidget);
      await _shoot(tester, _key, 'settings-about-sheet-$dir');
    });

    testWidgets('sign-out sheet renders — $dir', (tester) async {
      await _pump(tester, const SettingsScreen(), locale);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SettingsScreen)),
      );
      await tester.scrollUntilVisible(
        find.text(l10n.settings_sign_out_title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l10n.settings_sign_out_title));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.settings_sign_out_confirm_body), findsOneWidget);
      await _shoot(tester, _key, 'settings-signout-sheet-$dir');
    });
  }
}
