import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
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
      DabblerToastProvider.of(context).show(
        const DabblerToastSpec(
          message: 'Notifications enabled',
          tone: DabblerToastTone.success,
        ),
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
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Notifications',
        onBack: () => context.pop(),
      ),
      bottomBar: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space8,
          DabblerSpacing.space6,
          DabblerSpacing.space8,
          DabblerSpacing.space8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DabblerButton(
              label: 'Enable Notifications',
              size: DabblerButtonSize.full,
              fullWidth: true,
              loading: _requesting,
              onPressed: _enableNotifications,
            ),
            const SizedBox(height: DabblerSpacing.space3),
            DabblerButton(
              label: 'Maybe Later',
              tone: DabblerButtonTone.text,
              size: DabblerButtonSize.full,
              fullWidth: true,
              disabled: _requesting,
              onPressed: _skip,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space8,
          vertical: DabblerSpacing.space6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DabblerProgressBar(
              value: 1,
              size: DabblerProgressBarSize.sm,
            ),
            const SizedBox(height: DabblerSpacing.space10),
            const Center(
              child: DabblerIconTile.named('notification-bing', size: 64),
            ),
            const SizedBox(height: DabblerSpacing.space8),
            Text(
              'Stay in the Loop',
              textAlign: TextAlign.center,
              style: DabblerType.title1
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DabblerSpacing.space4),
            Text(
              'Get notified about game invites, friend requests, and activity '
              'from your circles. You can fine-tune what you receive anytime '
              'in Settings.',
              textAlign: TextAlign.center,
              style: DabblerType.body
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
