// KAN-991 (SET-01, F-12, F-17): in-app and push per category. Social,
// Messages, Games, Meetups and Rewards & announcements; Rewards &
// announcements is in-app only (no push control, SET-01). Booking is hidden
// (F-12). Security is shown always on and cannot be switched off. There is no
// Email, SMS, "Friends" or "Login alerts" row.

import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings_keys.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';

import 'notification_settings_rows.dart';

/// The label, detail and icon of a category row.
({String title, String sub, String icon}) notifCategoryLabel(
  AppLocalizations l10n,
  String category,
) => switch (category) {
  NotifCategoryKey.social => (
    title: l10n.notif_settings_cat_social,
    sub: l10n.notif_settings_cat_social_sub,
    icon: 'people',
  ),
  NotifCategoryKey.messages => (
    title: l10n.notif_settings_cat_messages,
    sub: l10n.notif_settings_cat_messages_sub,
    icon: 'message-text',
  ),
  NotifCategoryKey.games => (
    title: l10n.notif_settings_cat_games,
    sub: l10n.notif_settings_cat_games_sub,
    icon: 'game',
  ),
  NotifCategoryKey.meetups => (
    title: l10n.notif_settings_cat_meetups,
    sub: l10n.notif_settings_cat_meetups_sub,
    icon: 'calendar',
  ),
  _ => (
    title: l10n.notif_settings_cat_system,
    sub: l10n.notif_settings_cat_system_sub,
    icon: 'coin',
  ),
};

class NotificationSettingsCategoriesSection extends StatelessWidget {
  const NotificationSettingsCategoriesSection({
    super.key,
    required this.settings,
    required this.controller,
    required this.osDenied,
    required this.onPushTurnedOn,
  });

  final NotificationSettings settings;
  final NotificationSettingsController controller;

  /// The phone's permission is off: every push switch is disabled.
  final bool osDenied;

  /// The push master switch went on: ask for the OS permission (the one
  /// place the native prompt is asked for).
  final VoidCallback onPushTurnedOn;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool pushLocked = osDenied || !settings.pushEnabled;
    return DabblerRowGroup(
      header: l10n.notif_settings_categories_header,
      children: [
        NotifSettingsSwitchRow(
          title: l10n.notif_settings_push,
          subtitle: l10n.notif_settings_push_sub,
          icon: 'notification',
          value: settings.pushEnabled,
          disabled: osDenied,
          onChanged: (bool on) {
            unawaited(controller.setPushEnabled(on));
            if (on) onPushTurnedOn();
          },
        ),
        for (final String c in NotifCategoryKey.shown)
          _CategoryRow(
            category: c,
            settings: settings,
            controller: controller,
            pushLocked: pushLocked,
          ),
        const _SecurityRow(),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.settings,
    required this.controller,
    required this.pushLocked,
  });

  final String category;
  final NotificationSettings settings;
  final NotificationSettingsController controller;
  final bool pushLocked;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DabblerColors colors = DabblerColors.of(context);
    final label = notifCategoryLabel(l10n, category);
    final bool inAppOnly = category == NotifCategoryKey.system;
    return DabblerInputRow(
      key: ValueKey<String>('notif-category-$category'),
      flat: true,
      showDivider: false,
      dense: true,
      title: label.title,
      subtitle: label.sub,
      leading: DabblerIcon(
        label.icon,
        size: DabblerSizing.iconMd,
        color: colors.textSecondary,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotifSettingsChannelToggle(
            key: ValueKey<String>('notif-$category-in_app'),
            label: l10n.notif_settings_channel_in_app,
            semanticLabel:
                '${label.title} · ${l10n.notif_settings_channel_in_app}',
            value: settings.categoryOn(category, NotifChannel.inApp),
            onChanged: (bool on) => unawaited(
              controller.setCategory(category, NotifChannel.inApp, on),
            ),
          ),
          if (!inAppOnly) ...[
            const SizedBox(width: DabblerSpacing.space3),
            NotifSettingsChannelToggle(
              key: ValueKey<String>('notif-$category-push'),
              label: l10n.notif_settings_channel_push,
              semanticLabel:
                  '${label.title} · ${l10n.notif_settings_channel_push}',
              value: settings.categoryOn(category, NotifChannel.push),
              disabled: pushLocked,
              onChanged: (bool on) => unawaited(
                controller.setCategory(category, NotifChannel.push, on),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Security notices: always on, never switchable (CEO answer; F-16).
class _SecurityRow extends StatelessWidget {
  const _SecurityRow();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DabblerColors colors = DabblerColors.of(context);
    return DabblerInputRow(
      key: const ValueKey<String>('notif-category-security'),
      flat: true,
      showDivider: false,
      dense: true,
      title: l10n.notif_settings_cat_security,
      subtitle: l10n.notif_settings_cat_security_sub,
      leading: DabblerIcon(
        'security',
        size: DabblerSizing.iconMd,
        color: colors.textSecondary,
      ),
      trailing: DabblerToggle(
        key: const ValueKey<String>('notif-security-toggle'),
        checked: true,
        disabled: true,
        semanticLabel:
            '${l10n.notif_settings_cat_security} · ${l10n.notif_settings_always_on}',
      ),
    );
  }
}
