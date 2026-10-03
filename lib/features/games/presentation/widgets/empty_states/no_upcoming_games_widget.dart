import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Empty state widget when user has no upcoming games
class NoUpcomingGamesWidget extends StatelessWidget {
  final VoidCallback? onCreateGame;
  final VoidCallback? onBrowseGames;
  final VoidCallback? onJoinedGames;
  final VoidCallback? onPastGames;
  final bool hasJoinedGames;
  final bool hasPastGames;

  const NoUpcomingGamesWidget({
    super.key,
    this.onCreateGame,
    this.onBrowseGames,
    this.onJoinedGames,
    this.onPastGames,
    this.hasJoinedGames = false,
    this.hasPastGames = false,
  });

  @override
  Widget build(BuildContext context) {
    final DabblerColors colors = DabblerColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DabblerIconTile.named(
              'calendar-tick',
              size: DabblerSizing.illustrationMd,
            ),

            const SizedBox(height: DabblerSpacing.space8),

            // Title
            DabblerText(
              'No upcoming games',
              style: DabblerType.headline,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: DabblerSpacing.space4),

            // Message
            DabblerText(
              'You don\'t have any games scheduled. Start playing by creating your own game or joining one nearby!',
              style: DabblerType.body,
              tone: DabblerTextTone.secondary,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: DabblerSpacing.space10),

            // Primary action - Create game
            DabblerButton(
              label: 'Create Your First Game',
              icon: 'add',
              fullWidth: true,
              onPressed: onCreateGame,
            ),

            const SizedBox(height: DabblerSpacing.space4),

            // Secondary action - Browse games
            DabblerButton(
              label: 'Browse Games to Join',
              icon: 'search-normal',
              tone: DabblerButtonTone.outlined,
              fullWidth: true,
              onPressed: onBrowseGames,
            ),

            const SizedBox(height: DabblerSpacing.space8),

            // Additional navigation options if available
            if (hasJoinedGames || hasPastGames) ...[
              DabblerText(
                'Or check your other games:',
                style: DabblerType.footnote,
                tone: DabblerTextTone.secondary,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: DabblerSpacing.space5),

              Row(
                children: [
                  if (hasJoinedGames) ...[
                    Expanded(
                      child: DabblerButton(
                        label: 'Joined Games',
                        icon: 'people',
                        tone: DabblerButtonTone.text,
                        onPressed: onJoinedGames,
                      ),
                    ),
                  ],

                  if (hasJoinedGames && hasPastGames)
                    const SizedBox(width: DabblerSpacing.space2),

                  if (hasPastGames) ...[
                    Expanded(
                      child: DabblerButton(
                        label: 'Past Games',
                        icon: 'clock',
                        tone: DabblerButtonTone.text,
                        onPressed: onPastGames,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: DabblerSpacing.space8),

            // Help text with tips
            DabblerSurface.sunken(
              padding: const EdgeInsets.all(DabblerSpacing.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DabblerIcon(
                        'lamp-on',
                        size: DabblerSizing.iconRow,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: DabblerSpacing.space2),
                      DabblerText(
                        'Pro Tips',
                        style: DabblerType.subheadline,
                        weight: DabblerTextWeight.semibold,
                        tone: DabblerTextTone.secondary,
                      ),
                    ],
                  ),

                  const SizedBox(height: DabblerSpacing.space2),

                  DabblerText(
                    '• Create games in advance to give players time to join\n'
                    '• Set up recurring games for regular play sessions\n'
                    '• Join games early - popular ones fill up fast!',
                    style: DabblerType.footnote,
                    tone: DabblerTextTone.secondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for first-time user experience with extra onboarding
class FirstTimeUserGamesWidget extends StatelessWidget {
  final VoidCallback? onCreateGame;
  final VoidCallback? onBrowseGames;
  final VoidCallback? onViewTutorial;

  const FirstTimeUserGamesWidget({
    super.key,
    this.onCreateGame,
    this.onBrowseGames,
    this.onViewTutorial,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DabblerSpacing.space10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Welcome mark (a flat brand tile; the old gradient is not in the
            // design system).
            const DabblerIconTile.named(
              'game',
              weight: DabblerIconWeight.bold,
              size: DabblerSizing.illustrationMd,
            ),

            const SizedBox(height: DabblerSpacing.space8),

            // Welcome title
            DabblerText(
              'Welcome to Dabbler!',
              style: DabblerType.headline,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: DabblerSpacing.space4),

            // Welcome message
            DabblerText(
              'Ready to get in the game? Create your first game or join one nearby to start connecting with other players!',
              style: DabblerType.body,
              tone: DabblerTextTone.secondary,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: DabblerSpacing.space10),

            // Primary CTA - Create game
            DabblerButton(
              label: 'Create Your First Game',
              icon: 'add',
              fullWidth: true,
              onPressed: onCreateGame,
            ),

            const SizedBox(height: DabblerSpacing.space4),

            // Secondary CTA - Browse games
            DabblerButton(
              label: 'Explore Games Near You',
              icon: 'discover',
              tone: DabblerButtonTone.outlined,
              fullWidth: true,
              onPressed: onBrowseGames,
            ),

            const SizedBox(height: DabblerSpacing.space4),

            // Tutorial link
            DabblerButton(
              label: 'How does it work?',
              icon: 'info-circle',
              tone: DabblerButtonTone.text,
              onPressed: onViewTutorial,
            ),

            const SizedBox(height: DabblerSpacing.space10),

            // Feature highlights
            DabblerSurface.sunken(
              padding: const EdgeInsets.all(DabblerSpacing.space6),
              child: Column(
                children: [
                  DabblerText('What you can do:', style: DabblerType.headline),

                  const SizedBox(height: DabblerSpacing.space5),

                  _buildFeatureItem(
                    context,
                    'calendar',
                    'Create Games',
                    'Organize pickup games at your favorite venues',
                  ),

                  const SizedBox(height: DabblerSpacing.space4),

                  _buildFeatureItem(
                    context,
                    'user-add',
                    'Join Players',
                    'Find and connect with players in your area',
                  ),

                  const SizedBox(height: DabblerSpacing.space4),

                  _buildFeatureItem(
                    context,
                    'building-3',
                    'Discover Venues',
                    'Find courts, fields, and facilities nearby',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    String icon,
    String title,
    String description,
  ) {
    return Row(
      children: [
        DabblerIconTile.named(icon),

        const SizedBox(width: DabblerSpacing.space4),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DabblerText(
                title,
                style: DabblerType.subheadline,
                weight: DabblerTextWeight.semibold,
              ),
              DabblerText(
                description,
                style: DabblerType.footnote,
                tone: DabblerTextTone.secondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
