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
