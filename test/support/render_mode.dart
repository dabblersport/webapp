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

/// Where the design-system `fonts/` folder can be, in the order it is tried:
/// the folder of the package the app is actually resolved against (read from
/// `.dart_tool/package_config.json`, so it works in any checkout, worktree or
/// CI layout and needs no sibling), then the sibling checkout as a fallback.
List<String> renderFontDirCandidates() {
  final List<String> dirs = <String>[];
  final File cfg = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  if (cfg.existsSync()) {
    final Match? m = RegExp(
      r'"name":\s*"dabbler_design_system",\s*"rootUri":\s*"([^"]+)"',
    ).firstMatch(cfg.readAsStringSync());
    if (m != null) {
      final Uri root = Uri.parse(m.group(1)!);
      final String base = root.isAbsolute
          ? root.toFilePath()
          : Directory.current.uri
                .resolve('.dart_tool/')
                .resolveUri(root)
                .toFilePath();
      dirs.add('${base.endsWith('/') ? base : '$base/'}fonts');
    }
  }
  dirs.add('${Directory.current.parent.path}/dabbler-design-system/fonts');
  return dirs;
}

/// Loads the design-system fonts for a render test (call from `setUpAll`).
///
/// Throws a [StateError] naming every folder tried when none holds the fonts:
/// without them the test engine falls back to Ahem (every glyph a full em
/// wide) and the render fails with layout errors that hide the real cause.
/// [searchDirs] overrides the folders tried (for the negative test).
///
/// Wingx, the Arabic display face, draws Arabic only — it has no Latin
/// letters. Latin text under an Arabic locale (data that is not translated)
/// therefore needs a fallback, and the test engine has none, so it drew
/// black blocks. This registers Gloock (the Latin display face) and Glory
/// under the fallback family names the engine consults, so those glyphs draw.
Future<void> loadRenderFonts({List<String>? searchDirs}) async {
  final List<String> tried = searchDirs ?? renderFontDirCandidates();
  final String? dsFonts = tried.cast<String?>().firstWhere(
    (String? d) => File('$d/Glory-Regular.ttf').existsSync(),
    orElse: () => null,
  );
  if (dsFonts == null) {
    throw StateError(
      'Design-system fonts not found; render tests would fall back to Ahem. '
      'Looked for Glory-Regular.ttf in: ${tried.join(', ')}. Run '
      '`flutter pub get` so dabbler_design_system resolves in '
      '.dart_tool/package_config.json.',
    );
  }
  Future<void> family(String name, List<String> files) async {
    final FontLoader loader = FontLoader(name);
    for (final String f in files) {
      final File file = File('$dsFonts/$f');
      if (!file.existsSync()) {
        throw StateError('Design-system font missing: ${file.path}');
      }
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
  for (final String fallback in <String>['Roboto', 'Noto Sans', 'Arial', 'Georgia', 'Times New Roman']) {
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
