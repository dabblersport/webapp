import 'package:flutter/material.dart';

/// @deprecated Use DSAvatar from the design system instead
/// This widget is kept for backward compatibility but will be removed in future versions
///
/// Migration:
/// - AppAvatar.small() → DSAvatar.small()
/// - AppAvatar.medium() → DSAvatar.medium()
/// - AppAvatar.large() → DSAvatar.large()
/// - fallbackText parameter → displayName parameter
/// - Add context parameter (AvatarContext.main, .social, .sports, etc.)
@Deprecated(
  'Use DSAvatar from core/design_system/widgets/ds_avatar.dart instead',
)
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? fallbackText;
  final double size;
  final VoidCallback? onTap;
  final Widget? badge;
  final bool showBadge;
  final String? _sportEmoji;
  final Color? fallbackBackgroundColor;
  final Color? fallbackForegroundColor;
  final Color? borderColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    this.fallbackText,
    this.size = 48.0,
    this.onTap,
    this.badge,
    this.showBadge = true,
    this.fallbackBackgroundColor,
    this.fallbackForegroundColor,
    this.borderColor,
  }) : _sportEmoji = null;

  /// Small avatar (40x40)
  const AppAvatar.small({
    super.key,
    this.imageUrl,
    this.fallbackText,
    this.onTap,
    this.badge,
    this.showBadge = true,
    this.fallbackBackgroundColor,
    this.fallbackForegroundColor,
    this.borderColor,
  }) : size = 40.0,
       _sportEmoji = null;

  /// Medium avatar (48x48) - Default
  const AppAvatar.medium({
    super.key,
    this.imageUrl,
    this.fallbackText,
    this.onTap,
    this.badge,
    this.showBadge = true,
    this.fallbackBackgroundColor,
    this.fallbackForegroundColor,
    this.borderColor,
  }) : size = 48.0,
       _sportEmoji = null;

  /// Large avatar (64x64)
  const AppAvatar.large({
    super.key,
    this.imageUrl,
    this.fallbackText,
    this.onTap,
    this.badge,
    this.showBadge = true,
    this.fallbackBackgroundColor,
    this.fallbackForegroundColor,
    this.borderColor,
  }) : size = 64.0,
       _sportEmoji = null;

  /// Avatar with sport badge
  const AppAvatar.withSportBadge({
    super.key,
    this.imageUrl,
    this.fallbackText,
    this.size = 48.0,
    this.onTap,
    required String sportEmoji,
    this.fallbackBackgroundColor,
    this.fallbackForegroundColor,
    this.borderColor,
  }) : badge = null,
       showBadge = true,
       _sportEmoji = sportEmoji;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = size * 0.375; // 18dp for 48dp size (maintains ratio)

    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final fallbackBackground =
        fallbackBackgroundColor ?? colorScheme.primary.withValues(alpha: 0.12);
    final fallbackForeground = fallbackForegroundColor ?? colorScheme.primary;
    final effectiveBorderColor =
        borderColor ?? colorScheme.outline.withValues(alpha: 0.2);

    Widget avatarContent = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hasImage ? null : fallbackBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorderColor, width: 1),
        image: hasImage
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: !hasImage
          ? Center(
              child: Text(
                _getInitials(fallbackText),
                style: TextStyle(
                  color: fallbackForeground,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );

    // Wrap with badge if needed
    if (showBadge && (badge != null || _sportEmoji != null)) {
      final badgeSize = size * 0.46; // Proportional badge size
      final badgeWidget =
          badge ??
          _buildDefaultBadge(context, colorScheme, _sportEmoji!, badgeSize);

      avatarContent = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarContent,
          Positioned(bottom: -2, right: -2, child: badgeWidget),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarContent);
    }

    return avatarContent;
  }

  Widget _buildDefaultBadge(
    BuildContext context,
    ColorScheme colorScheme,
    String emoji,
    double badgeSize,
  ) {
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.surface, width: 2),
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: badgeSize * 0.5)),
      ),
    );
  }

  String _getInitials(String? text) {
    if (text == null || text.isEmpty) return 'U';
    final words = text.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return text[0].toUpperCase();
  }
}

/// Legacy avatar widget - Deprecated, use AppAvatar instead
@Deprecated('Use AppAvatar instead')
class CustomAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;

  const CustomAvatar({
    super.key,
    this.imageUrl,
    this.radius = 24.0,
    this.fallbackIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    return AppAvatar(imageUrl: imageUrl, size: radius * 2);
  }
}
