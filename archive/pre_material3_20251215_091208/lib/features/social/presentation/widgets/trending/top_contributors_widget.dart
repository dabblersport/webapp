import 'package:flutter/material.dart';

/// Widget for displaying top contributors
class TopContributorsWidget extends StatelessWidget {
  final List<TopContributor> contributors;
  final ValueChanged<String>? onContributorTap;

  const TopContributorsWidget({
    super.key,
    required this.contributors,
    this.onContributorTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (contributors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No top contributors',
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
      itemCount: contributors.length,
      itemBuilder: (context, index) {
        final contributor = contributors[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: contributor.avatarUrl != null
                  ? NetworkImage(contributor.avatarUrl!)
                  : null,
              child: contributor.avatarUrl == null
                  ? Text(contributor.displayName.substring(0, 1).toUpperCase())
                  : null,
            ),
            title: Row(
              children: [
                Text(
                  '${index + 1}. ${contributor.displayName}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (contributor.isVerified) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.verified,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
            subtitle: Text(
              '${contributor.postCount} posts • ${contributor.totalEngagement} engagements',
              style: theme.textTheme.bodySmall,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${contributor.engagementRate.toStringAsFixed(1)}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  'Avg. Rate',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            onTap: () => onContributorTap?.call(contributor.userId),
          ),
        );
      },
    );
  }
}

/// Data class for top contributor information
class TopContributor {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int postCount;
  final int totalEngagement;
  final double engagementRate;
  final bool isVerified;
  final int rank;

  const TopContributor({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.postCount,
    required this.totalEngagement,
    required this.engagementRate,
    this.isVerified = false,
    required this.rank,
  });
}
