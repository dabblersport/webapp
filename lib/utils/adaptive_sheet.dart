import 'package:flutter/material.dart';

import 'package:dabbler/widgets/adaptive_scaffold.dart';

/// Shows a modal that adapts to screen width:
/// - **Narrow** (< 600 px): standard `showModalBottomSheet`.
/// - **Wide** (≥ 600 px): a centered Material 3 dialog.
///
/// This replaces all raw `showModalBottomSheet` calls in the app so that
/// drawers become popup modals on wide / desktop viewports.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = true,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  double maxDialogWidth = 480,
  double maxDialogHeightFraction = 0.7,
  Color? backgroundColor,
  ColorScheme? colorSchemeOverride,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final isWide = width >= AdaptiveBreakpoints.compact;

  // Optionally wrap content in a theme override (e.g. sports category colors).
  Widget Function(BuildContext) effectiveBuilder;
  if (colorSchemeOverride != null) {
    effectiveBuilder = (ctx) => Theme(
      data: Theme.of(ctx).copyWith(colorScheme: colorSchemeOverride),
      child: builder(ctx),
    );
  } else {
    effectiveBuilder = builder;
  }

  if (isWide) {
    return _showCenteredDialog<T>(
      context: context,
      builder: effectiveBuilder,
      isDismissible: isDismissible,
      maxWidth: maxDialogWidth,
      maxHeightFraction: maxDialogHeightFraction,
      backgroundColor: backgroundColor,
    );
  }

  // ── Mobile: bottom sheet ──────────────────────────────────────────────
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    builder: effectiveBuilder,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor ?? cs.surfaceContainerHigh,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  );
}

/// Internal: renders a centered M3 dialog that wraps the sheet content.
Future<T?> _showCenteredDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required bool isDismissible,
  required double maxWidth,
  required double maxHeightFraction,
  Color? backgroundColor,
}) {
  final cs = Theme.of(context).colorScheme;
  final screenHeight = MediaQuery.sizeOf(context).height;

  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    builder: (ctx) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: screenHeight * maxHeightFraction,
          ),
          child: Material(
            color: backgroundColor ?? cs.surfaceContainerHigh,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            child: builder(ctx),
          ),
        ),
      );
    },
  );
}
