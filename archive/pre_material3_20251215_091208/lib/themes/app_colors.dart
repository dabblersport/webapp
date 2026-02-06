import 'package:flutter/material.dart';

/// Centralized app color definitions.
///
/// ⚠️ **DEPRECATED**: This class is deprecated in favor of Material 3 ColorScheme.
///
/// **Migration:**
/// - Use `Theme.of(context).colorScheme.*` instead
/// - See `lib/core/design_system/MATERIAL3_MIGRATION_GUIDE.md` for details
///
/// @deprecated Use Material 3 ColorScheme instead
@Deprecated(
  'Use Material 3 ColorScheme instead. See MATERIAL3_MIGRATION_GUIDE.md',
)
class AppColors {
  static const Color textPrimary = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF757575);
  static const Color primary = Color(0xFF1976D2);
  static const Color secondary = Color(0xFF42A5F5);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F0F0);
  static const Color error = Color(0xFFD32F2F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF000000);
  static const Color onBackground = Color(0xFF000000);
  static const Color onSurface = Color(0xFF000000);
  static const Color onError = Color(0xFFFFFFFF);
}
