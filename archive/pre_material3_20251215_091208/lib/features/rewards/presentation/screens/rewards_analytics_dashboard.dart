import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';

class RewardsAnalyticsDashboard extends ConsumerStatefulWidget {
  const RewardsAnalyticsDashboard({super.key});

  @override
  ConsumerState<RewardsAnalyticsDashboard> createState() =>
      _RewardsAnalyticsDashboardState();
}

class _RewardsAnalyticsDashboardState
    extends ConsumerState<RewardsAnalyticsDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards Analytics'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events), text: 'Achievements'),
            Tab(icon: Icon(Icons.people), text: 'Engagement'),
            Tab(icon: Icon(Icons.trending_up), text: 'Points'),
            Tab(icon: Icon(Icons.military_tech), text: 'Tiers'),
            Tab(icon: Icon(Icons.star), text: 'Popular'),
            Tab(icon: Icon(Icons.analytics), text: 'Abandonment'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AchievementCompletionDashboard(),
          UserEngagementDashboard(),
          PointsDistributionDashboard(),
          TierProgressionDashboard(),
          PopularAchievementsDashboard(),
          AbandonmentAnalysisDashboard(),
        ],
      ),
    );
  }
}

// Achievement Completion Rates Dashboard
class AchievementCompletionDashboard extends ConsumerWidget {
  const AchievementCompletionDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementAnalytics = ref.watch(achievementAnalyticsProvider);

    return achievementAnalytics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Achievement Completion Overview'),
            const SizedBox(height: 16),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Achievements',
                    data.totalAchievements.toString(),
                    Icons.emoji_events,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Avg Completion Rate',
                    '${(data.averageCompletionRate * 100).toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Completion Rate by Category
            _buildSectionHeader('Completion Rates by Category'),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barGroups: data.categoryCompletionRates.entries.map((entry) {
                    final index = data.categoryCompletionRates.keys
                        .toList()
                        .indexOf(entry.key);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value * 100,
                          color: _getCategoryColor(entry.key),
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final categories = data.categoryCompletionRates.keys
                              .toList();
                          if (value.toInt() < categories.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                categories[value.toInt()].toUpperCase(),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: true, horizontalInterval: 20),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Achievement Difficulty Analysis
            _buildSectionHeader('Completion Rate by Difficulty'),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                  sections: data.difficultyCompletionRates.entries.map((entry) {
                    return PieChartSectionData(
                      value: entry.value * 100,
                      title:
                          '${entry.key}\n${(entry.value * 100).toStringAsFixed(1)}%',
                      color: _getDifficultyColor(entry.key),
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Top Performing Achievements
            _buildSectionHeader('Top Performing Achievements'),
            const SizedBox(height: 16),
            ...data.topAchievements.map(
              (achievement) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getTierColor(achievement.tier),
                    child: const Icon(Icons.star, color: Colors.white),
                  ),
                  title: Text(achievement.name),
                  subtitle: Text(
                    '${achievement.category} • ${achievement.tier.name}',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(achievement.completionRate * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'games':
        return Colors.blue;
      case 'social':
        return Colors.green;
      case 'exploration':
        return Colors.orange;
      case 'progress':
        return Colors.purple;
      case 'engagement':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.yellow[600]!;
      case 'hard':
        return Colors.orange;
      case 'expert':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getTierColor(BadgeTier tier) {
    switch (tier) {
      case BadgeTier.bronze:
        return Colors.brown;
      case BadgeTier.silver:
        return Colors.grey;
      case BadgeTier.gold:
        return Colors.amber;
      case BadgeTier.platinum:
        return Colors.blue[200]!;
      case BadgeTier.diamond:
        return Colors.cyan;
    }
  }
}

// User Engagement Metrics Dashboard
class UserEngagementDashboard extends ConsumerWidget {
  const UserEngagementDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engagementData = ref.watch(engagementAnalyticsProvider);

    return engagementData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key Metrics Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Daily Active Users',
                    data.dailyActiveUsers.toString(),
                    Icons.people,
                    Colors.blue,
                    '+${data.dauGrowth.toStringAsFixed(1)}%',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Average Session Time',
                    '${data.averageSessionTime.toStringAsFixed(1)}m',
                    Icons.timer,
                    Colors.green,
                    '+${data.sessionTimeGrowth.toStringAsFixed(1)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Retention Rate (7d)',
                    '${(data.retentionRate7Day * 100).toStringAsFixed(1)}%',
                    Icons.refresh,
                    Colors.purple,
                    '${data.retentionTrend > 0 ? '+' : ''}${data.retentionTrend.toStringAsFixed(1)}%',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    'Actions per User',
                    data.actionsPerUser.toStringAsFixed(1),
                    Icons.touch_app,
                    Colors.orange,
                    '+${data.actionGrowth.toStringAsFixed(1)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Engagement Over Time Chart
            _buildSectionHeader('Daily Active Users Trend'),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final days = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];
                          if (value.toInt() < days.length) {
                            return Text(days[value.toInt()]);
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY:
                      data.weeklyEngagement.values.reduce(
                        (a, b) => a > b ? a : b,
                      ) *
                      1.1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.weeklyEngagement.entries.map((entry) {
                        final index = data.weeklyEngagement.keys
                            .toList()
                            .indexOf(entry.key);
                        return FlSpot(index.toDouble(), entry.value);
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 4,
                              color: Colors.blue,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // User Segmentation
            _buildSectionHeader('User Engagement Segments'),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: [
                    PieChartSectionData(
                      value: data.highlyEngagedPercent,
                      title:
                          'Highly\nEngaged\n${data.highlyEngagedPercent.toStringAsFixed(1)}%',
                      color: Colors.green,
                      radius: 80,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: data.moderatelyEngagedPercent,
                      title:
                          'Moderately\nEngaged\n${data.moderatelyEngagedPercent.toStringAsFixed(1)}%',
                      color: Colors.orange,
                      radius: 80,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: data.lowEngagementPercent,
                      title:
                          'Low\nEngagement\n${data.lowEngagementPercent.toStringAsFixed(1)}%',
                      color: Colors.red,
                      radius: 80,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String change,
  ) {
    final isPositive = change.startsWith('+');
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(
                    fontSize: 12,
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Points Distribution Dashboard
class PointsDistributionDashboard extends ConsumerWidget {
  const PointsDistributionDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsData = ref.watch(pointsAnalyticsProvider);

    return pointsData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Points Summary
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Points Awarded',
                    _formatNumber(data.totalPointsAwarded),
                    Icons.stars,
                    Colors.amber,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Average Points/User',
                    _formatNumber(data.averagePointsPerUser),
                    Icons.person,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Daily Points Rate',
                    _formatNumber(data.dailyPointsRate),
                    Icons.today,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Points Inflation Rate',
                    '${data.inflationRate.toStringAsFixed(2)}%',
                    Icons.trending_up,
                    data.inflationRate > 5 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Points Distribution Histogram
            _buildSectionHeader('Points Distribution by User'),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      data.distributionBuckets.values.reduce(
                        (a, b) => a > b ? a : b,
                      ) *
                      1.1,
                  barGroups: data.distributionBuckets.entries.map((entry) {
                    final index = data.distributionBuckets.keys
                        .toList()
                        .indexOf(entry.key);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: _getDistributionColor(entry.key),
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final ranges = data.distributionBuckets.keys.toList();
                          if (value.toInt() < ranges.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                ranges[value.toInt()],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Points Sources Breakdown
            _buildSectionHeader('Points Sources'),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                  sections: data.pointsSources.entries.map((entry) {
                    final percentage =
                        (entry.value / data.totalPointsAwarded) * 100;
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: '${entry.key}\n${percentage.toStringAsFixed(1)}%',
                      color: _getSourceColor(entry.key),
                      radius: 80,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }

  Color _getDistributionColor(String range) {
    switch (range) {
      case '0-100':
        return Colors.red[300]!;
      case '101-500':
        return Colors.orange[300]!;
      case '501-1K':
        return Colors.yellow[600]!;
      case '1K-5K':
        return Colors.green[300]!;
      case '5K-10K':
        return Colors.blue[300]!;
      case '10K+':
        return Colors.purple[300]!;
      default:
        return Colors.grey;
    }
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'games':
        return Colors.blue;
      case 'achievements':
        return Colors.amber;
      case 'social':
        return Colors.green;
      case 'daily_bonus':
        return Colors.orange;
      case 'events':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// Additional dashboard widgets would continue here...
// TierProgressionDashboard, PopularAchievementsDashboard, AbandonmentAnalysisDashboard

final achievementAnalyticsProvider = FutureProvider<AchievementAnalyticsData>((
  ref,
) async {
  // Mock data that matches the dashboard's AchievementAnalyticsData structure
  return AchievementAnalyticsData(
    totalAchievements: 150,
    averageCompletionRate: 0.75,
    categoryCompletionRates: {
      'gaming': 0.80,
      'social': 0.65,
      'profile': 0.85,
      'venue': 0.55,
    },
    difficultyCompletionRates: {'bronze': 0.90, 'silver': 0.70, 'gold': 0.45},
    topAchievements: [
      AchievementPerformance(
        id: '1',
        name: 'First Win',
        category: 'gaming',
        tier: BadgeTier.bronze,
        completionRate: 0.95,
      ),
      AchievementPerformance(
        id: '2',
        name: 'Social Butterfly',
        category: 'social',
        tier: BadgeTier.silver,
        completionRate: 0.80,
      ),
    ],
  );
});

final engagementAnalyticsProvider = FutureProvider<EngagementAnalyticsData>((
  ref,
) async {
  // Mock data that matches the dashboard's EngagementAnalyticsData structure
  return EngagementAnalyticsData(
    dailyActiveUsers: 1200,
    dauGrowth: 0.08,
    averageSessionTime: 18.5,
    sessionTimeGrowth: 0.12,
    retentionRate7Day: 0.72,
    retentionTrend: 0.72,
    actionsPerUser: 15.3,
    actionGrowth: 0.05,
    weeklyEngagement: {
      'Mon': 0.65,
      'Tue': 0.70,
      'Wed': 0.68,
      'Thu': 0.72,
      'Fri': 0.75,
      'Sat': 0.80,
      'Sun': 0.62,
    },
    highlyEngagedPercent: 0.25,
    moderatelyEngagedPercent: 0.45,
    lowEngagementPercent: 0.30,
  );
});

final pointsAnalyticsProvider = FutureProvider<PointsAnalyticsData>((
  ref,
) async {
  // Mock data that matches the dashboard's PointsAnalyticsData structure
  return PointsAnalyticsData(
    totalPointsAwarded: 750000,
    averagePointsPerUser: 950,
    dailyPointsRate: 1500.0,
    inflationRate: 0.025,
    distributionBuckets: {
      '0-100': 180,
      '101-500': 320,
      '501-1000': 280,
      '1000+': 220,
    },
    pointsSources: {
      'achievements': 55,
      'daily_bonus': 25,
      'social': 12,
      'challenges': 8,
    },
  );
});

// Data classes
class AchievementAnalyticsData {
  final int totalAchievements;
  final double averageCompletionRate;
  final Map<String, double> categoryCompletionRates;
  final Map<String, double> difficultyCompletionRates;
  final List<AchievementPerformance> topAchievements;

  AchievementAnalyticsData({
    required this.totalAchievements,
    required this.averageCompletionRate,
    required this.categoryCompletionRates,
    required this.difficultyCompletionRates,
    required this.topAchievements,
  });
}

class AchievementPerformance {
  final String id;
  final String name;
  final String category;
  final BadgeTier tier;
  final double completionRate;

  AchievementPerformance({
    required this.id,
    required this.name,
    required this.category,
    required this.tier,
    required this.completionRate,
  });
}

class EngagementAnalyticsData {
  final int dailyActiveUsers;
  final double dauGrowth;
  final double averageSessionTime;
  final double sessionTimeGrowth;
  final double retentionRate7Day;
  final double retentionTrend;
  final double actionsPerUser;
  final double actionGrowth;
  final Map<String, double> weeklyEngagement;
  final double highlyEngagedPercent;
  final double moderatelyEngagedPercent;
  final double lowEngagementPercent;

  EngagementAnalyticsData({
    required this.dailyActiveUsers,
    required this.dauGrowth,
    required this.averageSessionTime,
    required this.sessionTimeGrowth,
    required this.retentionRate7Day,
    required this.retentionTrend,
    required this.actionsPerUser,
    required this.actionGrowth,
    required this.weeklyEngagement,
    required this.highlyEngagedPercent,
    required this.moderatelyEngagedPercent,
    required this.lowEngagementPercent,
  });
}

class PointsAnalyticsData {
  final double totalPointsAwarded;
  final double averagePointsPerUser;
  final double dailyPointsRate;
  final double inflationRate;
  final Map<String, int> distributionBuckets;
  final Map<String, int> pointsSources;

  PointsAnalyticsData({
    required this.totalPointsAwarded,
    required this.averagePointsPerUser,
    required this.dailyPointsRate,
    required this.inflationRate,
    required this.distributionBuckets,
    required this.pointsSources,
  });
}

/// Missing Dashboard Widget Classes
class TierProgressionDashboard extends StatelessWidget {
  const TierProgressionDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Tier Progression Dashboard - Coming Soon'),
    );
  }
}

class PopularAchievementsDashboard extends StatelessWidget {
  const PopularAchievementsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Popular Achievements Dashboard - Coming Soon'),
    );
  }
}

class AbandonmentAnalysisDashboard extends StatelessWidget {
  const AbandonmentAnalysisDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Abandonment Analysis Dashboard - Coming Soon'),
    );
  }
}
