import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../utils/constants/route_constants.dart';

/// Welcome screen for social onboarding
class SocialOnboardingWelcomeScreen extends ConsumerWidget {
  const SocialOnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);

    return DabblerPage(
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
              label: 'Get Started',
              size: DabblerButtonSize.full,
              fullWidth: true,
              onPressed: () => context.push(RoutePaths.socialOnboardingFriends),
            ),
            const SizedBox(height: DabblerSpacing.space6),
            const DabblerProgressBar(
              value: 0.25,
              size: DabblerProgressBarSize.sm,
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
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DabblerButton(
                label: 'Skip',
                tone: DabblerButtonTone.text,
                size: DabblerButtonSize.small,
                onPressed: () => _skipOnboarding(context),
              ),
            ),
            const SizedBox(height: DabblerSpacing.space10),
            const Center(child: DabblerIconTile.named('people', size: 96)),
            const SizedBox(height: DabblerSpacing.space10),
            Text(
              'Welcome to Social',
              textAlign: TextAlign.center,
              style: DabblerType.title1
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DabblerSpacing.space5),
            Text(
              'Connect with fellow players, share your game experiences, and build your sports community.',
              textAlign: TextAlign.center,
              style: DabblerType.body
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: DabblerSpacing.space11),
            _buildFeaturesList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList(BuildContext context) {
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    const features = [
      _FeatureItem(
        icon: 'user-add',
        title: 'Find Friends',
        description: 'Connect with players in your area',
      ),
      _FeatureItem(
        icon: 'message',
        title: 'Chat & Share',
        description: 'Message friends and share game moments',
      ),
      _FeatureItem(
        icon: 'game',
        title: 'Game Together',
        description: 'Discover and join games with your network',
      ),
    ];

    return Column(
      children: [
        for (final feature in features)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: DabblerSpacing.space3,
            ),
            child: Row(
              children: [
                DabblerIconTile.named(feature.icon),
                const SizedBox(width: DabblerSpacing.space5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.title,
                        style: DabblerType.headline
                            .resolveForDirection(direction)
                            .copyWith(color: colors.textPrimary),
                      ),
                      const SizedBox(height: DabblerSpacing.space1),
                      Text(
                        feature.description,
                        style: DabblerType.footnote
                            .resolveForDirection(direction)
                            .copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _skipOnboarding(BuildContext context) {
    // Mark social onboarding as completed and go to main app
    context.go(RoutePaths.home);
  }
}

class _FeatureItem {
  final String icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
