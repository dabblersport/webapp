import 'package:flutter/material.dart';

/// Material 3 ColorScheme extension for app-specific category colors
///
/// This extension adds category colors (main, social, sports, activities, profile)
/// to the Material 3 ColorScheme, allowing them to be accessed via theme.
extension AppColorSchemeExtension on ColorScheme {
  /// Main category color is the runtime source of truth for all screens.
  Color get categoryMain => primary;

  /// Main category container color is the runtime source of truth for all screens.
  Color get categoryMainContainer => primaryContainer;

  /// Legacy category aliases intentionally resolve to main tokens.
  Color get categorySocial => categoryMain;

  /// Legacy category aliases intentionally resolve to main container tokens.
  Color get categorySocialContainer => categoryMainContainer;

  /// Legacy category aliases intentionally resolve to main tokens.
  Color get categorySports => categoryMain;

  /// Legacy category aliases intentionally resolve to main container tokens.
  Color get categorySportsContainer => categoryMainContainer;

  /// Legacy category aliases intentionally resolve to main tokens.
  Color get categoryActivities => categoryMain;

  /// Legacy category aliases intentionally resolve to main tokens.
  Color get categoryProfile => categoryMain;

  /// Get category color by name
  Color getCategoryColor(String category) {
    return categoryMain;
  }
}

/// Material 3 Theme extension for app-specific design tokens
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  /// Success color for success states
  final Color success;

  /// Warning color for warning states
  final Color warning;

  /// Info/Link color for informational states and links
  final Color infoLink;

  /// Danger color for error/danger states (uses ColorScheme.error by default)
  final Color? danger;

  const AppThemeExtension({
    required this.success,
    required this.warning,
    required this.infoLink,
    this.danger,
  });

  @override
  AppThemeExtension copyWith({
    Color? success,
    Color? warning,
    Color? infoLink,
    Color? danger,
    bool? dangerNull,
  }) {
    return AppThemeExtension(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      infoLink: infoLink ?? this.infoLink,
      danger: dangerNull == true ? null : (danger ?? this.danger),
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) {
      return this;
    }

    return AppThemeExtension(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      infoLink: Color.lerp(infoLink, other.infoLink, t)!,
      danger: danger != null && other.danger != null
          ? Color.lerp(danger!, other.danger!, t)
          : (danger ?? other.danger),
    );
  }
}

/// Extension to easily access AppThemeExtension from BuildContext
extension AppThemeExtensionContext on BuildContext {
  AppThemeExtension get appTheme =>
      Theme.of(this).extension<AppThemeExtension>() ??
      const AppThemeExtension(
        success: Color(0xFF00A63E),
        warning: Color(0xFFEC8F1E),
        infoLink: Color(0xFF155DFC),
      );

  /// Success color
  Color get successColor => appTheme.success;

  /// Warning color
  Color get warningColor => appTheme.warning;

  /// Info/Link color
  Color get infoLinkColor => appTheme.infoLink;

  /// Danger color (falls back to ColorScheme.error)
  Color get dangerColor => appTheme.danger ?? Theme.of(this).colorScheme.error;
}
