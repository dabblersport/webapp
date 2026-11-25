// KAN-1048 (NOTIF-4): the channel groups (KAN-1045). One section per group in
// `sort_order`: an "All '<group>'" switch, then one switch per channel with
// its label in the app's language. A group switch is on while any of its
// channels is on. Security cannot be muted: its switches are disabled and a
// note says why. Changes apply at once and revert, with an error toast, when
// the server refuses. The mutes stop pushes, so the switches follow the push
// master switch.

import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/notifications/data/models/notification_channel.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notification_channels_controller.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

import 'notification_settings_rows.dart';

/// The localized name of a channel group; an unknown key shows as itself.
String notifChannelGroupName(AppLocalizations l10n, String group) =>
    switch (group) {
      'games' => l10n.notif_channels_group_games,
      'meetups' => l10n.notif_channels_group_meetups,
      'activities' => l10n.notif_channels_group_activities,
      'messages' => l10n.notif_channels_group_messages,
      'social' => l10n.notif_channels_group_social,
      'booking' => l10n.notif_channels_group_booking,
      'security' => l10n.notif_channels_group_security,
      'system' => l10n.notif_channels_group_system,
      _ => group,
    };

class NotificationSettingsChannelsSection extends ConsumerWidget {
  const NotificationSettingsChannelsSection({
    super.key,
    required this.pushLocked,
  });

  /// Push is off (master switch or phone permission): every switch is
  /// disabled.
  final bool pushLocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NotificationChannelsState state = ref.watch(
      notificationChannelsControllerProvider,
    );
    final List<NotificationChannelGroup> groups = state.groups;
    if (groups.isEmpty) return const SizedBox.shrink();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    final NotificationChannelsController controller = ref.read(
      notificationChannelsControllerProvider.notifier,
    );

    void report(Future<bool> change) => unawaited(
      change.then((bool ok) {
        if (ok || !context.mounted) return;
        DabblerToastProvider.of(context).show(
          DabblerToastSpec(
            message: l10n.notif_channels_update_failed,
            tone: DabblerToastTone.error,
          ),
        );
      }),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final NotificationChannelGroup g in groups) ...[
          const SizedBox(height: DabblerSpacing.space7),
          DabblerRowGroup(
            key: ValueKey<String>('notif-group-${g.key}'),
            header: notifChannelGroupName(l10n, g.key),
            note: g.canMute ? null : l10n.notif_channels_locked_note,
            children: [
              NotifSettingsSwitchRow(
                key: ValueKey<String>('notif-group-toggle-${g.key}'),
                title: l10n.notif_channels_all(
                  notifChannelGroupName(l10n, g.key),
                ),
                value: g.anyOn,
                disabled: pushLocked || !g.canMute,
                onChanged: (bool on) =>
                    report(controller.setGroupOn(g.key, on)),
              ),
              for (final NotificationChannel c in g.channels)
                NotifSettingsSwitchRow(
                  key: ValueKey<String>('notif-channel-${c.key}'),
                  title: c.label(lang),
                  value: c.on,
                  disabled: pushLocked || !c.canMute,
                  onChanged: (bool on) =>
                      report(controller.setChannelOn(c.key, on)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
