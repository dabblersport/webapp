import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../utils/constants/route_constants.dart';

/// Find friends screen for social onboarding. It has no design frame: it is
/// the design system's flow page with its default parts.
class SocialOnboardingFriendsScreen extends ConsumerStatefulWidget {
  const SocialOnboardingFriendsScreen({super.key});

  @override
  ConsumerState<SocialOnboardingFriendsScreen> createState() =>
      _SocialOnboardingFriendsScreenState();
}

class _SocialOnboardingFriendsScreenState
    extends ConsumerState<SocialOnboardingFriendsScreen> {
  final List<_ContactSuggestion> _suggestions = [];

  void _toggleSelection(int index) {
    setState(() {
      _suggestions[index].isSelected = !_suggestions[index].isSelected;
    });
  }

  void _continue() {
    // Continue to next step
    context.push(RoutePaths.socialOnboardingPrivacy);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedCount = _suggestions.where((s) => s.isSelected).length;

    return DabblerFlowPage(
      onBack: () => context.pop(),
      backLabel: l10n.onb_back,
      stepCount: 4,
      stepIndex: 1,
      title: l10n.social_onboarding_friends_title,
      subtitle: l10n.social_onboarding_friends_subtitle,
      content: [
        DabblerSection(
          title: l10n.social_onboarding_friends_suggested,
          action: selectedCount > 0
              ? DabblerBadge(
                  label: l10n.social_onboarding_friends_selected(selectedCount),
                )
              : null,
          children: _suggestions.isEmpty
              ? [
                  DabblerText(
                    'Friend suggestions are coming soon.',
                    style: DabblerType.subheadline,
                    tone: DabblerTextTone.secondary,
                    textAlign: TextAlign.center,
                  ),
                ]
              : [
                  for (var i = 0; i < _suggestions.length; i++)
                    _suggestionRow(l10n, _suggestions[i], i),
                ],
        ),
      ],
      primaryLabel: selectedCount > 0
          ? (selectedCount > 1
                ? l10n.social_onboarding_friends_send_requests(selectedCount)
                : l10n.social_onboarding_friends_send_request)
          : l10n.social_onboarding_friends_continue,
      onPrimary: _continue,
      secondary: DabblerButton(
        label: l10n.social_onboarding_friends_skip,
        tone: DabblerButtonTone.text,
        size: DabblerButtonSize.full,
        fullWidth: true,
        onPressed: () => context.push(RoutePaths.socialOnboardingPrivacy),
      ),
    );
  }

  Widget _suggestionRow(
    AppLocalizations l10n,
    _ContactSuggestion suggestion,
    int index,
  ) {
    final mutual = suggestion.mutualFriends;
    return DabblerInputRow(
      leading: DabblerAvatar(
        seed: suggestion.name,
        imageUrl: suggestion.avatar,
      ),
      title: suggestion.name,
      subtitle: mutual > 0
          ? (mutual > 1
                ? l10n.social_onboarding_friends_mutual_many(mutual)
                : l10n.social_onboarding_friends_mutual_one(mutual))
          : suggestion.source,
      onTap: () => _toggleSelection(index),
      trailing: suggestion.isSelected
          ? DabblerBadge(
              label: l10n.social_onboarding_friends_added,
              tone: DabblerBadgeTone.success,
              icon: const DabblerIcon(
                'tick-circle',
                size: DabblerSizing.iconInline,
              ),
            )
          : DabblerButton(
              label: l10n.social_onboarding_friends_add_btn,
              size: DabblerButtonSize.small,
              onPressed: () => _toggleSelection(index),
            ),
    );
  }
}

class _ContactSuggestion {
  final String name;
  final String avatar;
  final int mutualFriends;
  final String source;
  bool isSelected;

  _ContactSuggestion({
    required this.name,
    required this.avatar,
    required this.mutualFriends,
    required this.source,
    required this.isSelected,
  });
}
