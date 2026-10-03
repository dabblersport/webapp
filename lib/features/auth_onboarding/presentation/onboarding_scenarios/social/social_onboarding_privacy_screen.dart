import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../../utils/constants/route_constants.dart';

/// Privacy settings introduction screen for social onboarding
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
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Privacy Settings',
        onBack: () => context.pop(),
      ),
      bottomBar: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space8,
          DabblerSpacing.space6,
          DabblerSpacing.space8,
          DabblerSpacing.space8,
        ),
        child: Row(
          children: [
            Expanded(
              child: DabblerButton(
                label: 'Back',
                tone: DabblerButtonTone.outlined,
                size: DabblerButtonSize.full,
                fullWidth: true,
                onPressed: () => context.pop(),
              ),
            ),
            const SizedBox(width: DabblerSpacing.space6),
            Expanded(
              child: DabblerButton(
                label: 'Continue',
                size: DabblerButtonSize.full,
                fullWidth: true,
                onPressed: () {
                  context.push(RoutePaths.socialOnboardingNotifications);
                },
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space8,
          vertical: DabblerSpacing.space6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: DabblerProgressBar(
                    value: 0.75, // 3 out of 4 steps
                    size: DabblerProgressBarSize.sm,
                  ),
                ),
                const SizedBox(width: DabblerSpacing.space4),
                DabblerText(
                  '3 of 4',
                  style: DabblerType.footnote,
                  tone: DabblerTextTone.secondary,
                ),
              ],
            ),
            const SizedBox(height: DabblerSpacing.space10),
            const DabblerIconTile.named(
              'shield-tick',
              size: DabblerSizing.illustrationMd,
            ),
            const SizedBox(height: DabblerSpacing.space8),
            DabblerText('Privacy & Safety', style: DabblerType.title1),
            const SizedBox(height: DabblerSpacing.space4),
            DabblerText(
              'Control who can see your profile and interact with you. You can always change these settings later.',
              tone: DabblerTextTone.secondary,
            ),
            const SizedBox(height: DabblerSpacing.space10),
            Expanded(
              child: ListView(
                children: [
                  _buildPrivacyOption(
                    title: 'Profile Visible to Friends',
                    subtitle: 'Your profile is visible to your friends',
                    value: _profileVisibleToFriends,
                    onChanged: (value) {
                      setState(() {
                        _profileVisibleToFriends = value;
                      });
                    },
                  ),
                  _buildPrivacyOption(
                    title: 'Posts Visible to Public',
                    subtitle: 'Anyone can see your posts',
                    value: _postsVisibleToPublic,
                    onChanged: (value) {
                      setState(() {
                        _postsVisibleToPublic = value;
                      });
                    },
                  ),
                  _buildPrivacyOption(
                    title: 'Allow Friend Requests',
                    subtitle: 'People can send you friend requests',
                    value: _allowFriendRequests,
                    onChanged: (value) {
                      setState(() {
                        _allowFriendRequests = value;
                      });
                    },
                  ),
                  _buildPrivacyOption(
                    title: 'Allow Message Requests',
                    subtitle: 'Non-friends can send you messages',
                    value: _allowMessageRequests,
                    onChanged: (value) {
                      setState(() {
                        _allowMessageRequests = value;
                      });
                    },
                  ),
                  _buildPrivacyOption(
                    title: 'Show Online Status',
                    subtitle: 'Friends can see when you\'re online',
                    value: _showOnlineStatus,
                    onChanged: (value) {
                      setState(() {
                        _showOnlineStatus = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyOption({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = DabblerColors.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space4),
      child: DabblerSurface.card(
        radius: DabblerRadius.lg,
        padding: const EdgeInsetsDirectional.all(DabblerSpacing.space4),
        child: Row(
          children: [
            DabblerIcon(
              value ? 'eye' : 'eye-slash',
              size: DabblerSizing.iconMd,
              color: value ? colors.success.strong : colors.textTertiary,
            ),
            const SizedBox(width: DabblerSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DabblerText(title, style: DabblerType.headline),
                  DabblerText(
                    subtitle,
                    style: DabblerType.footnote,
                    tone: DabblerTextTone.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: DabblerSpacing.space4),
            DabblerToggle(
              checked: value,
              onChanged: onChanged,
              semanticLabel: title,
            ),
          ],
        ),
      ),
    );
  }
}
