// Moved verbatim from lib/app/app_router.dart under KAN-124 (P0-3b); the only
// change is the removal of the leading underscore, because a private class
// cannot be reached from a sibling module file.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Placeholder screen for routes that don't have screens implemented yet.
///
/// Built from the design system: a [DabblerPage] with a titled top bar (the
/// back action pops the route) and a [DabblerEmptyState] body.
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: title,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Center(
        child: DabblerEmptyState(
          icon: 'setting-2',
          title: '$title\nComing Soon',
          action: DabblerButton(
            label: 'Go Back',
            tone: DabblerButtonTone.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
