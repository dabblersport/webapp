import 'package:flutter/material.dart';

import 'app_background.dart';

/// Wraps the entire app with a centered, fixed-width viewport on large screens
/// so that the experience stays mobile-first while still working on web.
class ResponsiveAppShell extends StatelessWidget {
  const ResponsiveAppShell({
    super.key,
    required this.child,
    this.maxContentWidth = 500,
  });

  /// Content rendered by the router.
  final Widget child;

  /// Maximum width before we clamp the layout to preserve a mobile feel.
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool clampWidth = constraints.maxWidth > maxContentWidth;
        final double targetWidth = clampWidth
            ? maxContentWidth
            : constraints.maxWidth;

        Widget content;

        if (clampWidth) {
          // On wide/web screens render the app in a centered mobile shell and
          // override MediaQuery so children still think they're on a phone.
          content = Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Container(
                constraints: BoxConstraints(maxWidth: targetWidth),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 60,
                      spreadRadius: 4,
                      offset: const Offset(0, 30),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38),
                  child: MediaQuery(
                    data: mediaQuery.copyWith(
                      size: Size(targetWidth, mediaQuery.size.height),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          );
        } else {
          content = SizedBox.expand(child: child);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: AppBackground()),
            content,
          ],
        );
      },
    );
  }
}
