import 'package:flutter/material.dart';

/// A filter chip widget using Material Design 3
///
/// Rest state: Shows emoji + label
/// Active state: Shows emoji + label + optional count badge
class AppFilterChip extends StatelessWidget {
  /// Optional emoji to display (e.g., '⚽️'). Provide either [emoji] or [icon].
  final String? emoji;

  /// Optional icon to display instead of emoji.
  final IconData? icon;

  /// Optional icon color override (defaults to onSurfaceVariant).
  final Color? iconColor;

  /// Icon size when using [icon]. Defaults to 18.
  final double iconSize;

  /// The label text (e.g., 'Football', 'All')
  final String label;

  /// Whether the chip is selected/active
  final bool isSelected;

  /// Callback when the chip is tapped
  final VoidCallback? onTap;

  /// Optional count to display in active state
  final int? count;

  /// Background color when selected
  final Color? selectedColor;

  /// Border color when selected (legacy compatibility)
  final Color? selectedBorderColor;

  /// Text color when selected (legacy compatibility)
  final Color? selectedTextColor;

  const AppFilterChip({
    super.key,
    this.emoji,
    this.icon,
    this.iconColor,
    this.iconSize = 18,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.count,
    this.selectedColor,
    this.selectedBorderColor,
    this.selectedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    assert(
      (emoji != null && emoji!.isNotEmpty) || icon != null,
      'Provide either an emoji or an icon to AppFilterChip',
    );

    final colorScheme = Theme.of(context).colorScheme;
    final leadingWidget = icon != null
        ? Icon(
            icon,
            size: iconSize,
            color: iconColor ?? colorScheme.onSurfaceVariant,
          )
        : Text(emoji!, style: const TextStyle(fontSize: 16));

    return FilterChip(
      selected: isSelected,
      onSelected: onTap != null ? (_) => onTap!() : null,
      selectedColor: selectedColor,
      showCheckmark: false,
      label: Row(
        mainAxisSize: isSelected ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: isSelected
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          // Leading visual (icon or emoji)
          leadingWidget,
          const SizedBox(width: 6),

          // Label - expand when selected to show full text
          if (isSelected)
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible,
                maxLines: 1,
              ),
            )
          else
            Flexible(
              child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),

          // Count badge (only shown when selected and count is provided)
          if (isSelected && count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
