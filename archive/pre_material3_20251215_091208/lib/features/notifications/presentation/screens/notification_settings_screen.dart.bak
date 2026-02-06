import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Game-related notifications
  bool _gameInvites = true;
  bool _gameUpdates = true;
  bool _gameReminders = true;
  bool _gameResults = true;

  // Booking-related notifications
  bool _bookingConfirmations = true;
  bool _bookingReminders = true;
  bool _bookingChanges = true;

  // Social notifications
  bool _friendRequests = true;
  bool _friendActivity = false;
  bool _teamInvites = true;

  // Achievements and rewards
  bool _achievements = true;
  bool _loyaltyPoints = true;
  bool _rewards = true;

  // System notifications
  bool _appUpdates = false;
  bool _maintenanceAlerts = true;
  bool _securityAlerts = true;

  // Notification methods
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;

  // Timing preferences
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '08:00';
  bool _quietHoursEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              context,
              'Notification Methods',
              'Choose how you want to receive notifications',
            ),
            _buildNotificationMethodsSection(),
            const SizedBox(height: 32),

            _buildSectionHeader(
              context,
              'Game Notifications',
              'Stay updated about your games and activities',
            ),
            _buildGameNotificationsSection(),
            const SizedBox(height: 32),

            _buildSectionHeader(
              context,
              'Booking Notifications',
              'Get alerts about your venue bookings',
            ),
            _buildBookingNotificationsSection(),
            const SizedBox(height: 32),

            _buildSectionHeader(
              context,
              'Social Notifications',
              'Connect with friends and teammates',
            ),
            _buildSocialNotificationsSection(),
            const SizedBox(height: 32),

            _buildSectionHeader(
              context,
              'Achievements & Rewards',
              'Celebrate your progress and earn rewards',
            ),
            _buildAchievementsSection(),
            const SizedBox(height: 32),

            _buildSectionHeader(
              context,
              'System Notifications',
              'Important app updates and alerts',
            ),
            _buildSystemNotificationsSection(),
            const SizedBox(height: 32),

            _buildSectionHeader(
              context,
              'Quiet Hours',
              'Pause notifications during specified times',
            ),
            _buildQuietHoursSection(),
            const SizedBox(height: 32),

            _buildTestNotificationButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNotificationMethodsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSwitchTile(
              'Push Notifications',
              'Receive notifications on your device',
              LucideIcons.smartphone,
              _pushNotifications,
              (value) => setState(() => _pushNotifications = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Email Notifications',
              'Get notifications via email',
              LucideIcons.mail,
              _emailNotifications,
              (value) => setState(() => _emailNotifications = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'SMS Notifications',
              'Receive urgent alerts via text message',
              LucideIcons.messageSquare,
              _smsNotifications,
              (value) => setState(() => _smsNotifications = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameNotificationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSwitchTile(
              'Game Invitations',
              'When someone invites you to join a game',
              LucideIcons.userPlus,
              _gameInvites,
              (value) => setState(() => _gameInvites = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Game Updates',
              'Changes to games you\'ve joined',
              LucideIcons.gamepad2,
              _gameUpdates,
              (value) => setState(() => _gameUpdates = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Game Reminders',
              'Reminders before your upcoming games',
              LucideIcons.clock,
              _gameReminders,
              (value) => setState(() => _gameReminders = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Game Results',
              'Results and post-game activities',
              LucideIcons.trophy,
              _gameResults,
              (value) => setState(() => _gameResults = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingNotificationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSwitchTile(
              'Booking Confirmations',
              'When your venue booking is confirmed',
              LucideIcons.checkCircle,
              _bookingConfirmations,
              (value) => setState(() => _bookingConfirmations = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Booking Reminders',
              'Reminders before your booking time',
              LucideIcons.calendar,
              _bookingReminders,
              (value) => setState(() => _bookingReminders = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Booking Changes',
              'Updates to your existing bookings',
              LucideIcons.pencil,
              _bookingChanges,
              (value) => setState(() => _bookingChanges = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialNotificationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSwitchTile(
              'Friend Requests',
              'When someone wants to connect with you',
              LucideIcons.users,
              _friendRequests,
              (value) => setState(() => _friendRequests = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Friend Activity',
              'Updates about your friends\' activities',
              LucideIcons.activity,
              _friendActivity,
              (value) => setState(() => _friendActivity = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Team Invitations',
              'Invitations to join teams',
              LucideIcons.users,
              _teamInvites,
              (value) => setState(() => _teamInvites = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSwitchTile(
              'Achievement Unlocked',
              'When you earn new badges and achievements',
              LucideIcons.award,
              _achievements,
              (value) => setState(() => _achievements = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Loyalty Points',
              'Updates about earned loyalty points',
              LucideIcons.gift,
              _loyaltyPoints,
              (value) => setState(() => _loyaltyPoints = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Rewards Available',
              'When new rewards become available',
              LucideIcons.star,
              _rewards,
              (value) => setState(() => _rewards = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemNotificationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSwitchTile(
              'App Updates',
              'New features and app improvements',
              LucideIcons.download,
              _appUpdates,
              (value) => setState(() => _appUpdates = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Maintenance Alerts',
              'Scheduled maintenance and downtime',
              LucideIcons.wrench,
              _maintenanceAlerts,
              (value) => setState(() => _maintenanceAlerts = value),
            ),
            const Divider(),
            _buildSwitchTile(
              'Security Alerts',
              'Important security and privacy updates',
              LucideIcons.shield,
              _securityAlerts,
              (value) => setState(() => _securityAlerts = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuietHoursSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSwitchTile(
              'Enable Quiet Hours',
              'Pause non-urgent notifications during specified times',
              LucideIcons.moon,
              _quietHoursEnabled,
              (value) => setState(() => _quietHoursEnabled = value),
            ),
            if (_quietHoursEnabled) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Time',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _selectTime(context, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.clock, size: 16),
                                const SizedBox(width: 8),
                                Text(_quietHoursStart),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Time',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _selectTime(context, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.clock, size: 16),
                                const SizedBox(width: 8),
                                Text(_quietHoursEnd),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildTestNotificationButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _sendTestNotification,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.send, size: 16),
            SizedBox(width: 8),
            Text('Send Test Notification'),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(
          (isStartTime ? _quietHoursStart : _quietHoursEnd).split(':')[0],
        ),
        minute: int.parse(
          (isStartTime ? _quietHoursStart : _quietHoursEnd).split(':')[1],
        ),
      ),
    );

    if (picked != null && mounted) {
      final formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStartTime) {
          _quietHoursStart = formattedTime;
        } else {
          _quietHoursEnd = formattedTime;
        }
      });
    }
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💾 Notification settings saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  void _sendTestNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔔 Test notification sent! Check your notifications.'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
