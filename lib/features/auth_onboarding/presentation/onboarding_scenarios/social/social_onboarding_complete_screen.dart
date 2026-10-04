import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../utils/constants/route_constants.dart';

/// Completion screen for social onboarding. It has no design frame: it is
/// the design system's flow page with its default parts.
class SocialOnboardingCompleteScreen extends StatelessWidget {
  const SocialOnboardingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DabblerFlowPage(
      title: l10n.social_onboarding_complete_title,
      subtitle: l10n.social_onboarding_complete_subtitle,
      content: [
        DabblerInputRow(
          leading: const DabblerIconTile.named('people'),
          title: l10n.social_onboarding_complete_connect_title,
          subtitle: l10n.social_onboarding_complete_connect_desc,
          flat: true,
        ),
        DabblerInputRow(
          leading: const DabblerIconTile.named('message'),
          title: l10n.social_onboarding_complete_share_title,
          subtitle: l10n.social_onboarding_complete_share_desc,
          flat: true,
        ),
        DabblerInputRow(
          leading: const DabblerIconTile.named('game'),
          title: l10n.social_onboarding_complete_discover_title,
          subtitle: l10n.social_onboarding_complete_discover_desc,
          flat: true,
          showDivider: false,
        ),
      ],
      primaryLabel: l10n.social_onboarding_complete_explore_btn,
      // Navigate to main app with social/community tab selected.
      onPrimary: () => context.go(RoutePaths.community),
      secondary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DabblerButton(
            label: l10n.social_onboarding_complete_home_btn,
            tone: DabblerButtonTone.outlined,
            size: DabblerButtonSize.full,
            fullWidth: true,
            onPressed: () => context.go(RoutePaths.home),
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          DabblerButton(
            label: l10n.social_onboarding_complete_later,
            tone: DabblerButtonTone.text,
            size: DabblerButtonSize.full,
            fullWidth: true,
            onPressed: () => context.go(RoutePaths.home),
          ),
        ],
      ),
    );
  }
}
