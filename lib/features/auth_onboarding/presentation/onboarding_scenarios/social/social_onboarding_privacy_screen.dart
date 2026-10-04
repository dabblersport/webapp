import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../utils/constants/route_constants.dart';

/// Privacy settings introduction screen for social onboarding. It has no
/// design frame: it is the design system's flow page with its default parts.
class SocialOnboardingPrivacyScreen extends StatefulWidget {
  const SocialOnboardingPrivacyScreen({super.key});

  @override
  State<SocialOnboardingPrivacyScreen> createState() =>
      _SocialOnboardingPrivacyScreenState();
}

class _SocialOnboardingPrivacyScreenState
    extends State<SocialOnboardingPrivacyScreen> {
  bool _profileVisibleToFriends = true;
  bool _postsVisibleToPublic = false;
  bool _allowFriendRequests = true;
  bool _allowMessageRequests = true;
  bool _showOnlineStatus = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerFlowPage(
      onBack: () => context.pop(),
      backLabel: l10n.onb_back,
      stepCount: 4,
      stepIndex: 2,
      stepLabel: l10n.social_onboarding_privacy_step,
      title: l10n.social_onboarding_privacy_title,
      subtitle: l10n.social_onboarding_privacy_subtitle,
      content: [
        _option(
          title: l10n.social_onboarding_privacy_profile_visible_title,
          subtitle: l10n.social_onboarding_privacy_profile_visible_subtitle,
          value: _profileVisibleToFriends,
          onChanged: (v) => setState(() => _profileVisibleToFriends = v),
        ),
        _option(
          title: l10n.social_onboarding_privacy_posts_public_title,
          subtitle: l10n.social_onboarding_privacy_posts_public_subtitle,
          value: _postsVisibleToPublic,
          onChanged: (v) => setState(() => _postsVisibleToPublic = v),
        ),
        _option(
          title: l10n.social_onboarding_privacy_allow_requests_title,
          subtitle: l10n.social_onboarding_privacy_allow_requests_subtitle,
          value: _allowFriendRequests,
          onChanged: (v) => setState(() => _allowFriendRequests = v),
        ),
        _option(
          title: l10n.social_onboarding_privacy_allow_messages_title,
          subtitle: l10n.social_onboarding_privacy_allow_messages_subtitle,
          value: _allowMessageRequests,
          onChanged: (v) => setState(() => _allowMessageRequests = v),
        ),
        _option(
          title: l10n.social_onboarding_privacy_online_status_title,
          subtitle: l10n.social_onboarding_privacy_online_status_subtitle,
          value: _showOnlineStatus,
          onChanged: (v) => setState(() => _showOnlineStatus = v),
        ),
      ],
      primaryLabel: l10n.social_onboarding_privacy_continue,
      onPrimary: () => context.push(RoutePaths.socialOnboardingNotifications),
    );
  }

  Widget _option({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return DabblerInputRow.toggle(
      leading: DabblerIcon(value ? 'eye' : 'eye-slash'),
      title: title,
      subtitle: subtitle,
      checked: value,
      onChanged: onChanged,
    );
  }
}
