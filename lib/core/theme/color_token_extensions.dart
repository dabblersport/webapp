import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

/// Extension to get category-specific ColorSchemes from context
/// All colors come from Material 3 design tokens - no custom color definitions
extension CategoryThemeExtension on BuildContext {
  /// Get ColorScheme for a specific category (sync, static only)
  /// Usage:
  ///   final socialTheme = context.getCategoryTheme('main');
  ///   Container(color: socialTheme.primary);
  ColorScheme getCategoryTheme(String category) {
    final brightness = Theme.of(this).brightness;
    // Prefer token-preloaded cache (sync) and fall back to the current scheme.
    return AppTheme.tryGetCachedColorScheme(category, brightness) ??
        Theme.of(this).colorScheme;
  }

  /// Check if current theme is for a specific category (sync, static only)
  bool isCategoryTheme(String category) {
    final currentPrimary = Theme.of(this).colorScheme.primary;
    final brightness = Theme.of(this).brightness;
    final categoryScheme = AppTheme.tryGetCachedColorScheme(
      category,
      brightness,
    );
    if (categoryScheme == null) return false;
    return currentPrimary == categoryScheme.primary;
  }
}
