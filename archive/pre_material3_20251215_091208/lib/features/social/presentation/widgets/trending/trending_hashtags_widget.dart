import 'package:flutter/material.dart';

/// Widget for displaying trending hashtags
class TrendingHashtagsWidget extends StatelessWidget {
  final List<TrendingHashtag> hashtags;
  final VoidCallback? onHashtagTap;

  const TrendingHashtagsWidget({
    super.key,
    required this.hashtags,
    this.onHashtagTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (hashtags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tag,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No trending hashtags',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hashtags.length,
      itemBuilder: (context, index) {
        final hashtag = hashtags[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.tag),
            title: Text(
              '#${hashtag.tag}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${hashtag.postCount} posts • ${hashtag.engagementCount} engagements',
              style: theme.textTheme.bodySmall,
            ),
            trailing: Text(
              '${hashtag.growthPercentage.toStringAsFixed(1)}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: hashtag.growthPercentage >= 0
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: onHashtagTap,
          ),
        );
      },
    );
  }
}

/// Data class for trending hashtag information
class TrendingHashtag {
  final String tag;
  final int postCount;
  final int engagementCount;
  final double growthPercentage;
  final int rank;

  const TrendingHashtag({
    required this.tag,
    required this.postCount,
    required this.engagementCount,
    required this.growthPercentage,
    required this.rank,
  });
}
