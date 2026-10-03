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
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space8,
        end: DabblerSpacing.space8,
        bottom: DabblerSpacing.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DabblerIconTile.named('notification'),
          const SizedBox(height: DabblerSpacing.space7),
          DabblerText('Stay Updated', style: DabblerType.title2),
          const SizedBox(height: DabblerSpacing.space2),
          DabblerText(
            'Get notified about game invites, squad updates, and messages. '
            'Never miss out on the action!',
            style: DabblerType.body,
            tone: DabblerTextTone.secondary,
          ),
          const SizedBox(height: DabblerSpacing.space10),
          DabblerButton(
            label: 'Enable Notifications',
            icon: 'notification-bing',
            fullWidth: true,
            onPressed: onEnableNotifications,
          ),
          const SizedBox(height: DabblerSpacing.space4),
          DabblerButton(
            label: 'Remind Me Later',
            icon: 'clock',
            tone: DabblerButtonTone.secondary,
            fullWidth: true,
            onPressed: onRemindLater,
          ),
          const SizedBox(height: DabblerSpacing.space3),
          DabblerButton(
            label: 'No Thanks',
            tone: DabblerButtonTone.neutral,
            fullWidth: true,
            onPressed: onNoThanks,
          ),
        ],
      ),
    );
  }
}
