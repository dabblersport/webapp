import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder onboarding step while notifications are redesigned.
class SocialOnboardingNotificationsScreen extends StatelessWidget {
  const SocialOnboardingNotificationsScreen({super.key});

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
      body: Padding(
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
              Icons.notifications_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Notifications Paused',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'We\'re rebuilding notification preferences. You can finish onboarding now '
              'and we\'ll add configuration options in a future update.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.push('/social/onboarding/complete'),
              child: const Text('Finish'),
            ),
          ],
        ),
      ),
    );
  }
}
