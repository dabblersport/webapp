import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../utils/constants/route_constants.dart';

/// Welcome screen for social onboarding. It has no design frame: it is the
/// design system's flow page with its default parts.
class SocialOnboardingWelcomeScreen extends ConsumerWidget {
  const SocialOnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DabblerFlowPage(
      stepCount: 4,
      stepIndex: 0,
      title: l10n.social_onboarding_welcome_title,
      subtitle: l10n.social_onboarding_welcome_subtitle,
      content: [
        DabblerInputRow(
          leading: const DabblerIconTile.named('user-add'),
          title: l10n.social_onboarding_welcome_find_friends_title,
          subtitle: l10n.social_onboarding_welcome_find_friends_desc,
          flat: true,
        ),
        DabblerInputRow(
          leading: const DabblerIconTile.named('message'),
          title: l10n.social_onboarding_welcome_chat_title,
          subtitle: l10n.social_onboarding_welcome_chat_desc,
          flat: true,
        ),
        DabblerInputRow(
          leading: const DabblerIconTile.named('game'),
          title: l10n.social_onboarding_welcome_game_title,
          subtitle: l10n.social_onboarding_welcome_game_desc,
          flat: true,
          showDivider: false,
        ),
      ],
      primaryLabel: l10n.social_onboarding_welcome_get_started,
      onPrimary: () => context.push(RoutePaths.socialOnboardingFriends),
      secondary: DabblerButton(
        label: l10n.social_onboarding_welcome_skip,
        tone: DabblerButtonTone.text,
        size: DabblerButtonSize.full,
        fullWidth: true,
        // Mark social onboarding as completed and go to main app.
        onPressed: () => context.go(RoutePaths.home),
      ),
    );
  }
}
