// KAN-991 (G-11, F-2): message previews. Two options, "Sender name +
// message" by default, with a sample push under the choice and a note that
// the phone's lock-screen setting still applies.

import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';

import 'notification_settings_rows.dart';

class NotificationSettingsPreviewSection extends StatelessWidget {
  const NotificationSettingsPreviewSection({
    super.key,
    required this.settings,
    required this.controller,
  });

  final NotificationSettings settings;
  final NotificationSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool senderOnly = settings.previewSenderOnly;
    return DabblerRowGroup(
      header: l10n.notif_settings_preview_header,
      children: [
        _option(
          context,
          key: 'full',
          label: l10n.notif_settings_preview_full,
          selected: !senderOnly,
          onSelected: () => controller.setPreviewSenderOnly(false),
        ),
        _option(
          context,
          key: 'name',
          label: l10n.notif_settings_preview_name,
          selected: senderOnly,
          onSelected: () => controller.setPreviewSenderOnly(true),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: DabblerSpacing.space3),
          child: DabblerText(
            l10n.notif_settings_preview_sample,
            style: DabblerType.caption1,
            tone: DabblerTextTone.secondary,
          ),
        ),
        DabblerNotificationRow(
          key: const ValueKey<String>('notif-preview-sample'),
          leading: DabblerIconTile.named(
            'message-text',
            tone: DabblerIconTileTone.brand,
          ),
          actor: l10n.notif_settings_preview_sample_sender,
          subject: senderOnly
              ? l10n.notif_settings_preview_sample_hidden
              : l10n.notif_settings_preview_sample_message,
        ),
        NotifSettingsNote(l10n.notif_settings_preview_note),
      ],
    );
  }

  Widget _option(
    BuildContext context, {
    required String key,
    required String label,
    required bool selected,
    required Future<void> Function() onSelected,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: DabblerSpacing.space2,
      ),
      child: DabblerRadio(
        key: ValueKey<String>('notif-preview-$key'),
        selected: selected,
        label: label,
        onChanged: (bool on) {
          if (on && !selected) unawaited(onSelected());
        },
      ),
    );
  }
}
