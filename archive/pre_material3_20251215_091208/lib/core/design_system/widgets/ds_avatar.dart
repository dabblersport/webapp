import 'package:flutter/material.dart';

/// Avatar component matching Figma design specifications
/// Raw Flutter implementation without external dependencies
/// Theme-aware, adapts to all theme modes
///
/// Design specs from Figma:
/// - Sizes: 24px, 30px, 42px, 48px, 54px
/// - Corner radius: 6px (24px), 12px (30px, 42px), 18px (48px, 54px)
/// - Optional sport icon overlay (sizes 30px, 42px, 48px)
/// - Background color: tokens.base (theme.colorScheme.surface)
enum DSAvatarSize {
  /// 24px - no sport icon
  size24,

  /// 30px - with sport icon
  size30,

  /// 42px - with sport icon
  size42,

  /// 48px - with sport icon
  size48,

  /// 54px - no sport icon
  size54,
}

class DSAvatar extends StatelessWidget {
  final DSAvatarSize size;
  final String? imageUrl;
  final Widget? sportIcon;
  final String? initials;
  final Color? backgroundColor;

  const DSAvatar({
    super.key,
    this.size = DSAvatarSize.size48,
    this.imageUrl,
    this.sportIcon,
    this.initials,
    this.backgroundColor,
  });

  /// Factory constructor for size 24px (no sport icon)
  const DSAvatar.size24({
    super.key,
    String? imageUrl,
    String? initials,
    Color? backgroundColor,
  }) : size = DSAvatarSize.size24,
       imageUrl = imageUrl,
       sportIcon = null,
       initials = initials,
       backgroundColor = backgroundColor;

  /// Factory constructor for size 30px (with sport icon)
  const DSAvatar.size30({
    super.key,
    String? imageUrl,
    Widget? sportIcon,
    String? initials,
    Color? backgroundColor,
  }) : size = DSAvatarSize.size30,
       imageUrl = imageUrl,
       sportIcon = sportIcon,
       initials = initials,
       backgroundColor = backgroundColor;

  /// Factory constructor for size 42px (with sport icon)
  const DSAvatar.size42({
    super.key,
    String? imageUrl,
    Widget? sportIcon,
    String? initials,
    Color? backgroundColor,
  }) : size = DSAvatarSize.size42,
       imageUrl = imageUrl,
       sportIcon = sportIcon,
       initials = initials,
       backgroundColor = backgroundColor;

  /// Factory constructor for size 48px (with sport icon)
  const DSAvatar.size48({
    super.key,
    String? imageUrl,
    Widget? sportIcon,
    String? initials,
    Color? backgroundColor,
  }) : size = DSAvatarSize.size48,
       imageUrl = imageUrl,
       sportIcon = sportIcon,
       initials = initials,
       backgroundColor = backgroundColor;

  /// Factory constructor for size 54px (no sport icon)
  const DSAvatar.size54({
    super.key,
    String? imageUrl,
    String? initials,
    Color? backgroundColor,
  }) : size = DSAvatarSize.size54,
       imageUrl = imageUrl,
       sportIcon = null,
       initials = initials,
       backgroundColor = backgroundColor;

  @override
  Widget build(BuildContext context) {
    final specs = _getAvatarSpecs();
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.colorScheme.surface;

    return SizedBox(
      width: specs.size,
      height: specs.size,
      child: Stack(
        children: [
          // Main avatar
          Container(
            width: specs.size,
            height: specs.size,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(specs.cornerRadius),
              border: Border.all(color: Colors.white, width: 1.5),
              image: imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageUrl == null && initials != null
                ? Center(
                    child: Text(
                      initials!,
                      style: TextStyle(
                        fontSize: specs.size * 0.4,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  )
                : null,
          ),
          // Sport icon overlay (bottom-right corner)
          if (sportIcon != null && specs.supportsSportIcon)
            Positioned(right: 0, bottom: 0, child: sportIcon!),
        ],
      ),
    );
  }

  _AvatarSpecs _getAvatarSpecs() {
    switch (size) {
      case DSAvatarSize.size24:
        return const _AvatarSpecs(
          size: 24.0,
          cornerRadius: 6.0,
          supportsSportIcon: false,
        );
      case DSAvatarSize.size30:
        return const _AvatarSpecs(
          size: 30.0,
          cornerRadius: 12.0,
          supportsSportIcon: true,
        );
      case DSAvatarSize.size42:
        return const _AvatarSpecs(
          size: 42.0,
          cornerRadius: 12.0,
          supportsSportIcon: true,
        );
      case DSAvatarSize.size48:
        return const _AvatarSpecs(
          size: 48.0,
          cornerRadius: 18.0,
          supportsSportIcon: true,
        );
      case DSAvatarSize.size54:
        return const _AvatarSpecs(
          size: 54.0,
          cornerRadius: 18.0,
          supportsSportIcon: false,
        );
    }
  }
}

class _AvatarSpecs {
  final double size;
  final double cornerRadius;
  final bool supportsSportIcon;

  const _AvatarSpecs({
    required this.size,
    required this.cornerRadius,
    required this.supportsSportIcon,
  });
}
