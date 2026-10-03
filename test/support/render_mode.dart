import 'package:flutter/material.dart';

/// Base theme for render tests: light by default, dark when the run passes
/// `--dart-define=RENDER_DARK=1`.
ThemeData renderThemeBase() =>
    const String.fromEnvironment('RENDER_DARK') == '1'
    ? ThemeData.dark()
    : ThemeData.light();
