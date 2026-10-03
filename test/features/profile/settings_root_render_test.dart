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

const String _shotsDir = String.fromEnvironment('SETTINGS_SHOTS_DIR');

Future<void> _loadFonts() async {
  final String dsFonts =
      '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
  }

  const String pkg = 'packages/dabbler_design_system';
  const List<String> glory = <String>[
    'Glory-Light.ttf',
    'Glory-Regular.ttf',
    'Glory-Medium.ttf',
    'Glory-SemiBold.ttf',
    'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf',
    'meral-sans-regular.ttf',
    'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf',
    'meral-sans-bold.ttf',
  ];
  for (final String prefix in <String>['$pkg/', '']) {
    await family('${prefix}Glory', glory);
    await family('${prefix}Gloock', <String>['Gloock-Regular.ttf']);
    await family('${prefix}Meral Sans', meral);
    await family('${prefix}Wingx', <String>['Wingx-Regular.otf']);
  }
  final String home = Platform.environment['HOME'] ?? '';
  final File iconsax = File(
    '$home/.pub-cache/hosted/pub.dev/iconsax_flutter-1.0.1/fonts/FlutterIconsax.ttf',
  );
  if (iconsax.existsSync()) {
    final FontLoader loader = FontLoader(
      'packages/iconsax_flutter/FlutterIconsax',
    )..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: _key, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(ThemeData.light()),
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
    await _loadFonts();
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

    testWidgets('settings search filters rows — $dir', (tester) async {
      await _pump(tester, const SettingsScreen(), locale);
      await tester.enterText(find.byType(EditableText), 'licen');
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await _shoot(tester, _key, 'settings-search-$dir');
    });

    testWidgets('country and language sheets render — $dir', (tester) async {
      await _pump(tester, const SettingsScreen(), locale);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SettingsScreen)),
      );
      await tester.scrollUntilVisible(
        find.text(l10n.settings_item_country_title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l10n.settings_item_country_title));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Morocco'), findsOneWidget);
      await _shoot(tester, _key, 'settings-country-sheet-$dir');
      Navigator.of(
        tester.element(find.text('Morocco')),
        rootNavigator: true,
      ).pop();
      await _settle(tester);

      await tester.scrollUntilVisible(
        find.text(l10n.settings_item_language_title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l10n.settings_item_language_title));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('العربية'), findsWidgets);
      await _shoot(tester, _key, 'settings-language-sheet-$dir');
    });

    testWidgets('sign-out dialog renders — $dir', (tester) async {
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
      expect(find.byType(DabblerDialog), findsOneWidget);
      await _shoot(tester, _key, 'settings-signout-dialog-$dir');
    });
  }
}
