import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// Content of the notification-permission sheet, with three options:
/// 1. Enable Notifications - Request device native notification permission
/// 2. Remind me later - Close and ask again next time
/// 3. No thanks - Close and never ask again
///
/// Content only: the sheet surface, handle, scrim and the "Stay Updated"
/// title come from [showDabblerSheet] (`title:` at the call).
class NotificationPermissionDrawer extends StatelessWidget {
  const NotificationPermissionDrawer({
    super.key,
    required this.onEnableNotifications,
    required this.onRemindLater,
    required this.onNoThanks,
  });

  final VoidCallback onEnableNotifications;
  final VoidCallback onRemindLater;
  final VoidCallback onNoThanks;

  @override
  Widget build(BuildContext context) {
    // Widgets only: the sheet owns the surface and the content padding
    // (the sheet convention, `components/sheet.md`).
    final l10n = AppLocalizations.of(context);
    return DabblerSheetBody(
      spacing: DabblerSpacing.space7,
      actions: DabblerSheetActions(
        children: <Widget>[
          DabblerButton(
            label: l10n.notif_perm_enable,
            icon: 'notification-bing',
            fullWidth: true,
            onPressed: onEnableNotifications,
          ),
          DabblerButton(
            label: l10n.notif_perm_remind_later,
            icon: 'clock',
            tone: DabblerButtonTone.secondary,
            fullWidth: true,
            onPressed: onRemindLater,
          ),
          DabblerButton(
            label: l10n.notif_perm_no_thanks,
            tone: DabblerButtonTone.neutral,
            fullWidth: true,
            onPressed: onNoThanks,
          ),
        ],
      ),
      children: <Widget>[
        const DabblerIconTile.named('notification'),
        DabblerText(
          l10n.notif_perm_body,
          style: DabblerType.body,
          tone: DabblerTextTone.secondary,
        ),
      ],
    );
  }
}
