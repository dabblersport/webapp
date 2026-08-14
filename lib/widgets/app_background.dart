import 'package:flutter/material.dart';

import 'dynamic_background.dart';

/// AppBackground renders the app-wide background behind every screen.
///
/// It paints the same primaryContainer → surface gradient used by the Home
/// screen ([DynamicBackground]), so all screens share the Home aesthetic.
/// Screens that own a scroll view can still stack their own
/// [DynamicBackground] with a controller on top to get the parallax effect.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(child: DynamicBackground());
  }
}

/// Transparent scaffold background so the app-wide [AppBackground] (the
/// shared aurora from the Pencil design — light node b68fG, dark node N4ZNP)
/// shows through on every screen in both brightnesses.
extension ScaffoldBackgroundX on BuildContext {
  Color get appScaffoldBackground => Colors.transparent;
}
