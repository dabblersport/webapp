import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

/// Extension to get category-specific ColorSchemes from context
/// All colors come from Material 3 design tokens - no custom color definitions
extension CategoryThemeExtension on BuildContext {
  /// Get ColorScheme for a specific category
  ///
  /// Usage:
  /// ```dart
  /// final socialTheme = context.getCategoryTheme('social');
  /// Container(color: socialTheme.primary);
  /// ```
  ColorScheme getCategoryTheme(String category) {
    final brightness = Theme.of(this).brightness;
    return AppTheme.getColorScheme(category, brightness);
  }

  /// Check if current theme is for a specific category
  bool isCategoryTheme(String category) {
    final currentPrimary = Theme.of(this).colorScheme.primary;
    final categoryPrimary = AppTheme.getColorScheme(
      category,
      Theme.of(this).brightness,
    ).primary;
    return currentPrimary == categoryPrimary;
  }
}
