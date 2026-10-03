import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../../utils/constants/route_constants.dart';

/// Completion screen for social onboarding
class SocialOnboardingCompleteScreen extends StatelessWidget {
  const SocialOnboardingCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              label: 'Explore Social',
              size: DabblerButtonSize.full,
              fullWidth: true,
              onPressed: () {
                // Navigate to main app with social/community tab selected
                context.go(RoutePaths.community);
              },
            ),
            const SizedBox(height: DabblerSpacing.space4),
            DabblerButton(
              label: 'Go to Home',
              tone: DabblerButtonTone.outlined,
              size: DabblerButtonSize.full,
              fullWidth: true,
              onPressed: () {
                // Navigate to main app with home tab
                context.go(RoutePaths.home);
              },
            ),
            const SizedBox(height: DabblerSpacing.space3),
            DabblerButton(
              label: 'I\'ll explore later',
              tone: DabblerButtonTone.text,
              size: DabblerButtonSize.full,
              fullWidth: true,
              onPressed: () {
                context.go(RoutePaths.home);
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space8,
          vertical: DabblerSpacing.space10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: DabblerIconTile.named(
                'tick-circle',
                tone: DabblerIconTileTone.brand,
                size: 96,
              ),
            ),
            const SizedBox(height: DabblerSpacing.space10),
            Text(
              'Welcome to Social!',
              textAlign: TextAlign.center,
              style: DabblerType.title1
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: DabblerSpacing.space5),
            Text(
              'You\'re all set up! Start connecting with friends, sharing your game experiences, and discovering new players in your area.',
              textAlign: TextAlign.center,
              style: DabblerType.body
                  .resolveForDirection(direction)
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: DabblerSpacing.space10),
            DabblerSurface.card(
              radius: DabblerRadius.lg,
              padding: const EdgeInsetsDirectional.all(DabblerSpacing.space5),
              child: Column(
                children: [
                  _feature(
                    context,
                    icon: 'people',
                    title: 'Connect with Players',
                    description:
                        'Find and add friends who love the same sports',
                  ),
                  const SizedBox(height: DabblerSpacing.space5),
                  _feature(
                    context,
                    icon: 'message',
                    title: 'Share Your Journey',
                    description:
                        'Post updates, photos, and celebrate your wins',
                  ),
                  const SizedBox(height: DabblerSpacing.space5),
                  _feature(
                    context,
                    icon: 'game',
                    title: 'Discover Games',
                    description: 'See what games your friends are playing',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature(
    BuildContext context, {
    required String icon,
    required String title,
    required String description,
  }) {
    final colors = DabblerColors.of(context);
    final direction = Directionality.of(context);
    return Row(
      children: [
        DabblerIconTile.named(icon),
        const SizedBox(width: DabblerSpacing.space5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: DabblerType.headline
                    .resolveForDirection(direction)
                    .copyWith(color: colors.textPrimary),
              ),
              Text(
                description,
                style: DabblerType.footnote
                    .resolveForDirection(direction)
                    .copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
