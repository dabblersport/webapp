import 'package:flutter/material.dart';

/// Chip component matching Figma design specifications
/// Built on Material Design 3 FilterChip/ChoiceChip foundation
/// Theme-aware, adapts to all 10 theme modes
///
/// Variants:
/// - Sizes: small (18px), default (36px)
/// - States: default (inactive), active (selected)
/// - Optional: icon, counter
///
/// Design specs from Figma:
/// - Small: height 18px, font 12px, weight 400
/// - Default: height 36px, font 15px, weight 600, padding 12px H + 6px V
/// - Item spacing: 3px between icon/text/counter
/// - Border radius: 999px (pill shape)
///
/// Color Token Mapping:
/// - Active background: tokens.button (theme.colorScheme.primary)
/// - Active text: tokens.onBtn (theme.colorScheme.onPrimary)
/// - Default background: tokens.button @ 6% opacity
/// - Default text (small): tokens.neutral
/// - Default text (default): tokens.button
enum AppChipSize {
  /// Small: 18px height, 12px font
  small,

  /// Default: 36px height, 15px font
  defaultSize,
}

class AppChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final Widget? icon;
  final String? counter;
  final AppChipSize size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  // Legacy support
  final int? counterInt;
  final bool? isSmall;

  const AppChip({
    super.key,
    required this.label,
    this.isActive = false,
    this.onTap,
    this.icon,
    this.counter,
    this.size = AppChipSize.defaultSize,
    this.backgroundColor,
    this.foregroundColor,
    this.counterInt,
    this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    // Handle legacy isSmall parameter
    final actualSize = isSmall == true ? AppChipSize.small : size;
    final actualCounter = counter ?? (counterInt?.toString());

    final specs = _getChipSpecs(actualSize);
    final colors = _getChipColors(context, actualSize);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: specs.height,
        padding: specs.padding,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(999.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              SizedBox(
                width: specs.iconSize,
                height: specs.iconSize,
                child: IconTheme(
                  data: IconThemeData(
                    color: colors.foreground,
                    size: specs.iconSize,
                  ),
                  child: icon!,
                ),
              ),
              const SizedBox(width: 3.0),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: specs.fontSize,
                fontWeight: specs.fontWeight,
                color: colors.foreground,
                height: 1.0,
              ),
            ),
            if (actualCounter != null) ...[
              const SizedBox(width: 3.0),
              Text(
                actualCounter,
                style: TextStyle(
                  fontSize: specs.counterFontSize,
                  fontWeight: specs.counterFontWeight,
                  color: colors.foreground,
                  height: 1.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _ChipSpecs _getChipSpecs(AppChipSize actualSize) {
    switch (actualSize) {
      case AppChipSize.small:
        return _ChipSpecs(
          height: 18.0,
          fontSize: 12.0,
          fontWeight: FontWeight.w400,
          iconSize: 12.0,
          counterFontSize: 12.0,
          counterFontWeight: FontWeight.w400,
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
        );
      case AppChipSize.defaultSize:
        return _ChipSpecs(
          height: 36.0,
          fontSize: 15.0,
          fontWeight: FontWeight.w600,
          iconSize: 18.0,
          counterFontSize: 12.0,
          counterFontWeight: FontWeight.w400,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        );
    }
  }

  _ChipColors _getChipColors(BuildContext context, AppChipSize actualSize) {
    final theme = Theme.of(context);
    final primary = backgroundColor ?? theme.colorScheme.primary;
    final onPrimary = foregroundColor ?? theme.colorScheme.onPrimary;
    final neutralColor = theme.colorScheme.onSurface.withValues(alpha: 0.92);

    if (isActive) {
      // Active state
      if (actualSize == AppChipSize.small) {
        // Small active: bg @ 6%, text in primary
        return _ChipColors(
          background: primary.withValues(alpha: 0.06),
          foreground: foregroundColor ?? primary,
        );
      } else {
        // Default active: solid bg, white text
        return _ChipColors(background: primary, foreground: onPrimary);
      }
    } else {
      // Default (inactive) state: bg @ 6%
      if (actualSize == AppChipSize.small) {
        // Small default: bg @ 6%, text in neutral (#1A1A1A)
        return _ChipColors(
          background: primary.withValues(alpha: 0.06),
          foreground: foregroundColor ?? neutralColor,
        );
      } else {
        // Default size default: bg @ 6%, text in primary
        return _ChipColors(
          background: primary.withValues(alpha: 0.06),
          foreground: foregroundColor ?? primary,
        );
      }
    }
  }
}

class _ChipSpecs {
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final double iconSize;
  final double counterFontSize;
  final FontWeight counterFontWeight;
  final EdgeInsets padding;

  const _ChipSpecs({
    required this.height,
    required this.fontSize,
    required this.fontWeight,
    required this.iconSize,
    required this.counterFontSize,
    required this.counterFontWeight,
    required this.padding,
  });
}

class _ChipColors {
  final Color background;
  final Color foreground;

  const _ChipColors({required this.background, required this.foreground});
}
