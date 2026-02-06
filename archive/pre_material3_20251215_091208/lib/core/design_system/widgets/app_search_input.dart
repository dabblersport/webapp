import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// A search input widget using Material Design 3
///
/// Adapts to work on both colored backgrounds and standard surfaces
class AppSearchInput extends StatelessWidget {
  /// Controller for the text field
  final TextEditingController? controller;

  /// Callback when the text changes
  final ValueChanged<String>? onChanged;

  /// Placeholder/hint text
  final String hintText;

  /// Whether to use light styling (for colored backgrounds)
  /// If false, uses standard theme colors
  final bool lightStyle;

  /// Custom height (defaults to 56)
  final double? height;

  const AppSearchInput({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText = 'Search',
    this.lightStyle = true,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height ?? 56.0;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: effectiveHeight,
      child: TextField(
        controller: controller,
        style: TextStyle(
          fontSize: 15,
          color: lightStyle ? Colors.white : colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: lightStyle
              ? Colors.black.withValues(alpha: 0.2)
              : (isDark
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.surfaceContainerHigh),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: lightStyle
                  ? Colors.transparent
                  : colorScheme.outlineVariant,
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: lightStyle
                  ? Colors.transparent
                  : colorScheme.outlineVariant,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: lightStyle
                  ? Colors.white.withValues(alpha: 0.5)
                  : colorScheme.primary,
              width: 2,
            ),
          ),
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 15,
            color: lightStyle
                ? Colors.white.withValues(alpha: 0.7)
                : colorScheme.surface,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              Iconsax.search_normal_copy,
              color: lightStyle
                  ? Colors.white.withValues(alpha: 0.7)
                  : colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
