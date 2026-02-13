import 'package:flutter/material.dart';
import '../../../themes/material3_extensions.dart';

/// Avatar context enum for category-based coloring
/// Maps to app feature areas for semantic color assignment
enum AvatarContext {
  /// Main/default context (purple) - Auth, onboarding, general screens
  main,

  /// Social context (blue) - Feed, posts, friends, public profiles
  social,

  /// Sports context (green) - Games, venues, sports flows
  sports,

  /// Activity context (pink) - Notifications, activity log
  activity,

  /// Profile context (orange) - My profile, settings
  profile,
}

/// Avatar color palette using Material 3 category colors
/// Provides consistent background/foreground pairs for initials-only avatars
class AvatarColorPalette {
  AvatarColorPalette._();

  /// Get background and foreground colors for a given avatar context
  ///
  /// Returns a record with (background, foreground) colors based on the
  /// context and current theme brightness.
  ///
  /// For initials-only avatars:
  /// - Background uses category container color
  /// - Foreground uses category primary color
  ///
  /// Example:
  /// ```dart
  /// final colors = AvatarColorPalette.getColors(
  ///   context: AvatarContext.social,
  ///   colorScheme: Theme.of(context).colorScheme,
  /// );
  /// Container(
  ///   color: colors.background,
  ///   child: Text('JD', style: TextStyle(color: colors.foreground)),
  /// )
  /// ```
  static ({Color background, Color foreground}) getColors({
    required AvatarContext context,
    required ColorScheme colorScheme,
  }) {
    switch (context) {
      case AvatarContext.main:
        return (
          background: colorScheme.categoryMainContainer,
          foreground: colorScheme.categoryMain,
        );

      case AvatarContext.social:
        return (
          background: colorScheme.categorySocialContainer,
          foreground: colorScheme.categorySocial,
        );

      case AvatarContext.sports:
        return (
          background: colorScheme.categorySportsContainer,
          foreground: colorScheme.categorySports,
        );

      case AvatarContext.activity:
        // Activity doesn't have container in extensions, use primary with opacity
        final activityColor = colorScheme.categoryActivities;
        return (
          background: activityColor.withValues(alpha: 0.12),
          foreground: activityColor,
        );

      case AvatarContext.profile:
        // Profile doesn't have container in extensions, use primary with opacity
        final profileColor = colorScheme.categoryProfile;
        return (
          background: profileColor.withValues(alpha: 0.12),
          foreground: profileColor,
        );
    }
  }

  /// Get border color with theme-appropriate opacity
  static Color getBorderColor(ColorScheme colorScheme) {
    return colorScheme.outline.withValues(alpha: 0.2);
  }

  /// Get edit overlay background color
  static Color getEditOverlayColor(ColorScheme colorScheme) {
    return colorScheme.scrim.withValues(alpha: 0.5);
  }

  /// Get error border color
  static Color getErrorBorderColor(ColorScheme colorScheme) {
    return colorScheme.error;
  }

  /// Get sport badge background color
  static Color getSportBadgeBackground(ColorScheme colorScheme) {
    return colorScheme.surface;
  }
}
