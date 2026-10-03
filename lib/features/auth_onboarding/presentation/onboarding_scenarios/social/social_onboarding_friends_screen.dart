import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../utils/constants/route_constants.dart';

/// Find friends screen for social onboarding
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
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    final selectedCount = _suggestions.where((s) => s.isSelected).length;

    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Find Friends',
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
              label: selectedCount > 0
                  ? 'Send ${selectedCount > 1 ? "$selectedCount Requests" : "Request"} & Continue'
                  : 'Continue',
              size: DabblerButtonSize.full,
              fullWidth: true,
              onPressed: _continue,
            ),
            const SizedBox(height: DabblerSpacing.space4),
            DabblerButton(
              label: 'Skip',
              tone: DabblerButtonTone.text,
              size: DabblerButtonSize.full,
              fullWidth: true,
              onPressed: () =>
                  context.push(RoutePaths.socialOnboardingPrivacy),
            ),
            const SizedBox(height: DabblerSpacing.space4),
            const DabblerProgressBar(
              value: 0.5,
              size: DabblerProgressBarSize.sm,
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
            Text(
              'Find Your Sports Community',
              style: DabblerType.title1
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DabblerSpacing.space3),
            Text(
              'Connect with friends to share game experiences and discover new opportunities.',
              style: DabblerType.subheadline
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: DabblerSpacing.space10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Suggested for You',
                    style: DabblerType.headline
                        .resolveForDirection(direction)
                        .copyWith(color: colors.textPrimary),
                  ),
                ),
                if (selectedCount > 0)
                  DabblerBadge(label: '$selectedCount selected'),
              ],
            ),
            const SizedBox(height: DabblerSpacing.space5),
            Expanded(
              child: _suggestions.isEmpty
                  ? Center(
                      child: Text(
                        'Friend suggestions are coming soon.',
                        textAlign: TextAlign.center,
                        style: DabblerType.subheadline
                            .resolveForDirection(direction)
                            .copyWith(color: colors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return _buildFriendSuggestionCard(suggestion, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendSuggestionCard(_ContactSuggestion suggestion, int index) {
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: DabblerSpacing.space1,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleSelection(index),
        child: DabblerSurface.card(
          radius: DabblerRadius.lg,
          padding: const EdgeInsetsDirectional.all(DabblerSpacing.space4),
          child: Row(
            children: [
              DabblerAvatar(seed: suggestion.name, imageUrl: suggestion.avatar),
              const SizedBox(width: DabblerSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.name,
                      style: DabblerType.headline
                          .resolveForDirection(direction)
                          .copyWith(color: colors.textPrimary),
                    ),
                    if (suggestion.mutualFriends > 0)
                      Text(
                        '${suggestion.mutualFriends} mutual friend${suggestion.mutualFriends > 1 ? 's' : ''}',
                        style: DabblerType.footnote
                            .resolveForDirection(direction)
                            .copyWith(color: colors.textSecondary),
                      ),
                    const SizedBox(height: DabblerSpacing.space1),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DabblerBadge(label: suggestion.source),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DabblerSpacing.space4),
              if (suggestion.isSelected)
                const DabblerBadge(
                  label: 'Added',
                  tone: DabblerBadgeTone.success,
                  icon: DabblerIcon('tick-circle', size: 14),
                )
              else
                DabblerButton(
                  label: 'Add',
                  size: DabblerButtonSize.small,
                  onPressed: () => _toggleSelection(index),
                ),
            ],
          ),
        ),
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
