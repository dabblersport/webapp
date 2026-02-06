import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Extension to access ThemeColorTokens from BuildContext
/// Maps the current theme brightness and category to the correct token set
extension ThemeColorTokensExtension on BuildContext {
  /// Get the current theme's color tokens
  /// Defaults to Main theme (Light/Dark based on brightness)
  ThemeColorTokens get colorTokens {
    final brightness = Theme.of(this).brightness;

    // For now, default to Main theme
    // In the future, this can be enhanced to detect category from route or state
    if (brightness == Brightness.light) {
      return MainLightColors.tokens;
    } else {
      return MainDarkColors.tokens;
    }
  }
}

/// Extension to get category-specific color tokens
extension CategoryColorTokensExtension on BuildContext {
  /// Get color tokens for a specific category
  ThemeColorTokens getCategoryColorTokens(String category, {bool? isDark}) {
    final brightness = isDark ?? (Theme.of(this).brightness == Brightness.dark);

    switch (category.toLowerCase()) {
      case 'social':
        return brightness ? SocialDarkColors.tokens : SocialLightColors.tokens;
      case 'sports':
        return brightness ? SportsDarkColors.tokens : SportsLightColors.tokens;
      case 'activities':
        return brightness
            ? ActivitiesDarkColors.tokens
            : ActivitiesLightColors.tokens;
      case 'profile':
        return brightness
            ? ProfileDarkColors.tokens
            : ProfileLightColors.tokens;
      case 'main':
      default:
        return brightness ? MainDarkColors.tokens : MainLightColors.tokens;
    }
  }
}
