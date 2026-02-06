import 'package:flutter/material.dart';

/// A widget for displaying when the social feed is empty
class EmptyFeedWidget extends StatelessWidget {
  const EmptyFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty state icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.3,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.feed_outlined,
                size: 60,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 24),

            // Empty state title
            Text(
              'No Posts Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Empty state description
            Text(
              'Be the first to share something! Create a post to start building your social feed.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Call to action button
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Create post functionality coming soon!'),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Post'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Alternative actions
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Discover people functionality coming soon!',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Discover People'),
                ),

                const SizedBox(width: 16),

                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Games functionality coming soon!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.sports),
                  label: const Text('Find Games'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
