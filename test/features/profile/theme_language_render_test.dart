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
import 'package:dabbler/features/profile/presentation/screens/theme_settings_screen.dart';
import 'package:dabbler/features/auth_onboarding/presentation/screens/language_selection_screen.dart';
import 'package:dabbler/features/misc/presentation/screens/help_center_screen.dart';
import '../../support/render_mode.dart';

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
    await _loadFonts();
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('theme settings renders both auto states — $dir', (
      tester,
    ) async {
      await _pump(tester, const ThemeSettingsScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.byType(DabblerTabs), findsOneWidget);
      await _shoot(tester, _key, 'appearance-default-$dir');

      await tester.scrollUntilVisible(find.byType(DabblerToggle), 200);
      await tester.tap(find.byType(DabblerToggle));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await _shoot(tester, _key, 'appearance-toggled-$dir');
      // Whichever state the toggle reached, the tabs permit no selection and
      // show none exactly while the time-based theme is on.
      final tabs = tester.widget<DabblerTabs>(find.byType(DabblerTabs));
      expect(tabs.allowNoSelection, isTrue);
      final auto = tester
          .widget<DabblerToggle>(find.byType(DabblerToggle))
          .checked;
      expect(tabs.value == null, auto);
      // restore singleton state
      await tester.tap(find.byType(DabblerToggle));
      await _settle(tester);
    });

    testWidgets('theme mode segmented control selects — $dir', (tester) async {
      await _pump(tester, const ThemeSettingsScreen(), locale);
      await tester.tap(find.text('Dark'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Always use dark theme'), findsOneWidget);
      await _shoot(tester, _key, 'appearance-dark-$dir');
    });

    testWidgets('language selection renders — $dir', (tester) async {
      await _pump(tester, const LanguageSelectionScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.text('العربية'), findsOneWidget);
      await tester.tap(find.text('العربية'));
      await _settle(tester);
      await _shoot(tester, _key, 'language-selected-$dir');
    });

    testWidgets('help center renders — $dir', (tester) async {
      await _pump(tester, const HelpCenterScreen(), locale);
      expect(tester.takeException(), isNull);
      expect(find.text('This screen is under development'), findsOneWidget);
      await _shoot(tester, _key, 'help-center-default-$dir');
    });
  }
}
