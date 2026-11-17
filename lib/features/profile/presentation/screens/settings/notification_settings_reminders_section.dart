// KAN-991 (G-10, F-4, I-5): a switch per reminder rung, for Going and for
// Interested, each saved on its own: 24h, 09:00 on the day, 2h, 30m. The
// reminders are pushes, so the switches are disabled while the phone's
// permission or the push master switch is off.

import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings_keys.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';

import 'notification_settings_rows.dart';

class NotificationSettingsRemindersSection extends StatelessWidget {
  const NotificationSettingsRemindersSection({
    super.key,
    required this.settings,
    required this.controller,
    required this.pushLocked,
  });

  final NotificationSettings settings;
  final NotificationSettingsController controller;

  /// OS permission denied or push master off.
  final bool pushLocked;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _group(
          context,
          group: NotifRung.going,
          title: l10n.notif_settings_reminders_going,
          sub: l10n.notif_settings_reminders_going_sub,
          header: l10n.notif_settings_reminders_header,
        ),
        const SizedBox(height: DabblerSpacing.space5),
        _group(
          context,
          group: NotifRung.interested,
          title: l10n.notif_settings_reminders_interested,
          sub: l10n.notif_settings_reminders_interested_sub,
        ),
      ],
    );
  }

  Widget _group(
    BuildContext context, {
    required String group,
    required String title,
    required String sub,
    String? header,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String nine = notifSettingsClock(context, 9 * 60);
    String label(String rung) => switch (rung) {
      NotifRung.day => l10n.notif_settings_rung_24h,
      NotifRung.morning => l10n.notif_settings_rung_morning(nine),
      NotifRung.twoHours => l10n.notif_settings_rung_2h,
      _ => l10n.notif_settings_rung_30m,
    };
    String? subOf(String rung) => rung != NotifRung.morning
        ? null
        : group == NotifRung.interested
        ? l10n.notif_settings_rung_morning_interested_sub
        : l10n.notif_settings_rung_morning_sub;
    return DabblerRowGroup(
      header: header,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: DabblerSpacing.space2,
            vertical: DabblerSpacing.space1,
          ),
          child: DabblerText(title, style: DabblerType.subheadline),
        ),
        NotifSettingsNote(sub),
        for (final String rung in NotifRung.rungs)
          NotifSettingsSwitchRow(
            key: ValueKey<String>('notif-rung-$group-$rung'),
            title: label(rung),
            subtitle: subOf(rung),
            icon: 'alarm',
            value: settings.rungOn(group, rung),
            disabled: pushLocked,
            onChanged: (bool on) =>
                unawaited(controller.setRung(group, rung, on)),
          ),
      ],
    );
  }
}
