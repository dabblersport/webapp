import 'package:flutter/material.dart';

/// Design System compatibility layer
/// Maps legacy DS API to Material Design 3 theme system
class DS {
  // This is a placeholder - DS should be accessed through context
  // For now, provide static fallback colors
  static const Color error = Color(0xFFEF4444);
  static const Color primary = Color(0xFF8B5CF6);
  static const Color onSurface = Color(0xFF1F2937);
  static const Color onSurfaceVariant = Color(0xFF6B7280);

  // Spacing constants
  static const double gap2 = 8.0;
  static const double gap4 = 16.0;
  static const double gap6 = 24.0;
  static const double gap8 = 32.0;
  static const double gap16 = 64.0;

  // Text styles - use with Theme.of(context).textTheme in actual code
  static const TextStyle headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    fontFamily: 'Roboto',
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontFamily: 'Roboto',
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontFamily: 'Roboto',
  );

  // Button style
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  );

  // Card decoration
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Skeleton loader
  static Widget skeleton({required double height, required double width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Extension to get DS colors from context
extension DSContext on BuildContext {
  Color get dsError => Theme.of(this).colorScheme.error;
  Color get dsPrimary => Theme.of(this).colorScheme.primary;
  Color get dsOnSurface => Theme.of(this).colorScheme.onSurface;
  Color get dsOnSurfaceVariant => Theme.of(this).colorScheme.onSurfaceVariant;

  TextStyle get dsHeadline => Theme.of(this).textTheme.headlineMedium!;
  TextStyle get dsBody => Theme.of(this).textTheme.bodyMedium!;

  ButtonStyle get dsPrimaryButton => ElevatedButton.styleFrom(
    backgroundColor: Theme.of(this).colorScheme.primary,
    foregroundColor: Theme.of(this).colorScheme.onPrimary,
  );
}
