import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';

/// App-root wiring for the Dabbler design-system package (KAN-407).
///
/// Installs the package's [DabblerColors] extension on the app's [ThemeData]
/// and points the text theme at the package's bundled font families, so any
/// widget under the app root can resolve a design-system token
/// (`DabblerColors.of(context)`) and render a `Dabbler*` component without
/// further wiring. No colour is declared here: every value is resolved by the
/// package. Other screens keep their existing Material widgets untouched.
abstract final class DabblerDesignSystemTheme {
  /// The design-system theme the app root resolves from.
  static const DabblerTheme theme = DabblerTheme.main;

  /// [base] with the [DabblerColors] extension for its brightness.
  static ThemeData withTokens(ThemeData base, {DabblerTheme theme = theme}) {
    final DabblerColors colors = DabblerColors.resolve(
      theme: theme,
      brightness: base.brightness,
    );
    final List<ThemeExtension<dynamic>> extensions = <ThemeExtension<dynamic>>[];
    for (final ThemeExtension<dynamic> e in base.extensions.values) {
      if (e is! DabblerColors) extensions.add(e);
    }
    extensions.add(colors);
    return base.copyWith(extensions: extensions);
  }

  /// [base] with the design-system sans family (Glory / Meral Sans for Arabic)
  /// applied to its text theme. Sizes, weights and colours are left as they are.
  static ThemeData withFonts(ThemeData base, {required Locale locale}) {
    final DabblerTypeScript script = locale.languageCode == 'ar'
        ? DabblerTypeScript.arabic
        : DabblerTypeScript.latin;
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: DabblerType.fontFamilyFor(DabblerTypeRole.sans, script),
        fontFamilyFallback: DabblerType.fontFamilyFallbackFor(
          DabblerTypeRole.sans,
          script,
        ),
      ),
    );
  }
}
