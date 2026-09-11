import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/config/notification_preference.dart';
import '../../../../../services/notifications/push_notification_service.dart';
import '../../../../../utils/constants/route_constants.dart';

/// Onboarding step that requests OS push-notification permission.
class SocialOnboardingNotificationsScreen extends StatefulWidget {
  const SocialOnboardingNotificationsScreen({super.key});

  @override
  State<SocialOnboardingNotificationsScreen> createState() =>
      _SocialOnboardingNotificationsScreenState();
}

class _SocialOnboardingNotificationsScreenState
    extends State<SocialOnboardingNotificationsScreen> {
  bool _requesting = false;

  Future<void> _enableNotifications() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    final service = PushNotificationService.instance;
    final granted = await service.requestNotificationPermission();
    await service.saveNotificationPreference(
      granted ? NotificationPreference.allow : NotificationPreference.remindLater,
    );

    if (!mounted) return;
    setState(() => _requesting = false);
    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications enabled')),
      );
    }
    context.push(RoutePaths.socialOnboardingComplete);
  }

  Future<void> _skip() async {
    await PushNotificationService.instance
        .saveNotificationPreference(NotificationPreference.remindLater);
    if (!mounted) return;
    context.push(RoutePaths.socialOnboardingComplete);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: 1,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 32),
            Icon(
              Icons.notifications_active_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Stay in the Loop',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Get notified about game invites, friend requests, and activity '
              'from your circles. You can fine-tune what you receive anytime '
              'in Settings.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _requesting ? null : _enableNotifications,
              child: _requesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enable Notifications'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _requesting ? null : _skip,
              child: const Text('Maybe Later'),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}
