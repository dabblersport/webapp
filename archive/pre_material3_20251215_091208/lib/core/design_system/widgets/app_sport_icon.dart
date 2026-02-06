import 'package:flutter/material.dart';

/// Sport Icon component matching Figma design specifications
/// Uses emoji icons for sport representation
/// Theme-aware, adapts to all theme modes
///
/// Design specs from Figma:
/// - Sizes: 12px icon (14px container), 18px icon (20px container),
///          24px icon (26px container), 30px icon (32px container)
/// - Circular background with opacity
/// - Emoji centered in container
/// - Background color: tokens.neutral (theme.colorScheme.onSurface @ 72% for small, 60% for medium, solid for large)
enum AppSportIconSize {
  /// 12px emoji, 14px container, 72% opacity
  size12,

  /// 18px emoji, 20px container, 72% opacity
  size18,

  /// 24px emoji, 26px container, 60% opacity
  size24,

  /// 30px emoji, 32px container, solid (no opacity)
  size30,
}

class AppSportIcon extends StatelessWidget {
  final String emoji;
  final AppSportIconSize size;
  final Color? backgroundColor;

  const AppSportIcon({
    super.key,
    required this.emoji,
    this.size = AppSportIconSize.size18,
    this.backgroundColor,
  });

  /// Factory constructor for 12px emoji
  const AppSportIcon.size12({
    super.key,
    required String emoji,
    Color? backgroundColor,
  }) : emoji = emoji,
       size = AppSportIconSize.size12,
       backgroundColor = backgroundColor;

  /// Factory constructor for 18px emoji
  const AppSportIcon.size18({
    super.key,
    required String emoji,
    Color? backgroundColor,
  }) : emoji = emoji,
       size = AppSportIconSize.size18,
       backgroundColor = backgroundColor;

  /// Factory constructor for 24px emoji
  const AppSportIcon.size24({
    super.key,
    required String emoji,
    Color? backgroundColor,
  }) : emoji = emoji,
       size = AppSportIconSize.size24,
       backgroundColor = backgroundColor;

  /// Factory constructor for 30px emoji
  const AppSportIcon.size30({
    super.key,
    required String emoji,
    Color? backgroundColor,
  }) : emoji = emoji,
       size = AppSportIconSize.size30,
       backgroundColor = backgroundColor;

  @override
  Widget build(BuildContext context) {
    final specs = _getSportIconSpecs();
    final theme = Theme.of(context);
    final bgColor =
        backgroundColor ??
        theme.colorScheme.onSurface.withOpacity(specs.opacity);

    return Container(
      width: specs.containerSize,
      height: specs.containerSize,
      decoration: BoxDecoration(
        color: theme.colorScheme.outline,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: specs.emojiSize)),
      ),
    );
  }

  _SportIconSpecs _getSportIconSpecs() {
    switch (size) {
      case AppSportIconSize.size12:
        return const _SportIconSpecs(
          containerSize: 14.0,
          emojiSize: 10.0,
          opacity: 0.60,
        );
      case AppSportIconSize.size18:
        return const _SportIconSpecs(
          containerSize: 20.0,
          emojiSize: 14.0,
          opacity: 0.60,
        );
      case AppSportIconSize.size24:
        return const _SportIconSpecs(
          containerSize: 26.0,
          emojiSize: 19.0,
          opacity: 0.60,
        );
      case AppSportIconSize.size30:
        return const _SportIconSpecs(
          containerSize: 32.0,
          emojiSize: 21.0,
          opacity: 0.60,
        );
    }
  }
}

class _SportIconSpecs {
  final double containerSize;
  final double emojiSize;
  final double opacity;

  const _SportIconSpecs({
    required this.containerSize,
    required this.emojiSize,
    required this.opacity,
  });
}
