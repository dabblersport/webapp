import 'package:flutter/material.dart';

/// AppBackground renders a full-screen gradient behind the entire app.
///
/// Gradients:
/// - Light: linear-gradient(137deg, #F5EDFF 10.52%, #EADAFF 89.32%)
/// - Dark:  linear-gradient(137deg, #1E0E33 10.52%, #5B2B99 89.32%)
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return IgnorePointer(child: Container(color: color));
  }
}
