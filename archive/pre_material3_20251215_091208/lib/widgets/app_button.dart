import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Material 3 button widget with multiple variants
///
/// This widget wraps Material 3 button components (FilledButton, OutlinedButton, TextButton)
/// to provide a consistent API while using Material 3 design tokens.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = ButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = ButtonVariant.secondary;

  const AppButton.outline({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = ButtonVariant.outline;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = ButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = ButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Determine Material 3 button size
    ButtonStyle? sizeStyle;
    double? iconSize;

    switch (size) {
      case ButtonSize.small:
        sizeStyle = ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          textStyle: WidgetStateProperty.all(textTheme.labelLarge),
          minimumSize: WidgetStateProperty.all(const Size(64, 32)),
        );
        iconSize = 18;
        break;
      case ButtonSize.medium:
        sizeStyle = ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          textStyle: WidgetStateProperty.all(textTheme.labelLarge),
          minimumSize: WidgetStateProperty.all(const Size(64, 40)),
        );
        iconSize = 20;
        break;
      case ButtonSize.large:
        sizeStyle = ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          textStyle: WidgetStateProperty.all(textTheme.labelLarge),
          minimumSize: WidgetStateProperty.all(const Size(64, 48)),
        );
        iconSize = 24;
        break;
    }

    // Build button content
    Widget buttonContent = isLoading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getLoadingColor(context),
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: iconSize),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: iconSize),
              ],
            ],
          );

    // Handle tap with haptic feedback
    VoidCallback? onTap = isLoading
        ? null
        : () {
            HapticFeedback.lightImpact();
            onPressed?.call();
          };

    // Build appropriate Material 3 button based on variant
    Widget button;
    switch (variant) {
      case ButtonVariant.primary:
        button = FilledButton(
          onPressed: onTap,
          style: sizeStyle,
          child: buttonContent,
        );
        break;
      case ButtonVariant.secondary:
        // Use FilledButton.tonal for secondary actions (Material 3 pattern)
        button = FilledButton.tonal(
          onPressed: onTap,
          style: sizeStyle,
          child: buttonContent,
        );
        break;
      case ButtonVariant.outline:
        button = OutlinedButton(
          onPressed: onTap,
          style: sizeStyle,
          child: buttonContent,
        );
        break;
      case ButtonVariant.ghost:
        button = TextButton(
          onPressed: onTap,
          style: sizeStyle,
          child: buttonContent,
        );
        break;
    }

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }

  Color _getLoadingColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (variant) {
      case ButtonVariant.primary:
        return colorScheme.onPrimary;
      case ButtonVariant.secondary:
        return colorScheme.onSecondaryContainer;
      case ButtonVariant.outline:
      case ButtonVariant.ghost:
        return colorScheme.primary;
    }
  }
}

/// Button variant types matching Material 3 patterns
enum ButtonVariant {
  /// Primary action - uses FilledButton
  primary,

  /// Secondary action - uses FilledButton.tonal
  secondary,

  /// Tertiary action - uses OutlinedButton
  outline,

  /// Text-only action - uses TextButton
  ghost,
}

/// Button size variants
enum ButtonSize {
  /// Small button (32dp height)
  small,

  /// Medium button (40dp height) - default
  medium,

  /// Large button (48dp height)
  large,
}
