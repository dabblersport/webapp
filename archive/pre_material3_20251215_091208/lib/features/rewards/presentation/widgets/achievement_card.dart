import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../themes/app_text_styles.dart';
import '../../../../utils/helpers/date_formatter.dart';
import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';
import 'package:dabbler/data/models/rewards/user_progress.dart';
import '../widgets/progress_visualization.dart';

class AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final UserProgress userProgress;
  final VoidCallback onTap;
  final bool isGridView;
  final bool showQuickActions;

  const AchievementCard({
    super.key,
    required this.achievement,
    required this.userProgress,
    required this.onTap,
    this.isGridView = false,
    this.showQuickActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = userProgress.status == ProgressStatus.completed;
    final isLocked = userProgress.status == ProgressStatus.notStarted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _getTierBorderColor(), width: 2),
          boxShadow: [
            BoxShadow(
              color: _getTierBorderColor().withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: isGridView ? _buildGridLayout() : _buildListLayout(),
            ),

            // Lock overlay for locked achievements
            if (isLocked && achievement.type != AchievementType.hidden)
              _buildLockOverlay(),

            // Mystery overlay for hidden achievements
            if (achievement.type == AchievementType.hidden && !isCompleted)
              _buildMysteryOverlay(),

            // Completion glow effect
            if (isCompleted) _buildCompletionGlow(),

            // Category badge
            Positioned(top: 8, right: 8, child: _buildCategoryBadge()),

            // Rarity indicator
            Positioned(top: 8, left: 8, child: _buildRarityIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildGridLayout() {
    final isCompleted = userProgress.status == ProgressStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon and points row
        Row(
          children: [
            Expanded(child: _buildAchievementIcon()),
            if (!isCompleted) const Spacer(),
            _buildPointsChip(),
          ],
        ),

        const SizedBox(height: 12),

        // Title
        Text(
          achievement.name,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: _getTextColor(),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 8),

        // Description
        Text(
          achievement.description,
          style: AppTextStyles.bodySmall.copyWith(
            color: _getSecondaryTextColor(),
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 12),

        // Progress section
        _buildProgressSection(),

        // Completion date or quick actions
        if (isCompleted) ...[
          const SizedBox(height: 8),
          _buildCompletionInfo(),
        ] else if (showQuickActions) ...[
          const SizedBox(height: 8),
          _buildQuickActions(),
        ],
      ],
    );
  }

  Widget _buildListLayout() {
    return Row(
      children: [
        // Icon
        _buildAchievementIcon(),

        const SizedBox(width: 16),

        // Main content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and points
              Row(
                children: [
                  Expanded(
                    child: Text(
                      achievement.name,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getTextColor(),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPointsChip(),
                ],
              ),

              const SizedBox(height: 4),

              // Description
              Text(
                achievement.description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: _getSecondaryTextColor(),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Progress and completion info
              Row(
                children: [
                  Expanded(child: _buildProgressSection()),
                  if (userProgress.status == ProgressStatus.completed) ...[
                    const SizedBox(width: 12),
                    _buildCompletionInfo(),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementIcon() {
    final iconSize = isGridView ? 48.0 : 56.0;

    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            _getTierBorderColor(),
            _getTierBorderColor().withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _getTierBorderColor().withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _getAchievementIcon(),
        color: Colors.white,
        size: iconSize * 0.5,
      ),
    );
  }

  Widget _buildPointsChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 14),
          const SizedBox(width: 4),
          Text(
            '${achievement.points}',
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.amber.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress visualization based on type
        ProgressVisualization(
          achievement: achievement,
          userProgress: userProgress,
          size: isGridView ? ProgressSize.small : ProgressSize.medium,
        ),

        const SizedBox(height: 4),

        // Progress text
        Text(
          _getProgressText(),
          style: AppTextStyles.bodySmall.copyWith(
            color: _getSecondaryTextColor(),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionInfo() {
    if (userProgress.completedAt == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 14),
            const SizedBox(width: 4),
            Text(
              'Completed',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          DateFormatter.formatDate(userProgress.completedAt!),
          style: AppTextStyles.bodySmall.copyWith(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Share button
        if (userProgress.status == ProgressStatus.completed)
          IconButton(
            onPressed: () {
              // Handle sharing
            },
            icon: const Icon(Icons.share, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

        // View details button
        Text(
          'Tap for details',
          style: AppTextStyles.bodySmall.copyWith(
            color: _getTierBorderColor(),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _getCategoryColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getCategoryName(),
        style: AppTextStyles.bodySmall.copyWith(
          color: _getCategoryColor(),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRarityIndicator() {
    final rarityIcons = {
      BadgeTier.bronze: Icons.workspace_premium,
      BadgeTier.silver: Icons.military_tech,
      BadgeTier.gold: Icons.emoji_events,
      BadgeTier.platinum: Icons.diamond_outlined,
      BadgeTier.diamond: Icons.auto_awesome,
    };

    final rarityColors = {
      BadgeTier.bronze: const Color(0xFFCD7F32),
      BadgeTier.silver: const Color(0xFFC0C0C0),
      BadgeTier.gold: const Color(0xFFFFD700),
      BadgeTier.platinum: const Color(0xFFE5E4E2),
      BadgeTier.diamond: const Color(0xFFB9F2FF),
    };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: rarityColors[achievement.tier]?.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        rarityIcons[achievement.tier],
        color: rarityColors[achievement.tier],
        size: 12,
      ),
    );
  }

  Widget _buildLockOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: Colors.white, size: 32),
              SizedBox(height: 8),
              Text(
                'Locked',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMysteryOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple.withOpacity(0.8),
              Colors.indigo.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.help_outline, color: Colors.white, size: 32),
              SizedBox(height: 8),
              Text(
                'Mystery',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Complete to reveal',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionGlow() {
    return Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 2.seconds, color: Colors.green.withOpacity(0.1));
  }

  Color _getTierBorderColor() {
    switch (achievement.tier) {
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

  IconData _getAchievementIcon() {
    switch (achievement.category) {
      case AchievementCategory.gaming:
        return Icons.sports_esports;
      case AchievementCategory.gameParticipation:
        return Icons.sports_esports;
      case AchievementCategory.social:
        return Icons.people;
      case AchievementCategory.profile:
        return Icons.person;
      case AchievementCategory.venue:
        return Icons.location_city;
      case AchievementCategory.engagement:
        return Icons.favorite;
      case AchievementCategory.skillPerformance:
        return Icons.emoji_events;
      case AchievementCategory.milestone:
        return Icons.flag;
      case AchievementCategory.special:
        return Icons.star;
    }
  }

  Color _getCategoryColor() {
    switch (achievement.category) {
      case AchievementCategory.gaming:
        return Colors.blue;
      case AchievementCategory.gameParticipation:
        return Colors.blue;
      case AchievementCategory.social:
        return Colors.green;
      case AchievementCategory.profile:
        return Colors.teal;
      case AchievementCategory.venue:
        return Colors.brown;
      case AchievementCategory.engagement:
        return Colors.pink;
      case AchievementCategory.skillPerformance:
        return Colors.orange;
      case AchievementCategory.milestone:
        return Colors.purple;
      case AchievementCategory.special:
        return Colors.red;
    }
  }

  String _getCategoryName() {
    switch (achievement.category) {
      case AchievementCategory.gaming:
        return 'Gaming';
      case AchievementCategory.gameParticipation:
        return 'Game';
      case AchievementCategory.social:
        return 'Social';
      case AchievementCategory.profile:
        return 'Profile';
      case AchievementCategory.venue:
        return 'Venue';
      case AchievementCategory.engagement:
        return 'Engagement';
      case AchievementCategory.skillPerformance:
        return 'Skill';
      case AchievementCategory.milestone:
        return 'Milestone';
      case AchievementCategory.special:
        return 'Special';
    }
  }

  Color _getTextColor() {
    if (userProgress.status == ProgressStatus.notStarted) {
      return Colors.grey[600] ?? Colors.grey;
    }
    return Colors.black;
  }

  Color _getSecondaryTextColor() {
    if (userProgress.status == ProgressStatus.notStarted) {
      return Colors.grey[500] ?? Colors.grey;
    }
    return Colors.grey[600] ?? Colors.grey;
  }

  String _getProgressText() {
    final progressPercent = userProgress.calculateProgress();

    switch (userProgress.status) {
      case ProgressStatus.completed:
        return 'Completed 🎉';
      case ProgressStatus.notStarted:
        return 'Not started';
      case ProgressStatus.inProgress:
        return '${progressPercent.toStringAsFixed(0)}% complete';
      case ProgressStatus.expired:
        return 'Expired';
    }
  }
}
