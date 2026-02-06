import 'package:flutter/material.dart';

/// Compatibility layer for legacy AppColors API
/// Maps old color methods to Material Design 3 ColorScheme
class AppColors {
  // Static colors (non-context dependent)
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color buttonForeground = Colors.white;
  static const Color textLight70 = Color(0xB3FFFFFF);
  static const Color borderDark = Color(0xFF374151);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBackground = Color(0xFFFEE2E2);
  static const Color infoBackground = Color(0xFFE0E7FF);
  static const Color infoBorder = Color(0xFF6366F1);
  static const Color secondarySportsBtn = Color(0xFF10B981);

  // Context-dependent colors using Material 3 ColorScheme
  static Color mainTxt(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color bodyTxt(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color captionsTxt(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color disabledTxt(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

  static Color stroke(BuildContext context) =>
      Theme.of(context).colorScheme.outline;

  static Color cardColor(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainer;

  static Color sectionBg(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;
}
