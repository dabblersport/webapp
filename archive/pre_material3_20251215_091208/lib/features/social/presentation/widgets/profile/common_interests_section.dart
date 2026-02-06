import 'package:flutter/material.dart';

class CommonInterestsSection extends StatelessWidget {
  final List<dynamic> interests;
  final Function(dynamic) onInterestTap;
  final VoidCallback onSuggestActivity;

  const CommonInterestsSection({
    super.key,
    required this.interests,
    required this.onInterestTap,
    required this.onSuggestActivity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Common Interests',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: onSuggestActivity,
                icon: const Icon(Icons.add),
                label: const Text('Suggest Activity'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (interests.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.interests_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No common interests yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add interests to your profile to find common ground',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: interests
                  .map((interest) => _buildInterestChip(theme, interest))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildInterestChip(ThemeData theme, dynamic interest) {
    return ActionChip(
      avatar: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        child: Icon(
          _getInterestIcon(interest.type),
          size: 16,
          color: theme.colorScheme.primary,
        ),
      ),
      label: Text(
        interest.name ?? 'Unknown Interest',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: theme.colorScheme.surface,
      side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
      onPressed: () => onInterestTap(interest),
    );
  }

  IconData _getInterestIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'sports':
        return Icons.sports;
      case 'music':
        return Icons.music_note;
      case 'movies':
        return Icons.movie;
      case 'books':
        return Icons.book;
      case 'travel':
        return Icons.flight;
      case 'food':
        return Icons.restaurant;
      case 'gaming':
        return Icons.games;
      case 'fitness':
        return Icons.fitness_center;
      case 'art':
        return Icons.palette;
      case 'technology':
        return Icons.computer;
      default:
        return Icons.favorite;
    }
  }
}
