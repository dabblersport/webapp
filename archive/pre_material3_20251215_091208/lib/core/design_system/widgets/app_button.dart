import 'package:flutter/material.dart';

/// Native Material 3 button wrapper for backward compatibility
///
/// @deprecated Use native Material 3 buttons instead:
/// - FilledButton for primary buttons
/// - OutlinedButton for secondary buttons
/// - TextButton for tertiary/ghost buttons
/// - ElevatedButton for elevated buttons
@Deprecated('Use FilledButton, OutlinedButton, or TextButton')
class AppButton extends StatelessWidget {
  final String? label;
  final VoidCallback? onPressed;
  final Widget? leftIcon;
  final Widget? rightIcon;
  final bool enabled;

  const AppButton({
    super.key,
    this.label,
    required this.onPressed,
    this.leftIcon,
    this.rightIcon,
    this.enabled = true,
  });

  factory AppButton.primary({
    Key? key,
    String? label,
    required VoidCallback? onPressed,
    Widget? leftIcon,
    Widget? rightIcon,
    bool enabled = true,
  }) {
    return AppButton(
      key: key,
      label: label,
      onPressed: onPressed,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
      enabled: enabled,
    );
  }

  factory AppButton.secondary({
    Key? key,
    String? label,
    required VoidCallback? onPressed,
    Widget? leftIcon,
    Widget? rightIcon,
    bool enabled = true,
  }) {
    return AppButton(
      key: key,
      label: label,
      onPressed: onPressed,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
      enabled: enabled,
    );
  }

  factory AppButton.ghost({
    Key? key,
    String? label,
    required VoidCallback? onPressed,
    Widget? leftIcon,
    Widget? rightIcon,
    bool enabled = true,
  }) {
    return AppButton(
      key: key,
      label: label,
      onPressed: onPressed,
      leftIcon: leftIcon,
      rightIcon: rightIcon,
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (label == null && leftIcon == null && rightIcon == null) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    if (leftIcon != null) children.add(leftIcon!);
    if (label != null) {
      if (leftIcon != null) children.add(const SizedBox(width: 8));
      children.add(Text(label!));
    }
    if (rightIcon != null) {
      if (label != null || leftIcon != null)
        children.add(const SizedBox(width: 8));
      children.add(rightIcon!);
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
