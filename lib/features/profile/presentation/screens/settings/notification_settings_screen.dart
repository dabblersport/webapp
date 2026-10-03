import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
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
  const NotificationSettingsScreen({super.key});

  // ── Category → kind-key mappings (only push-capable kinds) ──────────────

  static const _gameToggles = <_KindToggle>[
    _KindToggle('Game Invites & Requests', 'Invites, join requests, approvals',
        'game', ['game.invited', 'game.join_request', 'game.join_accepted']),
    _KindToggle('Game Reminders', 'Reminders for upcoming games', 'alarm',
        ['game.reminder']),
    _KindToggle('Game Updates', 'Changes, waitlist promotions, players joining',
        'refresh-circle',
        ['game.updated', 'game.waitlist_promoted', 'game.player_joined']),
    _KindToggle('Booking Payments', 'When a booking needs payment', 'card',
        ['arena.payment_required']),
  ];

  static const _socialToggles = <_KindToggle>[
    _KindToggle('Likes & Reactions', 'Likes and reactions on your content',
        'heart',
        ['social.post_liked', 'social.post_reacted', 'social.comment_liked']),
    _KindToggle('Comments', 'Comments on your posts', 'message-text',
        ['social.post_commented']),
    _KindToggle('Mentions', 'When someone mentions you', 'tag-user',
        ['social.mentioned_in_post', 'social.mentioned_in_comment']),
    _KindToggle('New Followers', 'When someone follows you', 'user-add',
        ['social.followed']),
  ];

  static const _connectionToggles = <_KindToggle>[
    _KindToggle('Friend Requests', 'New and accepted friend requests',
        'profile-add', ['friend.requested', 'friend.accepted']),
    _KindToggle('Squad Invites', 'Invites to join a squad', 'shield-tick',
        ['squad.invited']),
    _KindToggle('Meetup Invites', 'Invites and players joining meetups',
        'people', ['meetup.invited', 'meetup.player_joined']),
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
              message: 'Could not update settings: ${next.error}',
              tone: DabblerToastTone.error,
            ),
          );
        }
      },
    );

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Notifications',
        onBack: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DabblerSpacing.space6,
          DabblerSpacing.space4,
          DabblerSpacing.space6,
          DabblerSpacing.space11,
        ),
        children: [
          _buildHero(context),
          const SizedBox(height: DabblerSpacing.space7),
          _buildBody(context, ref, state),
        ],
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

    final controller = ref.read(notificationSettingsControllerProvider.notifier);
    final pushOn = settings.pushEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGeneralSection(context, settings, controller),
        const SizedBox(height: DabblerSpacing.space7),
        _buildQuietHoursSection(context, settings, controller),
        const SizedBox(height: DabblerSpacing.space7),
        // Per-kind sections only gate push, so dim them when push is off.
        Opacity(
          opacity: pushOn ? 1 : 0.5,
          child: IgnorePointer(
            ignoring: !pushOn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildKindSection(context, 'Game Notifications', _gameToggles,
                    settings, controller),
                const SizedBox(height: DabblerSpacing.space7),
                _buildKindSection(context, 'Social Notifications',
                    _socialToggles, settings, controller),
                const SizedBox(height: DabblerSpacing.space7),
                _buildKindSection(context, 'Connections', _connectionToggles,
                    settings, controller),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(BuildContext context) {
    final colors = DabblerColors.of(context);
    final dir = Directionality.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Stay informed',
          style: DabblerType.footnote
              .resolveForDirection(dir)
              .copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: DabblerSpacing.space2),
        const DabblerBanner(
          tone: DabblerBannerTone.neutral,
          title: 'Manage notifications',
          message:
              'Control how and when you receive notifications about games, social activity, and account updates.',
        ),
      ],
    );
  }

  Widget _buildGeneralSection(
    BuildContext context,
    NotificationSettings settings,
    NotificationSettingsController controller,
  ) {
    return DabblerSection(
      title: 'General Preferences',
      children: [
        _switchRow(context, 'Push Notifications',
            'Receive notifications on this device', 'notification',
            settings.pushEnabled, controller.setPushEnabled),
        _switchRow(context, 'Email Notifications',
            'Receive notifications via email', 'sms', settings.emailEnabled,
            controller.setEmailEnabled),
        _switchRow(context, 'SMS Notifications',
            'Receive important updates via SMS', 'message', settings.smsEnabled,
            controller.setSmsEnabled),
      ],
    );
  }

  Widget _buildQuietHoursSection(
    BuildContext context,
    NotificationSettings settings,
    NotificationSettingsController controller,
  ) {
    final enabled = settings.hasQuietHours;
    return DabblerSection(
      title: 'Quiet Hours',
      children: [
        _switchRow(
          context,
          'Mute during quiet hours',
          enabled
              ? 'No push between ${_fmt(context, settings.quietStartMin!)} and ${_fmt(context, settings.quietEndMin!)}'
              : 'Pause push notifications overnight',
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
          _timeRow(context, 'Start', settings.quietStartMin!,
              (m) => controller.setQuietHours(m, settings.quietEndMin!)),
          _timeRow(context, 'End', settings.quietEndMin!,
              (m) => controller.setQuietHours(settings.quietStartMin!, m)),
          _switchRow(
            context,
            'Allow urgent notifications',
            'High-priority alerts still come through during quiet hours',
            'danger',
            settings.allowHighPriorityOverride,
            controller.setAllowHighPriorityOverride,
          ),
          _switchRow(
            context,
            'Allow all notifications',
            'Every push still comes through during quiet hours',
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
    return DabblerSection(
      title: title,
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
      title: label,
      leading: DabblerIcon('clock', size: DabblerSizing.iconMd, color: colors.textSecondary),
      trailing: Text(
        _fmt(context, minutes),
        style: DabblerType.callout
            .resolveForDirection(Directionality.of(context))
            .copyWith(color: colors.textSecondary),
      ),
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
      title: title,
      subtitle: subtitle,
      leading: DabblerIcon(icon, size: DabblerSizing.iconMd, color: colors.textSecondary),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DabblerSpacing.space6),
      child: DabblerTimePicker(
        value: _value,
        onChanged: (t) => setState(() => _value = t),
        onConfirm: () {
          widget.onPicked(_value);
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }
}
