// Extracted from notifications_screen_v2.dart by KAN-152 (pt.C of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class ActivityEmptyState extends StatelessWidget {
  const ActivityEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: DabblerSpacing.space11,
        horizontal: DabblerSpacing.space8,
      ),
      child: DabblerEmptyState(
        icon: 'activity',
        title: l10n.activity_empty_no_activity,
        text: l10n.activity_empty_subtitle,
        size: DabblerEmptyStateSize.page,
      ),
    );
  }
}
