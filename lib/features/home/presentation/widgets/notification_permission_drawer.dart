import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Content of the notification-permission sheet, with three options:
/// 1. Enable Notifications - Request device native notification permission
/// 2. Remind me later - Close and ask again next time
/// 3. No thanks - Close and never ask again
///
/// Content only: the sheet surface, handle and scrim come from
/// [showDabblerSheet].
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
    return DabblerSheetBody(
      spacing: DabblerSpacing.space7,
      actions: DabblerSheetActions(
        children: <Widget>[
          DabblerButton(
            label: 'Enable Notifications',
            icon: 'notification-bing',
            fullWidth: true,
            onPressed: onEnableNotifications,
          ),
          DabblerButton(
            label: 'Remind Me Later',
            icon: 'clock',
            tone: DabblerButtonTone.secondary,
            fullWidth: true,
            onPressed: onRemindLater,
          ),
          DabblerButton(
            label: 'No Thanks',
            tone: DabblerButtonTone.neutral,
            fullWidth: true,
            onPressed: onNoThanks,
          ),
        ],
      ),
      children: <Widget>[
        const DabblerIconTile.named('notification'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: DabblerSpacing.space2,
          children: <Widget>[
            DabblerText('Stay Updated', style: DabblerType.title2),
            DabblerText(
              'Get notified about game invites, squad updates, and messages. '
              'Never miss out on the action!',
              style: DabblerType.body,
              tone: DabblerTextTone.secondary,
            ),
          ],
        ),
      ],
    );
  }
}
