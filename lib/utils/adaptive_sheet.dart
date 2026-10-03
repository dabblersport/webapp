import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show ColorScheme, Material, MaterialType;
import 'package:flutter/widgets.dart';

/// Shows a modal bottom sheet built from the design system.
///
/// Kept as the single entry point the app's many sheet call sites use
/// (listed in the KAN-413 report); it now delegates to [showDabblerSheet], so a
/// sheet is the design system's sheet at every width (the centred Material
/// dialog on wide viewports is gone: the design has no desktop layout).
///
/// Sheet contents that are not yet migrated still use Material widgets that
/// need a Material ancestor, so the content sits in a transparent `Material`
/// (it paints nothing). That wrapper goes away with the last unmigrated
/// content.
///
/// [isScrollControlled], [useSafeArea], [backgroundColor] and [enableDrag] no
/// longer change anything: the design-system sheet owns its surface, safe area
/// and drag handling. They stay in the signature so callers compile unchanged.
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
  return showDabblerSheet<T>(
    context: context,
    dismissible: isDismissible,
    dragHandle: showDragHandle,
    detents: const <double>[0.6, 0.95],
    builder: (ctx) => Material(
      type: MaterialType.transparency,
      child: builder(ctx),
    ),
  );
}
