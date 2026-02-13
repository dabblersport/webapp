import 'package:flutter/material.dart';
import '../design_system/tokens/avatar_color_palette.dart';
import '../utils/initials_generator.dart';
import '../utils/avatar_url_resolver.dart';

/// Avatar service providing utility functions for avatar management
///
/// Centralized service for:
/// - URL resolution (storage paths → public URLs)
/// - Initials generation from display names
/// - Context-based color selection
/// - Avatar-related business logic
class AvatarService {
  const AvatarService._();

  /// Resolves avatar URL or storage path to a full public URL
  ///
  /// Handles:
  /// - Full HTTP(S) URLs → returns as-is
  /// - Storage paths → resolves via Supabase storage
  /// - Null/empty → returns null
  ///
  /// Example:
  /// ```dart
  /// final url = AvatarService.resolveUrl('user-id/avatar.jpg');
  /// // Returns: https://xxx.supabase.co/storage/v1/object/public/avatars/user-id/avatar.jpg
  /// ```
  static String? resolveUrl(String? avatarUrlOrPath) {
    return resolveAvatarUrl(avatarUrlOrPath);
  }

  /// Generates 2-character initials from a display name
  ///
  /// Rules:
  /// - Null/empty → 'U'
  /// - Single word → First character
  /// - Multiple words → First + Last word initials
  ///
  /// Example:
  /// ```dart
  /// AvatarService.generateInitials('John Doe'); // 'JD'
  /// AvatarService.generateInitials('Jane'); // 'J'
  /// AvatarService.generateInitials(null); // 'U'
  /// ```
  static String generateInitials(String? displayName) {
    return InitialsGenerator.generate(displayName);
  }

  /// Gets category-based colors for avatar context
  ///
  /// Returns background and foreground colors for initials-only avatars
  /// based on the feature context (social, sports, profile, etc.)
  ///
  /// Example:
  /// ```dart
  /// final colors = AvatarService.getContextColors(
  ///   context: AvatarContext.social,
  ///   colorScheme: Theme.of(context).colorScheme,
  /// );
  /// ```
  static ({Color background, Color foreground}) getContextColors({
    required AvatarContext context,
    required ColorScheme colorScheme,
  }) {
    return AvatarColorPalette.getColors(
      context: context,
      colorScheme: colorScheme,
    );
  }

  /// Validates if an image URL is valid and non-empty
  static bool hasValidImageUrl(String? imageUrl) {
    return imageUrl != null && imageUrl.trim().isNotEmpty;
  }

  /// Checks if initials should be displayed (no valid image)
  static bool shouldShowInitials(String? imageUrl) {
    return !hasValidImageUrl(imageUrl);
  }
}
