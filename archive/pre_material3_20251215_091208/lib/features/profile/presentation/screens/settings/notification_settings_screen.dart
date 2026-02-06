import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Screen for managing notification preferences
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  // Notification preferences
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;

  // Game notifications
  bool _gameInvites = true;
  bool _gameReminders = true;
  bool _gameCancellations = true;
  bool _gameUpdates = true;

  // Social notifications
  bool _newFollowers = true;
  bool _friendRequests = true;
  bool _messages = true;
  bool _comments = true;

  // System notifications
  bool _accountActivity = true;
  bool _promotions = false;
  bool _newsletter = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Header
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(child: _buildHeader(context)),
            ),
            // Hero Card
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              sliver: SliverToBoxAdapter(child: _buildHeroCard(context)),
            ),
            // Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGeneralSection(),
                    const SizedBox(height: 20),
                    _buildGameNotificationsSection(),
                    const SizedBox(height: 20),
                    _buildSocialNotificationsSection(),
                    const SizedBox(height: 20),
                    _buildSystemNotificationsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
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
                  ? Colors.white.withOpacity(0.8)
                  : Colors.black.withOpacity(0.7),
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
              color: colorScheme.onPrimary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSection() {
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
              'General Preferences',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchItem(
              context,
              'Push Notifications',
              'Receive notifications on this device',
              Icons.notifications_outlined,
              _pushNotifications,
              (value) => setState(() => _pushNotifications = value),
            ),
            const Divider(height: 24),
            _buildSwitchItem(
              context,
              'Email Notifications',
              'Receive notifications via email',
              Icons.email_outlined,
              _emailNotifications,
              (value) => setState(() => _emailNotifications = value),
            ),
            const Divider(height: 24),
            _buildSwitchItem(
              context,
              'SMS Notifications',
              'Receive important updates via SMS',
              Icons.sms_outlined,
              _smsNotifications,
              (value) => setState(() => _smsNotifications = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameNotificationsSection() {
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
              'Game Notifications',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchItem(
              context,
              'Game Invites',
              'When someone invites you to a game',
              Icons.sports_outlined,
              _gameInvites,
              (value) => setState(() => _gameInvites = value),
            ),
            const Divider(height: 24),
            _buildSwitchItem(
              context,
              'Game Reminders',
              'Reminders for upcoming games',
              Icons.alarm_outlined,
              _gameReminders,
              (value) => setState(() => _gameReminders = value),
            ),
            const Divider(height: 24),
            _buildSwitchItem(
              context,
              'Game Cancellations',
              'When a game is cancelled',
              Icons.cancel_outlined,
              _gameCancellations,
              (value) => setState(() => _gameCancellations = value),
            ),
            const Divider(height: 24),
            _buildSwitchItem(
              context,
              'Game Updates',
              'Changes to game details',
              Icons.update_outlined,
              _gameUpdates,
              (value) => setState(() => _gameUpdates = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialNotificationsSection() {
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
              'Social Notifications',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchItem(
              context,
              'New Followers',
              'When someone follows you',
              Icons.person_add_outlined,
              _newFollowers,
              (value) => setState(() => _newFollowers = value),
            ),
            const Divider(height: 24),
            _buildSwitchItem(
              context,
              'Friend Requests',
              'New friend requests',
              Icons.group_add_outlined,
              _friendRequests,
              (value) => setState(() => _friendRequests = value),
            ),
            const Divider(height: 24),
            _buildSwitchItem(
              context,
              'Messages',
              'New direct messages',
              Icons.message_outlined,
              _messages,
              (value) => setState(() => _messages = value),
            ),
            const Divider(height: 24),
            _buildSwitchItem(
              context,
              'Comments',
              'Comments on your posts',
              Icons.comment_outlined,
              _comments,
              (value) => setState(() => _comments = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemNotificationsSection() {
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
              'System Notifications',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchItem(
              context,
              'Account Activity',
              'Important account updates',
              Icons.security_outlined,
              _accountActivity,
              (value) => setState(() => _accountActivity = value),
            ),
            const Divider(height: 24),
            _buildSwitchItem(
              context,
              'Promotions',
              'Special offers and promotions',
              Icons.local_offer_outlined,
              _promotions,
              (value) => setState(() => _promotions = value),
            ),
            const Divider(height: 24),
            _buildSwitchItem(
              context,
              'Newsletter',
              'Weekly newsletter updates',
              Icons.newspaper_outlined,
              _newsletter,
              (value) => setState(() => _newsletter = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.5),
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
                  color: colorScheme.onSurface.withOpacity(0.6),
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
