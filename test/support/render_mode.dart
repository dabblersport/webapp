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
