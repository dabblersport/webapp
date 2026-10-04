import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/config/notification_preference.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../services/notifications/push_notification_service.dart';
import '../../../../../utils/constants/route_constants.dart';

/// Onboarding step that requests OS push-notification permission. It has no
/// design frame: it is the design system's flow page with its default parts.
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
      granted
          ? NotificationPreference.allow
          : NotificationPreference.remindLater,
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
    await PushNotificationService.instance.saveNotificationPreference(
      NotificationPreference.remindLater,
    );
    if (!mounted) return;
    context.push(RoutePaths.socialOnboardingComplete);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerFlowPage(
      onBack: () => context.pop(),
      backLabel: l10n.onb_back,
      stepCount: 4,
      stepIndex: 3,
      title: 'Stay in the Loop',
      subtitle:
          'Get notified about game invites, friend requests, and activity '
          'from your circles. You can fine-tune what you receive anytime '
          'in Settings.',
      content: const [
        Center(
          child: DabblerIconTile.named(
            'notification-bing',
            size: DabblerSizing.illustrationMd,
          ),
        ),
      ],
      primaryLabel: 'Enable Notifications',
      primaryLoading: _requesting,
      onPrimary: _enableNotifications,
      secondary: DabblerButton(
        label: 'Maybe Later',
        tone: DabblerButtonTone.text,
        size: DabblerButtonSize.full,
        fullWidth: true,
        disabled: _requesting,
        onPressed: _skip,
      ),
    );
  }
}
