import 'package:flutter/material.dart';

/// A reusable background widget that creates a dynamic, scroll-linked gradient.
/// It transitions from a primary container color (at the top) to the surface color.
class DynamicBackground extends StatelessWidget {
  const DynamicBackground({
    super.key,
    this.scrollController,
    this.tabController,
    this.scrollControllers,
    this.startColor,
  });

  /// Single scroll controller for standard screens.
  final ScrollController? scrollController;

  /// Tab controller for multi-tab screens (like Home).
  final TabController? tabController;

  /// List of scroll controllers corresponding to tabs.
  final List<ScrollController>? scrollControllers;

  /// Override the start color (default is themed primaryContainer).
  final Color? startColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;

    // Collect all listeners that should trigger a rebuild
    final drivers = <Listenable>[];
    if (scrollController != null) drivers.add(scrollController!);
    if (tabController != null) drivers.add(tabController!);
    if (scrollControllers != null) {
      for (final sc in scrollControllers!) {
        drivers.add(sc);
      }
    }

    return AnimatedBuilder(
      animation: Listenable.merge(drivers),
      builder: (context, _) {
        double offset = 0.0;

        if (tabController != null && scrollControllers != null) {
          // Multi-tab logic: use offset of the active tab's controller
          final index = tabController!.index;
          if (index >= 0 && index < scrollControllers!.length) {
            final sc = scrollControllers![index];
            offset = sc.hasClients ? sc.offset : 0.0;
          }
        } else if (scrollController != null) {
          // Single-scroll logic
          offset = scrollController!.hasClients ? scrollController!.offset : 0.0;
        }

        // Configuration matching the Home screen aesthetic
        const baseStop = 0.20;
        // Parallax effect: shift the gradient up as we scroll down
        final dynamicStop = (baseStop * screenHeight - offset) / screenHeight;
        
        // Clamp stops to keep the transition smooth and predictable
        final clampedStart = dynamicStop.clamp(0.0, 0.1);
        final clampedEnd = (clampedStart + 0.30).clamp(0.4, 1.0);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [clampedStart, clampedEnd],
              colors: [
                (startColor ?? cs.primaryContainer).withValues(alpha: 0.3),
                cs.surface,
              ],
            ),
          ),
        );
      },
    );
  }
}
