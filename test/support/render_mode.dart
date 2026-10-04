import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' show WidgetTester;
import 'package:flutter/material.dart';

/// Base theme for render tests: light by default, dark when the run passes
/// `--dart-define=RENDER_DARK=1`.
ThemeData renderThemeBase() =>
    const String.fromEnvironment('RENDER_DARK') == '1'
    ? ThemeData.dark()
    : ThemeData.light();

/// Root folder render tests write PNGs under (`--dart-define=SHOTS_ROOT=...`).
const String kShotsRoot = String.fromEnvironment(
  'SHOTS_ROOT',
  defaultValue: '/Users/moataz/Desktop/Dabbler-Alpha-Plan',
);

/// Lets bundled and network images load for real (asset IO happens outside
/// the fake-async zone) before a render is captured.
Future<void> settleImages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Loads the design-system fonts for a render test (call from `setUpAll`).
///
/// Wingx, the Arabic display face, draws Arabic only — it has no Latin
/// letters. Latin text under an Arabic locale (data that is not translated)
/// therefore needs a fallback, and the test engine has none, so it drew
/// black blocks. This registers Gloock (the Latin display face) and Glory
/// under the fallback family names the engine consults, so those glyphs draw.
Future<void> loadRenderFonts() async {
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

  const List<String> glory = <String>[
    'Glory-Light.ttf', 'Glory-Regular.ttf', 'Glory-Medium.ttf',
    'Glory-SemiBold.ttf', 'Glory-Bold.ttf',
  ];
  const List<String> meral = <String>[
    'meral-sans-light.ttf', 'meral-sans-regular.ttf', 'meral-sans-medium.ttf',
    'meral-sans-semibold.ttf', 'meral-sans-bold.ttf',
  ];
  for (final String prefix in <String>['packages/dabbler_design_system/', '']) {
    await family('${prefix}Glory', glory);
    await family('${prefix}Gloock', <String>['Gloock-Regular.ttf']);
    await family('${prefix}Meral Sans', meral);
    await family('${prefix}Wingx', <String>['Wingx-Regular.otf']);
  }
  // Latin fallback for Wingx: the engine looks these up by name.
  for (final String fallback in <String>['Roboto', 'Noto Sans', 'Arial']) {
    await family(fallback, <String>['Gloock-Regular.ttf']);
  }
  final String home = Platform.environment['HOME'] ?? '';
  final File iconsax = File(
    '$home/.pub-cache/hosted/pub.dev/iconsax_flutter-1.0.1/fonts/FlutterIconsax.ttf',
  );
  if (iconsax.existsSync()) {
    final FontLoader loader =
        FontLoader('packages/iconsax_flutter/FlutterIconsax')
          ..addFont(iconsax.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}
