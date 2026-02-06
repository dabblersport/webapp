import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              'No upcoming games',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Message
            Text(
              'You don\'t have any games scheduled. Start playing by creating your own game or joining one nearby!',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Primary action - Create game
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreateGame,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Your First Game'),
              ),
            ),

            const SizedBox(height: 12),

            // Secondary action - Browse games
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onBrowseGames,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Browse Games to Join'),
              ),
            ),

            const SizedBox(height: 24),

            // Additional navigation options if available
            if (hasJoinedGames || hasPastGames) ...[
              Text(
                'Or check your other games:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  if (hasJoinedGames) ...[
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onJoinedGames,
                        icon: const Icon(Icons.group_rounded, size: 18),
                        label: const Text('Joined Games'),
                      ),
                    ),
                  ],

                  if (hasJoinedGames && hasPastGames) const SizedBox(width: 8),

                  if (hasPastGames) ...[
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onPastGames,
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('Past Games'),
                      ),
                    ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Help text with tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pro Tips',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '• Create games in advance to give players time to join\n'
                    '• Set up recurring games for regular play sessions\n'
                    '• Join games early - popular ones fill up fast!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Welcome icon with animation potential
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_basketball_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // Welcome title
            Text(
              'Welcome to Dabbler!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Welcome message
            Text(
              'Ready to get in the game? Create your first game or join one nearby to start connecting with other players!',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Primary CTA - Create game
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCreateGame,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Your First Game'),
              ),
            ),

            const SizedBox(height: 12),

            // Secondary CTA - Browse games
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onBrowseGames,
                icon: const Icon(Icons.explore_rounded),
                label: const Text('Explore Games Near You'),
              ),
            ),

            const SizedBox(height: 12),

            // Tutorial link
            TextButton.icon(
              onPressed: onViewTutorial,
              icon: const Icon(Icons.help_outline_rounded),
              label: const Text('How does it work?'),
            ),

            const SizedBox(height: 32),

            // Feature highlights
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'What you can do:',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildFeatureItem(
                    context,
                    Icons.event_rounded,
                    'Create Games',
                    'Organize pickup games at your favorite venues',
                  ),

                  const SizedBox(height: 12),

                  _buildFeatureItem(
                    context,
                    Icons.group_add_rounded,
                    'Join Players',
                    'Find and connect with players in your area',
                  ),

                  const SizedBox(height: 12),

                  _buildFeatureItem(
                    context,
                    Icons.location_city_rounded,
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
    IconData icon,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
