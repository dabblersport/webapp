import 'package:flutter/material.dart';

/// Custom input field matching Figma design specifications
/// Node: 196:1099 (Input)
///
/// Design specs:
/// - Size: 319×42px (height: 42px)
/// - Padding: 12px all around
/// - Corner radius: 9px
/// - Background: #FBFBFB
/// - Border: Primary color stroke
/// - Layout: Horizontal with 6px spacing
class CustomInputField extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final String? Function(String?)? validator;

  const CustomInputField({
    super.key,
    this.label,
    this.placeholder,
    this.hintText,
    this.helperText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.onTap,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: 42.0, // Figma spec
          decoration: BoxDecoration(
            color: const Color(0xFFFBFBFB), // Figma background color
            borderRadius: BorderRadius.circular(9.0), // Figma corner radius
            border: Border.all(
              color: errorText != null
                  ? colorScheme.error
                  : colorScheme.primary,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              // Prefix icon container
              if (prefixIcon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 12.0), // Figma padding
                  child: Icon(
                    prefixIcon!,
                    size: 18.0,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6.0), // Figma item spacing
              ] else
                const SizedBox(width: 12.0), // Figma padding when no prefix
              // Text input (grows to fill)
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  onTap: onTap,
                  obscureText: obscureText,
                  readOnly: readOnly,
                  enabled: enabled,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  minLines: minLines,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: placeholder ?? hintText,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10.0, // Center text vertically in 42px height
                    ),
                    isDense: true,
                  ),
                ),
              ),

              // Suffix icon container
              if (suffixIcon != null) ...[
                const SizedBox(width: 6.0), // Figma item spacing
                Padding(
                  padding: const EdgeInsets.only(right: 12.0), // Figma padding
                  child: suffixIcon,
                ),
              ] else
                const SizedBox(width: 12.0), // Figma padding when no suffix
            ],
          ),
        ),

        // Helper and error text below the field
        if (helperText != null || errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Text(
              errorText ?? helperText!,
              style: textTheme.bodySmall?.copyWith(
                color: errorText != null
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class CustomTextArea extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool enabled;
  final int minLines;
  final int maxLines;

  const CustomTextArea({
    super.key,
    this.label,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.controller,
    this.onChanged,
    this.readOnly = false,
    this.enabled = true,
    this.minLines = 3,
    this.maxLines = 5,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          onChanged: onChanged,
          readOnly: readOnly,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: placeholder,
            helperText: helperText,
            errorText: errorText,
            // Material 3 uses InputDecorationTheme from theme
          ).applyDefaults(Theme.of(context).inputDecorationTheme),
        ),
      ],
    );
  }
}
