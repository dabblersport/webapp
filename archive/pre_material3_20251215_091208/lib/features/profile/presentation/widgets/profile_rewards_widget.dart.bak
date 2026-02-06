import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../rewards/services/rewards_service_stub.dart' as rewards;
import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';
import '../../../rewards/presentation/widgets/ui/tier_badge_widget.dart';

/// Profile integration with rewards system
class ProfileRewardsWidget extends StatefulWidget {
  final String userId;

  const ProfileRewardsWidget({super.key, required this.userId});

  @override
  State<ProfileRewardsWidget> createState() => _ProfileRewardsWidgetState();
}

class _ProfileRewardsWidgetState extends State<ProfileRewardsWidget> {
  int _totalPoints = 0;
  BadgeTier _currentTier = BadgeTier.bronze;
  List<Achievement> _recentAchievements = [];
  int _totalAchievements = 0;
  int _leaderboardRank = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRewardsData();
  }

  Future<void> _loadRewardsData() async {
    setState(() => _isLoading = true);

    try {
      final rewardsService = rewards.RewardsService();

      final totalPoints = await rewardsService.getUserPoints(widget.userId);
      final currentTier = await rewardsService.getUserTier(widget.userId);
      final achievements = await rewardsService.getUserAchievements(
        widget.userId,
      );
      final rank = await rewardsService.getUserRank(widget.userId);

      if (mounted) {
        setState(() {
          _totalPoints = totalPoints;
          _currentTier = currentTier;
          _recentAchievements = achievements;
          _totalAchievements = achievements.length;
          _leaderboardRank = rank;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading rewards data: $e');
      // Use mock data on error
      if (mounted) {
        setState(() {
          _totalPoints = 150;
          _currentTier = BadgeTier.silver;
          _recentAchievements = [];
          _totalAchievements = 0;
          _leaderboardRank = 42;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with tier badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _currentTier.color.withOpacity(0.1),
                  _currentTier.color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                TierBadgeWidget(tier: _currentTier, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_currentTier.name} Tier',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _currentTier.color,
                            ),
                      ),
                      Text(
                        '$_totalPoints points',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_leaderboardRank > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$_leaderboardRank',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Stats grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Stats',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        icon: LucideIcons.trophy,
                        label: 'Points',
                        value: _formatNumber(_totalPoints),
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        icon: LucideIcons.award,
                        label: 'Achievements',
                        value: _totalAchievements.toString(),
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        icon: LucideIcons.trendingUp,
                        label: 'Rank',
                        value: _leaderboardRank > 0
                            ? '#$_leaderboardRank'
                            : '--',
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Recent achievements
          if (_recentAchievements.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Achievements',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _navigateToAchievements(),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...(_recentAchievements.map(
                    (achievement) => _buildAchievementItem(achievement),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(Achievement achievement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: achievement.tier.color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.award,
              color: achievement.tier.color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  achievement.description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: achievement.tier.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              achievement.tier.name.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: achievement.tier.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  void _navigateToAchievements() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Achievements screen coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Extension to add tier colors
extension BadgeTierColors on BadgeTier {
  Color get color {
    switch (this) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.silver:
        return const Color(0xFFC0C0C0);
      case BadgeTier.gold:
        return const Color(0xFFFFD700);
      case BadgeTier.platinum:
        return const Color(0xFFE5E4E2);
      case BadgeTier.diamond:
        return const Color(0xFFB9F2FF);
    }
  }
}
