import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:dabbler/core/constants/adaptive_destinations.dart';
import 'package:dabbler/widgets/adaptive_scaffold.dart';

/// Wraps any screen body with the app's adaptive layout:
///
/// * **Narrow** (< 600 px) — returns [body] as-is (the screen manages its own
///   `Scaffold` / scroll / bottom-nav).
/// * **Wide** (≥ 600 px) — embeds [body] inside [AdaptiveScaffold] so it gets
///   a side-nav rail (left), main content (center), and an optional
///   [rightPanel] column.
///
/// Usage:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return AdaptiveScreenWrapper(
///     currentNavIndex: 5, // Profile
///     body: _buildMobileBody(),
///     rightPanel: _buildContextPanel(),
///   );
/// }
/// ```
class AdaptiveScreenWrapper extends StatelessWidget {
  const AdaptiveScreenWrapper({
    super.key,
    required this.body,
    this.rightPanel,
    this.currentNavIndex = -1,
    this.onDestinationSelected,
    this.maxContentWidth = 600,
    this.headerWidget,
  });

  /// The main content — typically the screen's existing mobile widget tree.
  final Widget body;

  /// Optional right-side panel shown when viewport ≥ 1080 px.
  final Widget? rightPanel;

  /// Index into [kAdaptiveDestinations] to highlight in the side nav.
  /// Pass `-1` when no destination should be highlighted (e.g. a detail page).
  final int currentNavIndex;

  /// Override the default destination-tap handler.
  final ValueChanged<int>? onDestinationSelected;

  /// Max width of the centre column inside [AdaptiveScaffold].
  final double maxContentWidth;

  /// Optional branding widget at the top of the side rail (defaults to the
  /// Dabbler text logo).
  final Widget? headerWidget;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width < AdaptiveBreakpoints.compact) {
      return body;
    }

    final colorScheme = Theme.of(context).colorScheme;

    return AdaptiveScaffold(
      currentIndex: currentNavIndex,
      onDestinationSelected:
          onDestinationSelected ??
          (i) => onAdaptiveDestinationSelected(
            context,
            i,
            activeIndex: currentNavIndex,
          ),
      destinations: kAdaptiveDestinations,
      headerWidget:
          headerWidget ??
          SvgPicture.asset(
            'assets/images/dabbler_text_logo.svg',
            width: 100,
            height: 18,
            colorFilter: ColorFilter.mode(
              colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
      maxContentWidth: maxContentWidth,
      body: body,
      rightPanel: rightPanel,
    );
  }
}
