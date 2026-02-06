import 'package:flutter/material.dart';

/// Use native Material 3 TextField/TextFormField instead
/// Material 3 provides InputDecorationTheme for consistent styling
@Deprecated('Use native Material 3 TextField or TextFormField')
class AppInputField extends StatelessWidget {
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
  final Widget? prefixWidget;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final String? Function(String?)? validator;

  const AppInputField({
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
    this.prefixWidget,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
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
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: placeholder ?? hintText,
            hintStyle: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.5),
              fontSize: 15,
            ),
            helperText: helperText,
            helperStyle: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            errorText: errorText,
            errorStyle: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            prefixIcon:
                prefixWidget ??
                (prefixIcon != null
                    ? Icon(
                        prefixIcon,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      )
                    : null),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark
                ? colorScheme.surfaceContainerLow
                : colorScheme.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// Text area component for multi-line input
class AppTextArea extends StatelessWidget {
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

  const AppTextArea({
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
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(9.0),
            border: Border.all(
              color: errorText != null
                  ? colorScheme.error
                  : colorScheme.primary,
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            readOnly: readOnly,
            enabled: enabled,
            minLines: minLines,
            maxLines: maxLines,
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: placeholder,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
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
