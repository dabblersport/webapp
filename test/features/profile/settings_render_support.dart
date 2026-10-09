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

import '../../support/render_mode.dart';

/// Writes PNGs only with `--dart-define=SETTINGS_SHOTS_DIR=<dir>`.
const String settingsShotsDir = String.fromEnvironment('SETTINGS_SHOTS_DIR');

const Key settingsShotKey = Key('shot');

/// Loads the design-system faces and Iconsax so a render shows real glyphs.
Future<void> loadSettingsFonts() async {
  await loadRenderFonts();
}

/// Pumps [home] in a 393-wide app of [locale], inside a repaint boundary keyed
/// [settingsShotKey].
Future<void> pumpSettings(
  WidgetTester tester,
  Widget home,
  Locale locale, {
  List<Override> overrides = const <Override>[],
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: settingsShotKey, child: child),
        ),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: locale,
        ),
        home: home,
      ),
    ),
  );
  await settleSettings(tester);
}

Future<void> settleSettings(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Writes the current frame as `<SETTINGS_SHOTS_DIR>/<name>.png`.
Future<void> shootSettings(WidgetTester tester, String name) async {
  if (settingsShotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(settingsShotKey))
            as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(settingsShotsDir).createSync(recursive: true);
    File(
      '$settingsShotsDir/$name.png',
    ).writeAsBytesSync(png!.buffer.asUint8List());
  });
}
