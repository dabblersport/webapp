import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A simple shimmer loading placeholder widget.
///
/// Colors are resolved from the active [ColorScheme] so the shimmer adapts
/// correctly to both light and dark themes without any hardcoded values.
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 16.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: cs.surfaceContainerHigh,
      // In dark mode: surfaceContainerHighest is a higher tone (lighter).
      // In light mode: surfaceContainerLow is a higher tone (lighter).
      highlightColor: isDark
          ? cs.surfaceContainerHighest
          : cs.surfaceContainerLow,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
