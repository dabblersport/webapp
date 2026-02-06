import 'package:flutter/material.dart';

/// Design system tab component
/// Built on Material Design 3 TabBar/Tab foundation
/// Based on Figma node 127:169 (tab component)
///
/// Supports two variants: default and active
/// Can show optional icon, counter badge, and text label
/// Active tabs have a 2px bottom border, default tabs have 1px
class AppTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final Widget? icon;
  final int? counter;
  final VoidCallback? onTap;

  const AppTab({
    super.key,
    required this.label,
    this.isActive = false,
    this.icon,
    this.counter,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Constants from Figma design
    const double verticalPadding = 6.0;
    const double horizontalPadding = 12.0;
    const double itemSpacing = 3.0;
    const double iconSize = 24.0;
    const double minHeight = 36.0;

    // Active tab: bold text with 2px bottom border
    // Default tab: regular text with 1px bottom border at 6% opacity
    final Color textColor = isActive
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.92);

    final Color iconColor = isActive
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.92);

    final FontWeight fontWeight = isActive ? FontWeight.w700 : FontWeight.w400;
    final double fontSize = isActive ? 17.0 : 15.0;

    final BorderSide borderSide = isActive
        ? BorderSide(color: colorScheme.primary, width: 2.0)
        : BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.06),
            width: 1.0,
          );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: minHeight),
        decoration: BoxDecoration(border: Border(bottom: borderSide)),
        padding: const EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Optional icon
            if (icon != null) ...[
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: IconTheme(
                  data: IconThemeData(
                    color: iconColor,
                    size: iconSize * 0.75, // Icon is 18dp inside 24dp container
                  ),
                  child: icon!,
                ),
              ),
              const SizedBox(width: itemSpacing),
            ],

            // Label text
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: textColor,
                height: 1.17,
              ),
            ),

            // Optional counter badge
            if (counter != null) ...[
              const SizedBox(width: itemSpacing),
              _TabCounterBadge(count: counter!, isActive: isActive),
            ],
          ],
        ),
      ),
    );
  }
}

/// Counter badge component for tabs
class _TabCounterBadge extends StatelessWidget {
  final int count;
  final bool isActive;

  const _TabCounterBadge({required this.count, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Active: filled primary background with white text
    // Default: 60% opacity surface background with dark text
    final Color backgroundColor = isActive
        ? colorScheme.primary
        : colorScheme.surface.withValues(alpha: 0.6);

    final Color textColor = isActive
        ? colorScheme.onPrimary
        : colorScheme.onSurface.withValues(alpha: 0.92);

    return Container(
      height: 18.0,
      constraints: const BoxConstraints(minWidth: 24.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      alignment: Alignment.center,
      child: Text(
        count.toString(),
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w400,
          color: textColor,
          height: 1.17,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Tab bar component - horizontal list of tabs
class AppTabBar extends StatelessWidget {
  final List<AppTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final EdgeInsets? padding;

  const AppTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          return Padding(
            padding: EdgeInsets.only(right: index < tabs.length - 1 ? 8.0 : 0),
            child: AppTab(
              label: tab.label,
              isActive: selectedIndex == index,
              icon: tab.icon,
              counter: tab.counter,
              onTap: () => onTabSelected(index),
            ),
          );
        }),
      ),
    );
  }
}
