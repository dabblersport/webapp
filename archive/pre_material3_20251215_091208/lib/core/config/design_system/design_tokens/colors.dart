import 'package:flutter/material.dart';

/// Design tokens for colors following Ant Design principles while maintaining Dabbler's brand identity
class DabblerColors {
  // Primary Brand Colors
  static const MaterialColor primary = MaterialColor(
    0xFF8B5CF6, // Dabbler Purple
    {
      50: Color(0xFFF5F3FF),
      100: Color(0xFFEDE9FE),
      200: Color(0xFFDDD6FE),
      300: Color(0xFFC4B5FD),
      400: Color(0xFFA78BFA),
      500: Color(0xFF8B5CF6), // Primary
      600: Color(0xFF7C3AED),
      700: Color(0xFF6D28D9),
      800: Color(0xFF5B21B6),
      900: Color(0xFF4C1D95),
    },
  );

  // Secondary Colors
  static const MaterialColor secondary = MaterialColor(
    0xFF10B981, // Dabbler Green
    {
      50: Color(0xFFECFDF5),
      100: Color(0xFFD1FAE5),
      200: Color(0xFFA7F3D0),
      300: Color(0xFF6EE7B7),
      400: Color(0xFF34D399),
      500: Color(0xFF10B981), // Secondary
      600: Color(0xFF059669),
      700: Color(0xFF047857),
      800: Color(0xFF065F46),
      900: Color(0xFF064E3B),
    },
  );

  // Semantic Colors
  static const MaterialColor success = MaterialColor(
    0xFF10B981, // Same as secondary for now
    {
      50: Color(0xFFECFDF5),
      100: Color(0xFFD1FAE5),
      200: Color(0xFFA7F3D0),
      300: Color(0xFF6EE7B7),
      400: Color(0xFF34D399),
      500: Color(0xFF10B981),
      600: Color(0xFF059669),
      700: Color(0xFF047857),
      800: Color(0xFF065F46),
      900: Color(0xFF064E3B),
    },
  );

  static const MaterialColor warning = MaterialColor(0xFFF59E0B, {
    50: Color(0xFFFFFBEB),
    100: Color(0xFFFEF3C7),
    200: Color(0xFFFDE68A),
    300: Color(0xFFFCD34D),
    400: Color(0xFFFBBF24),
    500: Color(0xFFF59E0B),
    600: Color(0xFFD97706),
    700: Color(0xFFB45309),
    800: Color(0xFF92400E),
    900: Color(0xFF78350F),
  });

  static const MaterialColor error = MaterialColor(0xFFEF4444, {
    50: Color(0xFFFEF2F2),
    100: Color(0xFFFEE2E2),
    200: Color(0xFFFECACA),
    300: Color(0xFFFCA5A5),
    400: Color(0xFFF87171),
    500: Color(0xFFEF4444),
    600: Color(0xFFDC2626),
    700: Color(0xFFB91C1C),
    800: Color(0xFF991B1B),
    900: Color(0xFF7F1D1D),
  });

  // Neutral Colors - Light Theme
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Colors.white;
  static const Color textPrimaryLight = Color(0xFF1F2937);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color dividerLight = Color(0xFFE5E7EB);

  // Neutral Colors - Dark Theme
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFFD1D5DB);
  static const Color dividerDark = Color(0xFF374151);

  // Opacity Variants
  static const double activeStateOpacity = 0.9;
  static const double hoverStateOpacity = 0.8;
  static const double disabledStateOpacity = 0.38;
  static const double focusStateOpacity = 0.12;

  // Overlay Colors
  static Color overlay(Color color, {required double opacity}) {
    return color.withValues(alpha: opacity);
  }

  // Helper Methods
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  static MaterialColor createMaterialColor(Color color) {
    List<double> strengths = <double>[.05, .1, .2, .3, .4, .5, .6, .7, .8, .9];
    Map<int, Color> swatch = {};

    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 0; i < 10; i++) {
      final double ds = strengths[i];
      swatch[(ds * 1000).round()] = Color.fromRGBO(
        r + ((255 - r) * ds).round(),
        g + ((255 - g) * ds).round(),
        b + ((255 - b) * ds).round(),
        1,
      );
    }

    return MaterialColor(color.value, swatch);
  }
}
