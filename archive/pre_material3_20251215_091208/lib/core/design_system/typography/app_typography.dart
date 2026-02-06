import 'package:flutter/material.dart';

/// Design System Typography - Synced with Figma Design System
/// All styles match the Dabbler DS typography specifications
///
/// Font: Roboto (default system font)
/// Sizing follows Material 3 guidelines with custom adjustments
class AppTypography {
  // ========== Display Text (Extra Large Headers) ==========

  /// Display Large - Figma: display/large
  /// Font: Roboto Bold (700), Size: 36px, Line: 42.19px
  /// Used for major page titles and hero text
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.172, // 42.19 / 36
    letterSpacing: 0,
  );

  /// Display Medium - Figma: display/medium
  /// Font: Roboto SemiBold (600), Size: 30px, Line: 35.16px
  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.172, // 35.16 / 30
    letterSpacing: 0,
  );

  /// Display Small - Figma: display/small
  /// Font: Roboto Regular (400), Size: 24px, Line: 28.13px
  static const TextStyle displaySmall = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 1.172, // 28.13 / 24
    letterSpacing: 0,
  );

  // ========== Headlines ==========

  /// Headline Large - Figma: headline/large
  /// Font: Roboto Bold (700), Size: 24px, Line: 28.13px
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.172, // 28.13 / 24
    letterSpacing: 0,
  );

  /// Headline Medium - Figma: headline/medium
  /// Font: Roboto Medium (500), Size: 21px, Line: 24.61px
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 21,
    fontWeight: FontWeight.w500,
    height: 1.172, // 24.61 / 21
    letterSpacing: 0,
  );

  /// Headline Small - Figma: headline/small
  /// Font: Roboto Bold (700), Size: 19px, Line: 22.27px
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 19,
    fontWeight: FontWeight.w700,
    height: 1.172, // 22.27 / 19
    letterSpacing: 1,
  );

  // ========== Titles ==========

  /// Title Large - Figma: title/large
  /// Font: Roboto Bold (700), Size: 21px, Line: 24.61px
  static const TextStyle titleLarge = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 21,
    fontWeight: FontWeight.w700,
    height: 1.172, // 24.61 / 21
    letterSpacing: 0,
  );

  /// Title Medium - Figma: title/medium
  /// Font: Roboto Regular (400), Size: 19px, Line: 22.27px
  static const TextStyle titleMedium = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 19,
    fontWeight: FontWeight.w400,
    height: 1.172, // 22.27 / 19
    letterSpacing: 0,
  );

  /// Title Small - Figma: title/small
  /// Font: Roboto Regular (400), Size: 17px, Line: 19.92px
  static const TextStyle titleSmall = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.172, // 19.92 / 17
    letterSpacing: 0,
  );

  // ========== Body Text ==========

  /// Body Large - Figma: body/large
  /// Font: Roboto Regular (400), Size: 17px, Line: 19.92px
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.172, // 19.92 / 17
    letterSpacing: 0,
  );

  /// Body Medium - Figma: body/medium
  /// Font: Roboto Regular (400), Size: 15px, Line: 17.58px
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.172, // 17.58 / 15
    letterSpacing: 0,
  );

  /// Body Small - Figma: body/small
  /// Font: Roboto Regular (400), Size: 12px, Line: 14.06px
  static const TextStyle bodySmall = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.172, // 14.06 / 12
    letterSpacing: 0,
  );

  // ========== Labels ==========

  /// Label Large - Figma: label/large
  /// Font: Roboto Bold (700), Size: 17px, Line: 19.92px
  static const TextStyle labelLarge = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.172, // 19.92 / 17
    letterSpacing: 0,
  );

  /// Label Medium - Figma: label/medium
  /// Font: Roboto SemiBold (600), Size: 15px, Line: 17.58px
  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.172, // 17.58 / 15
    letterSpacing: 0,
  );

  /// Label Small - Figma: label/small
  /// Font: Roboto Regular (400), Size: 12px, Line: 14.06px
  static const TextStyle labelSmall = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.172, // 14.06 / 12
    letterSpacing: 0,
  );

  // ========== Captions ==========

  /// Caption Default - Figma: caption/default
  /// Font: Roboto Regular (400), Size: 12px, Line: 14.06px, Letter: 0.24
  static const TextStyle caption = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.172, // 14.06 / 12
    letterSpacing: 0.24,
  );

  /// Caption Footnote - Figma: caption/footnote
  /// Font: Roboto Light (300), Size: 9px, Line: 10.55px, Letter: 0.45, UPPERCASE
  /// Use with textTransform or .toUpperCase() in your text widget
  static const TextStyle captionFootnote = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 9,
    fontWeight: FontWeight.w300,
    height: 1.172, // 10.55 / 9
    letterSpacing: 0.45,
  );

  // ========== Legacy / Compatibility Aliases ==========
  // Keeping old names for backward compatibility during migration

  /// @deprecated Use headlineLarge instead
  static const TextStyle headingLarge = headlineLarge;

  /// @deprecated Use headlineMedium instead
  static const TextStyle headingMedium = headlineMedium;

  /// @deprecated Use headlineSmall instead
  static const TextStyle headingSmall = headlineSmall;

  /// @deprecated Use labelSmall instead
  static const TextStyle label = labelSmall;

  /// Greeting text (custom, not in Figma) - use displayMedium or titleLarge instead
  static const TextStyle greeting = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  /// Button text (custom, not in Figma) - use labelMedium instead
  static const TextStyle button = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );
}
