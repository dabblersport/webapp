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

/// Shared harness for the profile/settings render tests of the fidelity pass.
/// Writes PNGs only with `--dart-define=SETTINGS_SHOTS_DIR=<dir>`.
const String kProfileShotsDir = String.fromEnvironment('SETTINGS_SHOTS_DIR');

Future<void> loadProfileFonts() async {
  await loadRenderFonts();
}

Future<void> shootProfile(WidgetTester tester, Key key, String name) async {
  if (kProfileShotsDir.isEmpty) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(kProfileShotsDir).createSync(recursive: true);
    File('$kProfileShotsDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}



const Key kShotKey = Key('shot');

Future<void> pumpProfileScreen(
  WidgetTester tester,
  Widget screen,
  Locale locale, {
  List<Override> overrides = const [],
  double height = 852,
}) async {
  tester.view.physicalSize = Size(393, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DabblerToastProvider(
          child: RepaintBoundary(key: kShotKey, child: child),
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
  await settleProfile(tester);
}

Future<void> settleProfile(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
