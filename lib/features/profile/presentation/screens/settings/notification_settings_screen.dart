import 'package:dabbler/services/notifications/push_notification_service.dart';
import 'dart:async';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/profile/presentation/widgets/settings_inner_top_bar.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';

/// A row in the screen that maps a human label to one or more
/// `notification_kinds.key`s. The toggle is ON when none of [kinds] are muted.
class _KindToggle {
  const _KindToggle(this.title, this.subtitle, this.icon, this.kinds);
  final String title;
  final String subtitle;

  /// DS icon name rendered through [DabblerIcon].
  final String icon;
  final List<String> kinds;
}

/// Screen for managing notification preferences, backed by
/// `public.notification_settings`.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({
    super.key,
    this.meetupsEnabled = FeatureFlags.enableMeetups,
  });

  /// Shows the meetup host and guest kinds; follows FeatureFlags.enableMeetups.
  final bool meetupsEnabled;

  static List<_KindToggle> _gameToggles(AppLocalizations l) => [
    _KindToggle(
      l.notif_settings_kind_game_invites,
      l.notif_settings_kind_game_invites_sub,
      'game',
      const ['game.invited', 'game.join_request', 'game.join_accepted'],
    ),
    _KindToggle(
      l.notif_settings_kind_game_reminders,
      l.notif_settings_kind_game_reminders_sub,
      'alarm',
      const ['game.reminder'],
    ),
    _KindToggle(
      l.notif_settings_kind_game_updates,
      l.notif_settings_kind_game_updates_sub,
      'refresh-circle',
      const ['game.updated', 'game.waitlist_promoted', 'game.player_joined'],
    ),
    _KindToggle(
      l.notif_settings_kind_booking,
      l.notif_settings_kind_booking_sub,
      'card',
      const ['arena.payment_required'],
    ),
  ];

  static List<_KindToggle> _socialToggles(AppLocalizations l) => [
    _KindToggle(
      l.notif_settings_kind_likes,
      l.notif_settings_kind_likes_sub,
      'heart',
      const [
        'social.post_liked',
        'social.post_reacted',
        'social.comment_liked',
      ],
    ),
    _KindToggle(
      l.notif_settings_kind_comments,
      l.notif_settings_kind_comments_sub,
      'message-text',
      const ['social.post_commented'],
    ),
    _KindToggle(
      l.notif_settings_kind_mentions,
      l.notif_settings_kind_mentions_sub,
      'tag-user',
      const ['social.mentioned_in_post', 'social.mentioned_in_comment'],
    ),
    _KindToggle(
      l.notif_settings_kind_followers,
      l.notif_settings_kind_followers_sub,
      'user-add',
      const ['social.followed'],
    ),
  ];

  static List<_KindToggle> _connectionToggles(
    AppLocalizations l, {
    bool meetups = false,
  }) => [
    _KindToggle(
      l.notif_settings_kind_friends,
      l.notif_settings_kind_friends_sub,
      'profile-add',
      const ['friend.requested', 'friend.accepted'],
    ),
    _KindToggle(
      l.notif_settings_kind_squads,
      l.notif_settings_kind_squads_sub,
      'shield-tick',
      const ['squad.invited'],
    ),
    _KindToggle(
      l.notif_settings_kind_meetups,
      l.notif_settings_kind_meetups_sub,
      'people',
      const ['meetup.invited', 'meetup.player_joined'],
    ),
    if (meetups) ...[
      _KindToggle(
        l.notif_settings_kind_meetup_rsvps,
        l.notif_settings_kind_meetup_rsvps_sub,
        'people',
        const ['meetup.rsvp_received'],
      ),
      _KindToggle(
        l.notif_settings_kind_meetup_requests,
        l.notif_settings_kind_meetup_requests_sub,
        'profile-add',
        const ['meetup.request_received'],
      ),
      _KindToggle(
        l.notif_settings_kind_meetup_approved,
        l.notif_settings_kind_meetup_approved_sub,
        'refresh-circle',
        const ['meetup.request_approved'],
      ),
      _KindToggle(
        l.notif_settings_kind_meetup_declined,
        l.notif_settings_kind_meetup_declined_sub,
        'refresh-circle',
        const ['meetup.request_declined'],
      ),
      _KindToggle(
        l.notif_settings_kind_meetup_cancelled,
        l.notif_settings_kind_meetup_cancelled_sub,
        'alarm',
        const ['meetup.cancelled'],
      ),
    ],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationSettingsControllerProvider);

    // Surface save/load errors without blocking the UI.
    ref.listen<NotificationSettingsState>(
      notificationSettingsControllerProvider,
      (prev, next) {
        if (next.error != null && next.error != prev?.error) {
          DabblerToastProvider.of(context).show(
            DabblerToastSpec(
              message: AppLocalizations.of(
                context,
              ).notif_settings_update_failed('${next.error}'),
              tone: DabblerToastTone.error,
            ),
          );
        }
      },
    );

    return DabblerPage(
      topBar: settingsInnerTopBar(
        context,
        title: AppLocalizations.of(context).settings_tile_notifications,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DabblerSpacing.space6,
          DabblerSpacing.space4,
          DabblerSpacing.space6,
          DabblerSpacing.space11,
        ),
        children: [_buildBody(context, ref, state)],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotificationSettingsState state,
  ) {
    final settings = state.settings;
    if (settings == null) {
      return const Padding(
        padding: EdgeInsets.only(top: DabblerSpacing.space11),
        child: Center(child: DabblerSpinner()),
      );
    }

    final controller = ref.read(
      notificationSettingsControllerProvider.notifier,
    );
    final pushOn = settings.pushEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGeneralSection(context, settings, controller),
        const SizedBox(height: DabblerSpacing.space7),
        _buildQuietHoursSection(context, settings, controller),
        const SizedBox(height: DabblerSpacing.space7),
        // Per-kind sections only gate push, so dim them when push is off.
        DabblerInert(
          inert: !pushOn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildKindSection(
                context,
                AppLocalizations.of(context).notif_settings_group_game,
                _gameToggles(AppLocalizations.of(context)),
                settings,
                controller,
              ),
              const SizedBox(height: DabblerSpacing.space7),
              _buildKindSection(
                context,
                AppLocalizations.of(context).notif_settings_group_social,
                _socialToggles(AppLocalizations.of(context)),
                settings,
                controller,
              ),
              const SizedBox(height: DabblerSpacing.space7),
              _buildKindSection(
                context,
                AppLocalizations.of(context).notif_settings_group_connections,
                _connectionToggles(
                  AppLocalizations.of(context),
                  meetups: meetupsEnabled,
                ),
                settings,
                controller,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralSection(
    BuildContext context,
    NotificationSettings settings,
    NotificationSettingsController controller,
  ) {
    final l10n = AppLocalizations.of(context);
    return DabblerRowGroup(
      children: [
        _switchRow(
          context,
          l10n.notif_settings_push,
          l10n.notif_settings_push_sub,
          'notification',
          settings.pushEnabled,
          (on) {
            controller.setPushEnabled(on);
            // Turning push on is the in-app question: the native prompt is
            // asked for here, and only here (never at app start). With it off
            // nothing is requested.
            if (on) {
              unawaited(
                PushNotificationService.instance
                    .requestNotificationPermission(),
              );
            }
          },
        ),
        _switchRow(
          context,
          l10n.notif_settings_email,
          l10n.notif_settings_email_sub,
          'sms-notification',
          settings.emailEnabled,
          controller.setEmailEnabled,
        ),
        _switchRow(
          context,
          l10n.notif_settings_sms,
          l10n.notif_settings_sms_sub,
          'message',
          settings.smsEnabled,
          controller.setSmsEnabled,
        ),
      ],
    );
  }

  Widget _buildQuietHoursSection(
    BuildContext context,
    NotificationSettings settings,
    NotificationSettingsController controller,
  ) {
    final enabled = settings.hasQuietHours;
    final l10n = AppLocalizations.of(context);
    return DabblerRowGroup(
      header: l10n.notif_settings_quiet_header,
      children: [
        _switchRow(
          context,
          l10n.notif_settings_quiet_mute,
          enabled
              ? l10n.notif_settings_quiet_mute_on(
                  _fmt(context, settings.quietStartMin!),
                  _fmt(context, settings.quietEndMin!),
                )
              : l10n.notif_settings_quiet_mute_off,
          'moon',
          enabled,
          (value) {
            if (value) {
              // Sensible default window: 22:00 → 08:00.
              controller.setQuietHours(22 * 60, 8 * 60);
            } else {
              controller.clearQuietHours();
            }
          },
        ),
        if (enabled) ...[
          _timeRow(
            context,
            l10n.notif_settings_quiet_start,
            settings.quietStartMin!,
            (m) => controller.setQuietHours(m, settings.quietEndMin!),
          ),
          _timeRow(
            context,
            l10n.notif_settings_quiet_end,
            settings.quietEndMin!,
            (m) => controller.setQuietHours(settings.quietStartMin!, m),
          ),
          _switchRow(
            context,
            l10n.notif_settings_quiet_urgent,
            l10n.notif_settings_quiet_urgent_sub,
            'danger',
            settings.allowHighPriorityOverride,
            controller.setAllowHighPriorityOverride,
          ),
          _switchRow(
            context,
            l10n.notif_settings_quiet_all,
            l10n.notif_settings_quiet_all_sub,
            'notification-bing',
            settings.allowAllOverride,
            controller.setAllowAllOverride,
          ),
        ],
      ],
    );
  }

  Widget _buildKindSection(
    BuildContext context,
    String title,
    List<_KindToggle> toggles,
    NotificationSettings settings,
    NotificationSettingsController controller,
  ) {
    return DabblerRowGroup(
      header: title,
      children: [
        for (final t in toggles)
          _switchRow(
            context,
            t.title,
            t.subtitle,
            t.icon,
            !t.kinds.any(settings.isKindMuted),
            (value) => controller.setKindsEnabled(t.kinds, value),
          ),
      ],
    );
  }

  Widget _timeRow(
    BuildContext context,
    String label,
    int minutes,
    ValueChanged<int> onPicked,
  ) {
    final colors = DabblerColors.of(context);
    return DabblerInputRow(
      flat: true,
      showDivider: false,
      dense: true,
      title: label,
      leading: DabblerIcon(
        'clock',
        size: DabblerSizing.iconMd,
        color: colors.textSecondary,
      ),
      value: _fmt(context, minutes),
      onTap: () => showDabblerSheet<void>(
        context: context,
        title: label,
        detent: DabblerSheetDetent.content,
        builder: (_) => _QuietTimeSheet(
          initial: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
          onPicked: (t) => onPicked(t.hour * 60 + t.minute),
        ),
      ),
    );
  }

  /// Minutes-since-midnight → localized time string.
  String _fmt(BuildContext context, int minutes) {
    final t = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return t.format(context);
  }

  Widget _switchRow(
    BuildContext context,
    String title,
    String subtitle,
    String icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final colors = DabblerColors.of(context);
    return DabblerInputRow(
      flat: true,
      showDivider: false,
      dense: true,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      leading: DabblerIcon(
        icon,
        size: DabblerSizing.iconMd,
        color: colors.textSecondary,
      ),
      trailing: DabblerToggle(
        checked: value,
        onChanged: onChanged,
        semanticLabel: title,
      ),
    );
  }
}

class _QuietTimeSheet extends StatefulWidget {
  const _QuietTimeSheet({required this.initial, required this.onPicked});

  final TimeOfDay initial;
  final ValueChanged<TimeOfDay> onPicked;

  @override
  State<_QuietTimeSheet> createState() => _QuietTimeSheetState();
}

class _QuietTimeSheetState extends State<_QuietTimeSheet> {
  late TimeOfDay _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return DabblerTimePicker(
      value: _value,
      onChanged: (t) => setState(() => _value = t),
      onConfirm: () {
        widget.onPicked(_value);
        Navigator.pop(context);
      },
      onCancel: () => Navigator.pop(context),
    );
  }
}
