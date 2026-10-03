import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/profile/presentation/screens/preferences/game_preferences_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/render_mode.dart';

/// Renders the DS game preferences screen (no design frame: DS-default). Writes PNGs only with
/// `--dart-define=SETTINGS_SHOTS_DIR=<dir>`; otherwise it still pumps every
/// state LTR and RTL and checks it renders cleanly.
const String _shotsDir = String.fromEnvironment('SETTINGS_SHOTS_DIR');

Future<void> _loadFonts() async {
  final String dsFonts = '${Directory.current.parent.path}/dabbler-design-system/fonts';
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) return;
      loader.addFont(
        file.readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }

  const String pkg = 'packages/dabbler_design_system';
  const List<String> glory = <String>[
    'Glory-Light.ttf', 'Glory-Regular.ttf', 'Glory-Medium.ttf',
    'Glory-SemiBold.ttf', 'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf', 'meral-sans-regular.ttf', 'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf', 'meral-sans-bold.ttf',
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
    final FontLoader loader = FontLoader('packages/iconsax_flutter/FlutterIconsax')
      ..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

Future<void> _shoot(WidgetTester tester, Key key, String name) async {
  if (_shotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shotsDir).createSync(recursive: true);
    File('$_shotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}



const Key _shotKey = Key('shot');

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Locale locale, {
  double height = 852,
}) async {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: _shotKey, child: child),
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
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}


void main() {
  setUpAll(_loadFonts);

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String dir = locale.languageCode == 'ar' ? 'rtl' : 'ltr';

    testWidgets('game preferences default — $dir', (tester) async {
      await _pump(tester, const GamePreferencesScreen(), locale, height: 2600);
      expect(tester.takeException(), isNull);
      expect(find.text('Game Preferences'), findsOneWidget);
      expect(find.byType(DabblerCheckbox), findsNWidgets(6));
      expect(find.byType(DabblerRadio), findsNWidgets(8));
      expect(find.byType(DabblerChip), findsNWidgets(6));
      expect(find.byType(DabblerSlider), findsNothing);
      await _shoot(tester, _shotKey, 'game-preferences-default-$dir');
    });

    testWidgets('game preferences custom — $dir', (tester) async {
      await _pump(tester, const GamePreferencesScreen(), locale, height: 2800);
      await _tap(tester, find.text('Flexible Duration'));
      await _tap(tester, find.text('Flexible Team Size'));
      await _tap(tester, find.text('Leagues'));
      expect(tester.takeException(), isNull);
      expect(find.text('Custom Duration Range'), findsOneWidget);
      expect(find.text('Min Duration'), findsOneWidget);
      expect(find.byType(DabblerSlider), findsOneWidget);
      expect(find.text('Preferred Team Size: 5 - 11 players'), findsOneWidget);
      await _shoot(tester, _shotKey, 'game-preferences-custom-$dir');
    });

    testWidgets('game preferences save toast — $dir', (tester) async {
      await _pump(tester, const GamePreferencesScreen(), locale);
      await tester.tap(find.bySemanticsLabel('Save'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Game preferences saved!'), findsOneWidget);
      await _shoot(tester, _shotKey, 'game-preferences-saved-$dir');
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
