import 'package:flutter/material.dart';

/// Widget for displaying engagement metrics
class EngagementMetricsWidget extends StatelessWidget {
  final EngagementMetrics metrics;

  const EngagementMetricsWidget({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Cards
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Total Posts',
                  value: metrics.totalPosts.toString(),
                  icon: Icons.post_add,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  title: 'Total Engagement',
                  value: _formatNumber(metrics.totalEngagement),
                  icon: Icons.favorite,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Avg. Rate',
                  value: '${metrics.averageEngagementRate.toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  title: 'Active Users',
                  value: _formatNumber(metrics.activeUsers),
                  icon: Icons.people,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Engagement Breakdown
          Text(
            'Engagement Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _EngagementRow(
                    icon: Icons.favorite,
                    label: 'Likes',
                    value: metrics.totalLikes,
                    percentage: metrics.totalEngagement > 0
                        ? (metrics.totalLikes / metrics.totalEngagement) * 100
                        : 0,
                    color: Colors.red,
                  ),
                  const Divider(),
                  _EngagementRow(
                    icon: Icons.comment,
                    label: 'Comments',
                    value: metrics.totalComments,
                    percentage: metrics.totalEngagement > 0
                        ? (metrics.totalComments / metrics.totalEngagement) *
                              100
                        : 0,
                    color: Colors.blue,
                  ),
                  const Divider(),
                  _EngagementRow(
                    icon: Icons.share,
                    label: 'Shares',
                    value: metrics.totalShares,
                    percentage: metrics.totalEngagement > 0
                        ? (metrics.totalShares / metrics.totalEngagement) * 100
                        : 0,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Growth Metrics
          Text(
            'Growth Metrics',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _GrowthRow(label: 'Posts Growth', value: metrics.postsGrowth),
                  const Divider(),
                  _GrowthRow(
                    label: 'Engagement Growth',
                    value: metrics.engagementGrowth,
                  ),
                  const Divider(),
                  _GrowthRow(label: 'User Growth', value: metrics.userGrowth),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return '${(number / 1000).toStringAsFixed(1)}K';
    return '${(number / 1000000).toStringAsFixed(1)}M';
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngagementRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final double percentage;
  final Color color;

  const _EngagementRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ],
    );
  }
}

class _GrowthRow extends StatelessWidget {
  final String label;
  final double value;

  const _GrowthRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = value >= 0;

    return Row(
      children: [
        Icon(
          isPositive ? Icons.trending_up : Icons.trending_down,
          color: isPositive ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          '${isPositive ? '+' : ''}${value.toStringAsFixed(1)}%',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isPositive ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }
}

/// Data class for engagement metrics
class EngagementMetrics {
  final int totalPosts;
  final int totalEngagement;
  final double averageEngagementRate;
  final int activeUsers;
  final int totalLikes;
  final int totalComments;
  final int totalShares;
  final double postsGrowth;
  final double engagementGrowth;
  final double userGrowth;

  const EngagementMetrics({
    required this.totalPosts,
    required this.totalEngagement,
    required this.averageEngagementRate,
    required this.activeUsers,
    required this.totalLikes,
    required this.totalComments,
    required this.totalShares,
    required this.postsGrowth,
    required this.engagementGrowth,
    required this.userGrowth,
  });
}
