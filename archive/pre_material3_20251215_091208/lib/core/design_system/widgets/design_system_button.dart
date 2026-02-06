import 'package:flutter/material.dart';
import '../typography/app_typography.dart';

/// Primary pill-shaped button for the design system
///
/// Matches the purple CTA shown in the design spec with rounded edges
/// and supports leading/trailing icons plus a loading state.
class DesignSystemButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool fullWidth;
  final DesignSystemButtonSize size;

  const DesignSystemButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
    this.size = DesignSystemButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final onPrimary = colorScheme.onPrimary;

    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: onPrimary,
        padding: _padding,
        minimumSize: Size.fromHeight(_height),
        textStyle: _textStyle.copyWith(color: onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        overlayColor: onPrimary.withValues(alpha: 0.08),
      ),
      child: _buildContent(onPrimary),
    );

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _buildContent(Color onPrimary) {
    if (isLoading) {
      return SizedBox(
        width: _iconSize,
        height: _iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(onPrimary),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: _iconSize),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: _iconSize),
        ],
      ],
    );
  }

  double get _height {
    switch (size) {
      case DesignSystemButtonSize.small:
        return 40;
      case DesignSystemButtonSize.medium:
        return 48;
      case DesignSystemButtonSize.large:
        return 56;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case DesignSystemButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
      case DesignSystemButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
      case DesignSystemButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 28, vertical: 16);
    }
  }

  TextStyle get _textStyle {
    switch (size) {
      case DesignSystemButtonSize.small:
        return AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w400);
      case DesignSystemButtonSize.medium:
        return AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600);
      case DesignSystemButtonSize.large:
        return AppTypography.headingMedium.copyWith(
          fontWeight: FontWeight.w700,
        );
    }
  }

  double get _iconSize {
    switch (size) {
      case DesignSystemButtonSize.small:
        return 18;
      case DesignSystemButtonSize.medium:
        return 20;
      case DesignSystemButtonSize.large:
        return 24;
    }
  }
}

/// Supported button sizes for the design system CTA button
enum DesignSystemButtonSize { small, medium, large }
