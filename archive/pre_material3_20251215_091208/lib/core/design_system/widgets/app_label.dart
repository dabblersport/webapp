import 'package:flutter/material.dart';

/// Label component matching Figma design specifications
/// Built on Material Design 3 Chip component foundation
/// Theme-aware, adapts to all 10 theme modes
///
/// Variants:
/// - Types: filled (default), outline, subtle
/// - Sizes: sm (20px), default (24px), lg (30px)
/// - Icons: left, right, both, none
///
/// Design specs from Figma:
/// - SM: height 20px, font size 12px, weight 400
/// - Default: height 24px, font size 15px, weight 400
/// - LG: height 30px, font size 15px, weight 600
/// - Padding: 6px horizontal, 3px vertical
/// - Border radius: 999px (pill shape)
///
/// Color Token Mapping:
/// - Filled background: tokens.button (theme.colorScheme.primary)
/// - Filled text: tokens.onBtn (theme.colorScheme.onPrimary)
/// - Outline/Subtle background: tokens.button @ 6% opacity
/// - Outline/Subtle text: tokens.button
enum AppLabelType {
  /// Filled label with solid background
  filled,

  /// Label with transparent background at 6% opacity
  outline,

  /// Label with subtle background at 6% opacity (same as outline)
  subtle,
}

enum AppLabelSize {
  /// Small: 20px height, 12px font
  sm,

  /// Default: 24px height, 15px font
  defaultSize,

  /// Large: 30px height, 15px font, bold
  lg,
}

class AppLabel extends StatelessWidget {
  final String text;
  final AppLabelType type;
  final AppLabelSize size;
  final Widget? leftIcon;
  final Widget? rightIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppLabel({
    super.key,
    required this.text,
    this.type = AppLabelType.filled,
    this.size = AppLabelSize.defaultSize,
    this.leftIcon,
    this.rightIcon,
    this.backgroundColor,
    this.foregroundColor,
  });

  factory AppLabel.filled({
    Key? key,
    required String text,
    AppLabelSize size = AppLabelSize.defaultSize,
    Widget? leftIcon,
    Widget? rightIcon,
  }) {
    return AppLabel(
      key: key,
      text: text,
      type: AppLabelType.filled,
      size: size,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
    );
  }

  factory AppLabel.outline({
    Key? key,
    required String text,
    AppLabelSize size = AppLabelSize.defaultSize,
    Widget? leftIcon,
    Widget? rightIcon,
  }) {
    return AppLabel(
      key: key,
      text: text,
      type: AppLabelType.outline,
      size: size,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
    );
  }

  factory AppLabel.subtle({
    Key? key,
    required String text,
    AppLabelSize size = AppLabelSize.defaultSize,
    Widget? leftIcon,
    Widget? rightIcon,
  }) {
    return AppLabel(
      key: key,
      text: text,
      type: AppLabelType.subtle,
      size: size,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final specs = _getLabelSpecs();
    final colors = _getLabelColors(context);

    return Container(
      height: specs.height,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leftIcon != null) ...[
            SizedBox(
              width: specs.iconSize,
              height: specs.iconSize,
              child: IconTheme(
                data: IconThemeData(
                  color: colors.foreground,
                  size: specs.iconSize,
                ),
                child: leftIcon!,
              ),
            ),
            const SizedBox(width: 6.0),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: specs.fontSize,
              fontWeight: specs.fontWeight,
              color: colors.foreground,
              height: 1.0,
            ),
          ),
          if (rightIcon != null) ...[
            const SizedBox(width: 6.0),
            SizedBox(
              width: specs.iconSize,
              height: specs.iconSize,
              child: IconTheme(
                data: IconThemeData(
                  color: colors.foreground,
                  size: specs.iconSize,
                ),
                child: rightIcon!,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _LabelSpecs _getLabelSpecs() {
    switch (size) {
      case AppLabelSize.sm:
        return const _LabelSpecs(
          height: 20.0,
          fontSize: 12.0,
          fontWeight: FontWeight.w400,
          iconSize: 12.0,
        );
      case AppLabelSize.defaultSize:
        return const _LabelSpecs(
          height: 24.0,
          fontSize: 15.0,
          fontWeight: FontWeight.w400,
          iconSize: 18.0,
        );
      case AppLabelSize.lg:
        return const _LabelSpecs(
          height: 30.0,
          fontSize: 15.0,
          fontWeight: FontWeight.w600,
          iconSize: 24.0,
        );
    }
  }

  _LabelColors _getLabelColors(BuildContext context) {
    final theme = Theme.of(context);
    final primary = backgroundColor ?? theme.colorScheme.primary;
    final onPrimary = foregroundColor ?? theme.colorScheme.onPrimary;

    switch (type) {
      case AppLabelType.filled:
        return _LabelColors(background: primary, foreground: onPrimary);
      case AppLabelType.outline:
      case AppLabelType.subtle:
        return _LabelColors(
          background: primary.withValues(alpha: 0.06),
          foreground: foregroundColor ?? primary,
        );
    }
  }
}

class _LabelSpecs {
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final double iconSize;

  const _LabelSpecs({
    required this.height,
    required this.fontSize,
    required this.fontWeight,
    required this.iconSize,
  });
}

class _LabelColors {
  final Color background;
  final Color foreground;

  const _LabelColors({required this.background, required this.foreground});
}
