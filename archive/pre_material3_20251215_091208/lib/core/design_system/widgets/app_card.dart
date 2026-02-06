import 'package:flutter/material.dart';

/// Use native Material 3 Card instead
/// Card.filled() - filled card with surface color
/// Card.outlined() - outlined card with border
/// Card.elevated() - card with elevation (deprecated use)
@Deprecated('Use native Material 3 Card: Card.filled(), Card.outlined()')
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? elevation;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    // Redirect to native Card
    if (backgroundColor != null || elevation != null) {
      return Card(
        color: backgroundColor,
        elevation: elevation ?? 0,
        child: InkWell(
          onTap: onTap,
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      );
    }

    return Card.filled(
      child: InkWell(
        onTap: onTap,
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

/// Use native Material 3 Card.filled() with ListTile instead
@Deprecated('Use Card.filled() with ListTile')
class AppButtonCard extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const AppButtonCard({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card.filled(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                label,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Use native Material 3 Card.filled() with ListTile instead
@Deprecated('Use Card.filled() with ListTile.leading/title/subtitle')
class AppActionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const AppActionCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ActionChip(
      avatar: Text(emoji, style: const TextStyle(fontSize: 20)),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      onPressed: onTap,
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
