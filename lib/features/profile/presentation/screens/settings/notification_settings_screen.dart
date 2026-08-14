import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/constants/adaptive_destinations.dart';
import 'package:dabbler/widgets/adaptive_scaffold.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notification_settings_controller.dart';
import 'package:dabbler/features/notifications/presentation/providers/notification_settings_providers.dart';

/// A row in the screen that maps a human label to one or more
/// `notification_kinds.key`s. The toggle is ON when none of [kinds] are muted.
class _KindToggle {
  const _KindToggle(this.title, this.subtitle, this.icon, this.kinds);
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> kinds;
}

/// Screen for managing notification preferences, backed by
/// `public.notification_settings`.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  // ── Category → kind-key mappings (only push-capable kinds) ──────────────

  static const _gameToggles = <_KindToggle>[
    _KindToggle('Game Invites & Requests', 'Invites, join requests, approvals',
        Icons.sports_outlined,
        ['game.invited', 'game.join_request', 'game.join_accepted']),
    _KindToggle('Game Reminders', 'Reminders for upcoming games',
        Icons.alarm_outlined, ['game.reminder']),
    _KindToggle('Game Updates', 'Changes, waitlist promotions, players joining',
        Icons.update_outlined,
        ['game.updated', 'game.waitlist_promoted', 'game.player_joined']),
    _KindToggle('Booking Payments', 'When a booking needs payment',
        Icons.payment_outlined, ['arena.payment_required']),
  ];

  static const _socialToggles = <_KindToggle>[
    _KindToggle('Likes & Reactions', 'Likes and reactions on your content',
        Icons.favorite_outline,
        ['social.post_liked', 'social.post_reacted', 'social.comment_liked']),
    _KindToggle('Comments', 'Comments on your posts', Icons.comment_outlined,
        ['social.post_commented']),
    _KindToggle('Mentions', 'When someone mentions you',
        Icons.alternate_email_outlined,
        ['social.mentioned_in_post', 'social.mentioned_in_comment']),
    _KindToggle('New Followers', 'When someone follows you',
        Icons.person_add_outlined, ['social.followed']),
  ];

  static const _connectionToggles = <_KindToggle>[
    _KindToggle('Friend Requests', 'New and accepted friend requests',
        Icons.group_add_outlined, ['friend.requested', 'friend.accepted']),
    _KindToggle('Squad Invites', 'Invites to join a squad',
        Icons.shield_outlined, ['squad.invited']),
    _KindToggle('Meetup Invites', 'Invites and players joining meetups',
        Icons.groups_outlined, ['meetup.invited', 'meetup.player_joined']),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(notificationSettingsControllerProvider);

    // Surface save/load errors without blocking the UI.
    ref.listen<NotificationSettingsState>(
      notificationSettingsControllerProvider,
      (prev, next) {
        if (next.error != null && next.error != prev?.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update settings: ${next.error}')),
          );
        }
      },
    );

    final content = Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(child: _buildHeader(context)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              sliver: SliverToBoxAdapter(child: _buildHeroCard(context)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              sliver: SliverToBoxAdapter(
                child: _buildBody(context, ref, state),
              ),
            ),
          ],
        ),
      ),
    );

    final width = MediaQuery.of(context).size.width;
    if (width >= AdaptiveBreakpoints.compact) {
      final logoWidget = SvgPicture.asset(
        'assets/images/dabbler_text_logo.svg',
        width: 100,
        height: 18,
        colorFilter: ColorFilter.mode(colorScheme.onSurface, BlendMode.srcIn),
      );
      return AdaptiveScaffold(
        currentIndex: 7,
        destinations: kAdaptiveDestinations,
        onDestinationSelected: (i) =>
            onAdaptiveDestinationSelected(context, i, activeIndex: 7),
        headerWidget: logoWidget,
        body: content,
      );
    }
    return content;
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotificationSettingsState state,
  ) {
    final settings = state.settings;
    if (settings == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final controller = ref.read(notificationSettingsControllerProvider.notifier);
    final pushOn = settings.pushEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGeneralSection(context, settings, controller),
        const SizedBox(height: 20),
        _buildQuietHoursSection(context, settings, controller),
        const SizedBox(height: 20),
        // Per-kind sections only gate push, so dim them when push is off.
        Opacity(
          opacity: pushOn ? 1 : 0.5,
          child: IgnorePointer(
            ignoring: !pushOn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKindSection(
                    context, 'Game Notifications', _gameToggles, settings,
                    controller),
                const SizedBox(height: 20),
                _buildKindSection(
                    context, 'Social Notifications', _socialToggles, settings,
                    controller),
                const SizedBox(height: 20),
                _buildKindSection(context, 'Connections', _connectionToggles,
                    settings, controller),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHigh,
            foregroundColor: colorScheme.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Notifications',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF4A148C) : const Color(0xFFE0C7FF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stay informed',
            style: textTheme.labelLarge?.copyWith(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.black.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage notifications',
            style: textTheme.headlineSmall?.copyWith(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Control how and when you receive notifications about games, social activity, and account updates.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSection(
    BuildContext context,
    NotificationSettings settings,
    NotificationSettingsController controller,
  ) {
    return _buildCard(
      context,
      'General Preferences',
      [
        _buildSwitchItem(
          context,
          'Push Notifications',
          'Receive notifications on this device',
          Icons.notifications_outlined,
          settings.pushEnabled,
          controller.setPushEnabled,
        ),
        const Divider(height: 24),
        _buildSwitchItem(
          context,
          'Email Notifications',
          'Receive notifications via email',
          Icons.email_outlined,
          settings.emailEnabled,
          controller.setEmailEnabled,
        ),
        const Divider(height: 24),
        _buildSwitchItem(
          context,
          'SMS Notifications',
          'Receive important updates via SMS',
          Icons.sms_outlined,
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
    return _buildCard(
      context,
      'Quiet Hours',
      [
        _buildSwitchItem(
          context,
          'Mute during quiet hours',
          enabled
              ? 'No push between ${_fmt(context, settings.quietStartMin!)} and ${_fmt(context, settings.quietEndMin!)}'
              : 'Pause push notifications overnight',
          Icons.bedtime_outlined,
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
          const Divider(height: 24),
          _buildTimeRow(context, 'Start', settings.quietStartMin!,
              (m) => controller.setQuietHours(m, settings.quietEndMin!)),
          const SizedBox(height: 12),
          _buildTimeRow(context, 'End', settings.quietEndMin!,
              (m) => controller.setQuietHours(settings.quietStartMin!, m)),
          const Divider(height: 24),
          _buildSwitchItem(
            context,
            'Allow urgent notifications',
            'High-priority alerts still come through during quiet hours',
            Icons.priority_high_outlined,
            settings.allowHighPriorityOverride,
            controller.setAllowHighPriorityOverride,
          ),
          const Divider(height: 24),
          _buildSwitchItem(
            context,
            'Allow all notifications',
            'Every push still comes through during quiet hours',
            Icons.notifications_active_outlined,
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
    final children = <Widget>[];
    for (var i = 0; i < toggles.length; i++) {
      final t = toggles[i];
      final on = !t.kinds.any(settings.isKindMuted);
      if (i > 0) children.add(const Divider(height: 24));
      children.add(
        _buildSwitchItem(
          context,
          t.title,
          t.subtitle,
          t.icon,
          on,
          (value) => controller.setKindsEnabled(t.kinds, value),
        ),
      );
    }
    return _buildCard(context, title, children);
  }

  Widget _buildCard(BuildContext context, String title, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRow(
    BuildContext context,
    String label,
    int minutes,
    ValueChanged<int> onPicked,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(label, style: textTheme.bodyLarge),
        ),
        TextButton(
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
            );
            if (picked != null) {
              onPicked(picked.hour * 60 + picked.minute);
            }
          },
          style: TextButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurface,
          ),
          child: Text(_fmt(context, minutes)),
        ),
      ],
    );
  }

  /// Minutes-since-midnight → localized time string.
  String _fmt(BuildContext context, int minutes) {
    final t = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return t.format(context);
  }

  Widget _buildSwitchItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
