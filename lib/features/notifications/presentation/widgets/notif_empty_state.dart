// Extracted from notifications_screen_v2.dart by KAN-151 (pt.B of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class NotifEmptyState extends StatelessWidget {
  const NotifEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: DabblerSpacing.space11,
        horizontal: DabblerSpacing.space8,
      ),
      child: DabblerEmptyState(
        icon: 'notification-bing',
        title: l10n.notif_empty_no_notifications,
        text: l10n.notif_empty_subtitle,
        size: DabblerEmptyStateSize.page,
      ),
    );
  }
}
