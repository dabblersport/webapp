import 'package:flutter/material.dart';

/// Breakpoints for the adaptive layout, modelled after Twitter/X web.
class AdaptiveBreakpoints {
  /// Below this: mobile layout (bottom nav).
  static const double compact = 600;

  /// Below this: rail layout (icon-only side nav).
  static const double medium = 1080;

  /// Above [medium]: full layout (side nav with labels + right panel).
}

/// Destination descriptor shared between bottom nav and side rail/drawer.
class AdaptiveDestination {
  const AdaptiveDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.isAction = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// If true this entry is a CTA (e.g. "Create") instead of a page.
  final bool isAction;
}

/// A scaffold that adapts between mobile (bottom-nav) and desktop
/// (side-nav + optional right panel) layouts, similar to Twitter/X.
///
/// [body] is the main content area.
/// [rightPanel] is shown only on wide screens (> 1080 px) — pass trending
/// or suggestion widgets here.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.body,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.rightPanel,
    this.mobileBottomNav,
    this.maxContentWidth = 600,
    this.headerWidget,
  });

  /// Main scrollable content (the feed, explore, etc.).
  final Widget body;

  /// Navigation destinations shared between mobile & desktop.
  final List<AdaptiveDestination> destinations;

  /// Currently selected index.
  final int currentIndex;

  /// Called when a destination is tapped.
  final ValueChanged<int> onDestinationSelected;

  /// Optional right-side panel shown on wide screens (trending, suggestions).
  final Widget? rightPanel;

  /// Custom mobile bottom navigation bar. If null, a default bottom nav from
  /// [destinations] is rendered on compact screens.
  final Widget? mobileBottomNav;

  /// Max width of the centre column.
  final double maxContentWidth;

  /// Optional branding widget placed at the top of the side navigation.
  final Widget? headerWidget;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < AdaptiveBreakpoints.compact) {
          // ── Mobile: bottom nav ──
          return _MobileLayout(body: body, bottomNav: mobileBottomNav);
        }

        final bool showLabels = width >= AdaptiveBreakpoints.medium;
        final bool showRightPanel =
            width >= AdaptiveBreakpoints.medium && rightPanel != null;

        // ── Desktop / Tablet: side rail + content + optional right panel ──
        return _DesktopLayout(
          body: body,
          destinations: destinations,
          currentIndex: currentIndex,
          onDestinationSelected: onDestinationSelected,
          showLabels: showLabels,
          showRightPanel: showRightPanel,
          rightPanel: rightPanel,
          maxContentWidth: maxContentWidth,
          headerWidget: headerWidget,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private layout widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({required this.body, this.bottomNav});

  final Widget body;
  final Widget? bottomNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: bottomNav,
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.body,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.showLabels,
    required this.showRightPanel,
    required this.maxContentWidth,
    this.rightPanel,
    this.headerWidget,
  });

  final Widget body;
  final List<AdaptiveDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool showLabels;
  final bool showRightPanel;
  final Widget? rightPanel;
  final double maxContentWidth;
  final Widget? headerWidget;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final double railWidth = showLabels ? 240 : 72;

    // Total max width of the three-column group, so on very wide
    // screens the extra space is pushed to the outside (left & right)
    // instead of between columns.
    final double totalMaxWidth =
        railWidth +
        1 + // left divider
        maxContentWidth +
        (showRightPanel ? 1 + 340 : 0); // right divider + panel

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: totalMaxWidth),
          child: Row(
            children: [
              // ── Left navigation rail / sidebar ──
              SizedBox(
                width: railWidth,
                child: Material(
                  color: colorScheme.surface,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: showLabels ? 16 : 8,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: showLabels
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
                        children: [
                          if (headerWidget != null) ...[
                            headerWidget!,
                            const SizedBox(height: 24),
                          ],
                          // Nav items
                          ...List.generate(destinations.length, (i) {
                            final dest = destinations[i];
                            final isSelected = currentIndex == i;

                            return _SideNavItem(
                              icon: isSelected ? dest.selectedIcon : dest.icon,
                              label: dest.label,
                              isSelected: isSelected,
                              showLabel: showLabels,
                              isAction: dest.isAction,
                              onTap: () => onDestinationSelected(i),
                            );
                          }),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Thin vertical divider ──
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),

              // ── Centre content — fills remaining space within the
              //    constrained group, no extra gaps ──
              Expanded(child: body),

              // ── Right panel ──
              if (showRightPanel) ...[
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                SizedBox(
                  width: 340,
                  child: Material(
                    color: colorScheme.surface,
                    child: rightPanel,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A single item in the side navigation — icon only (rail) or icon + label.
class _SideNavItem extends StatefulWidget {
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.showLabel,
    required this.onTap,
    this.isAction = false,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool showLabel;
  final bool isAction;
  final VoidCallback onTap;

  @override
  State<_SideNavItem> createState() => _SideNavItemState();
}

class _SideNavItemState extends State<_SideNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final Color iconColor;
    final Color? bgColor;

    if (widget.isAction) {
      iconColor = colorScheme.primary;
      bgColor = _hovered ? colorScheme.primary.withValues(alpha: 0.08) : null;
    } else if (widget.isSelected) {
      iconColor = colorScheme.onSurface;
      bgColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    } else {
      iconColor = _hovered
          ? colorScheme.onSurface
          : colorScheme.onSurfaceVariant;
      bgColor = _hovered
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: widget.showLabel ? 16 : 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisSize: widget.showLabel
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 26, color: iconColor),
                if (widget.showLabel) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: textTheme.titleSmall?.copyWith(
                        color: iconColor,
                        fontWeight: widget.isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
