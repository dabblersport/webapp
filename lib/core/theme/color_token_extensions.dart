import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

/// Extension to get category-specific ColorSchemes from context
/// All colors come from Material 3 design tokens - no custom color definitions
extension CategoryThemeExtension on BuildContext {
  /// Get the currently selected app ColorScheme.
  /// Usage:
  ///   final socialTheme = context.getCategoryTheme('main');
  ///   Container(color: socialTheme.primary);
  ColorScheme getCategoryTheme(String category) {
    final brightness = Theme.of(this).brightness;
    return AppTheme.getColorSchemeSync(AppTheme.activeCategory, brightness);
  }

  /// Check if current theme matches the selected global category.
  bool isCategoryTheme(String category) {
    final currentPrimary = Theme.of(this).colorScheme.primary;
    final brightness = Theme.of(this).brightness;
    final categoryScheme = AppTheme.getColorSchemeSync(
      AppTheme.activeCategory,
      brightness,
    );
    return currentPrimary == categoryScheme.primary;
  }
}
