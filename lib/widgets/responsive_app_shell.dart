import 'package:flutter/material.dart';

import 'app_background.dart';

/// Wraps the entire app with a full-bleed layout and an [AppBackground] behind
/// the content.  Width clamping has been removed so that the adaptive scaffold
/// system can kick in at its own breakpoints (≥ 600 dp).
class ResponsiveAppShell extends StatelessWidget {
  const ResponsiveAppShell({super.key, required this.child});

  /// Content rendered by the router.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: AppBackground()),
        SizedBox.expand(child: child),
      ],
    );
  }
}
