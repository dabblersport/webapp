import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';
import 'package:dabbler/data/models/rewards/user_progress.dart';
import '../widgets/progress_visualization.dart';

class AchievementDetailScreen extends StatefulWidget {
  final Achievement achievement;
  final UserProgress userProgress;

  const AchievementDetailScreen({
    super.key,
    required this.achievement,
    required this.userProgress,
  });

  @override
  State<AchievementDetailScreen> createState() =>
      _AchievementDetailScreenState();
}

class _AchievementDetailScreenState extends State<AchievementDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _contentAnimationController;
  late Animation<double> _headerAnimation;
  late Animation<double> _contentAnimation;

  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupScrollListener();
  }

  void _setupAnimations() {
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    );
    _contentAnimation = CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOutCubic,
    );

    // Start animations
    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _contentAnimationController.forward();
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      final showTitle = _scrollController.offset > 200;
      if (showTitle != _showAppBarTitle) {
        setState(() => _showAppBarTitle = showTitle);
      }
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _contentAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHeroSection(),
                _buildProgressSection(),
                _buildDescriptionSection(),
                _buildRequirementsSection(),
                _buildTipsSection(),
                _buildRewardsSection(),
                _buildActionButtons(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: _showAppBarTitle ? 1 : 0,
      title: AnimatedOpacity(
        opacity: _showAppBarTitle ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          widget.achievement.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.share), onPressed: _shareAchievement),
        IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
      ],
    );
  }

  Widget _buildHeroSection() {
    final isCompleted = widget.userProgress.status == ProgressStatus.completed;
    final isHidden =
        widget.achievement.type == AchievementType.hidden && !isCompleted;

    return AnimatedBuilder(
      animation: _headerAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: _getTierGradient()),
          child: Column(
            children: [
              const SizedBox(height: 40), // Account for status bar
              // Achievement Icon/Badge
              Transform.scale(
                scale: _headerAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: isHidden
                      ? const Icon(
                          Icons.help_outline,
                          size: 60,
                          color: Colors.white,
                        )
                      : Icon(
                          _getAchievementIcon(),
                          size: 60,
                          color: Colors.white,
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Title
              FadeTransition(
                opacity: _headerAnimation,
                child: Text(
                  isHidden ? 'Hidden Achievement' : widget.achievement.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle/Category
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(_headerAnimation),
                child: Text(
                  _getCategoryName(widget.achievement.category),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Completion Status
              if (isCompleted)
                Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Completed ${_formatDate(widget.userProgress.completedAt!)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      duration: 300.ms,
                      delay: 400.ms,
                    )
                    .fadeIn(delay: 400.ms),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressSection() {
    final isCompleted = widget.userProgress.status == ProgressStatus.completed;
    final isHidden =
        widget.achievement.type == AchievementType.hidden && !isCompleted;

    if (isHidden) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _contentAnimation,
      builder: (context, child) {
        return Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${widget.userProgress.calculateProgress().round()}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Progress Visualization
                  Center(
                    child: ProgressVisualization(
                      achievement: widget.achievement,
                      userProgress: widget.userProgress,
                      size: ProgressSize.large,
                      animated: true,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress Details
                  if (widget.achievement.type == AchievementType.cumulative)
                    _buildCumulativeProgress(),

                  if (widget.achievement.type == AchievementType.streak)
                    _buildStreakProgress(),

                  if (widget.achievement.type == AchievementType.conditional)
                    _buildConditionalProgress(),
                ],
              ),
            )
            .animate()
            .fadeIn(
              duration: 400.ms,
              delay: Duration(
                milliseconds: (100 * _contentAnimation.value).round(),
              ),
            )
            .slideY(
              begin: 0.3,
              end: 0,
              duration: 400.ms,
              delay: Duration(
                milliseconds: (100 * _contentAnimation.value).round(),
              ),
            );
      },
    );
  }

  Widget _buildDescriptionSection() {
    final isCompleted = widget.userProgress.status == ProgressStatus.completed;
    final isHidden =
        widget.achievement.type == AchievementType.hidden && !isCompleted;

    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.description,
                    color: Colors.black87,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Text(
                isHidden
                    ? 'This achievement is hidden. Complete the requirements to reveal its details.'
                    : widget.achievement.description,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .slideY(begin: 0.3, end: 0, duration: 400.ms, delay: 200.ms);
  }

  Widget _buildRequirementsSection() {
    final isHidden =
        widget.achievement.type == AchievementType.hidden &&
        widget.userProgress.status != ProgressStatus.completed;

    if (isHidden) return const SizedBox.shrink();

    return Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.checklist, color: Colors.black87, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Requirements',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Use description as requirements for now
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.achievement.description,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 300.ms)
        .slideY(begin: 0.3, end: 0, duration: 400.ms, delay: 300.ms);
  }

  Widget _buildTipsSection() {
    // No hints available in Achievement entity
    return const SizedBox.shrink();
  }

  Widget _buildRewardsSection() {
    return Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber[50]!, Colors.orange[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Rewards',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  // Points
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.stars, color: Colors.amber[600], size: 32),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.achievement.points}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                          Text(
                            'Points',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Badge Tier
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _getTierIcon(),
                            color: _getTierColor(),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getTierName(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _getTierColor(),
                            ),
                          ),
                          Text(
                            'Badge',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 500.ms)
        .slideY(begin: 0.3, end: 0, duration: 400.ms, delay: 500.ms);
  }

  Widget _buildActionButtons() {
    final isCompleted = widget.userProgress.status == ProgressStatus.completed;

    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Primary action button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: isCompleted ? null : _startTracking,
                  icon: Icon(
                    isCompleted ? Icons.check_circle : Icons.play_arrow,
                  ),
                  label: Text(
                    isCompleted
                        ? 'Achievement Completed!'
                        : 'Start Tracking Progress',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCompleted
                        ? Colors.green
                        : Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: isCompleted ? 0 : 2,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Secondary actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareAchievement,
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Link'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 600.ms)
        .slideY(begin: 0.3, end: 0, duration: 400.ms, delay: 600.ms);
  }

  Widget _buildCumulativeProgress() {
    // Implementation for cumulative progress details
    return const SizedBox.shrink();
  }

  Widget _buildStreakProgress() {
    // Implementation for streak progress details
    return const SizedBox.shrink();
  }

  Widget _buildConditionalProgress() {
    // Implementation for conditional progress details
    return const SizedBox.shrink();
  }

  LinearGradient _getTierGradient() {
    switch (widget.achievement.tier) {
      case BadgeTier.bronze:
        return LinearGradient(
          colors: [Colors.brown[400]!, Colors.brown[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case BadgeTier.silver:
        return LinearGradient(
          colors: [Colors.grey[400]!, Colors.grey[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case BadgeTier.gold:
        return LinearGradient(
          colors: [Colors.amber[400]!, Colors.orange[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case BadgeTier.platinum:
        return LinearGradient(
          colors: [Colors.blue[300]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case BadgeTier.diamond:
        return LinearGradient(
          colors: [Colors.purple[300]!, Colors.purple[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  IconData _getAchievementIcon() {
    switch (widget.achievement.category) {
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
        return Icons.school;
      case AchievementCategory.milestone:
        return Icons.flag;
      case AchievementCategory.special:
        return Icons.star;
    }
  }

  String _getCategoryName(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.gaming:
        return 'Gaming Achievement';
      case AchievementCategory.gameParticipation:
        return 'Gaming Achievement';
      case AchievementCategory.social:
        return 'Social Achievement';
      case AchievementCategory.profile:
        return 'Profile Achievement';
      case AchievementCategory.venue:
        return 'Venue Achievement';
      case AchievementCategory.engagement:
        return 'Engagement Achievement';
      case AchievementCategory.skillPerformance:
        return 'Skill Achievement';
      case AchievementCategory.milestone:
        return 'Milestone Achievement';
      case AchievementCategory.special:
        return 'Special Achievement';
    }
  }

  IconData _getTierIcon() {
    switch (widget.achievement.tier) {
      case BadgeTier.bronze:
        return Icons.looks_3;
      case BadgeTier.silver:
        return Icons.looks_two;
      case BadgeTier.gold:
        return Icons.looks_one;
      case BadgeTier.platinum:
        return Icons.star;
      case BadgeTier.diamond:
        return Icons.diamond;
    }
  }

  Color _getTierColor() {
    switch (widget.achievement.tier) {
      case BadgeTier.bronze:
        return Colors.brown[600]!;
      case BadgeTier.silver:
        return Colors.grey[600]!;
      case BadgeTier.gold:
        return Colors.amber[600]!;
      case BadgeTier.platinum:
        return Colors.blue[600]!;
      case BadgeTier.diamond:
        return Colors.purple[600]!;
    }
  }

  String _getTierName() {
    switch (widget.achievement.tier) {
      case BadgeTier.bronze:
        return 'Bronze';
      case BadgeTier.silver:
        return 'Silver';
      case BadgeTier.gold:
        return 'Gold';
      case BadgeTier.platinum:
        return 'Platinum';
      case BadgeTier.diamond:
        return 'Diamond';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _shareAchievement() {
    final isCompleted = widget.userProgress.status == ProgressStatus.completed;
    final text = isCompleted
        ? 'I just earned the "${widget.achievement.name}" achievement in Dabbler! 🎉'
        : 'Check out this achievement in Dabbler: "${widget.achievement.name}"';

    Share.share(text);
  }

  void _copyToClipboard() {
    Clipboard.setData(
      ClipboardData(
        text: 'Check out this achievement: ${widget.achievement.name}',
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Achievement link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _startTracking() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Started tracking progress!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
