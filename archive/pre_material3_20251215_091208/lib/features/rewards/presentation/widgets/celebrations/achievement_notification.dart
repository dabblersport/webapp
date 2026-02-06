import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';

/// Achievement data for notifications
class AchievementData {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color iconColor;
  final int pointsEarned;
  final BadgeTier tier;
  final DateTime earnedAt;
  final Map<String, dynamic>? metadata;
  final String? imageUrl;

  const AchievementData({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.iconColor = Colors.amber,
    required this.pointsEarned,
    this.tier = BadgeTier.bronze,
    required this.earnedAt,
    this.metadata,
    this.imageUrl,
  });

  Color get tierColor {
    switch (tier) {
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

  String get formattedPoints {
    return pointsEarned.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

/// Progress data for next achievement
class ProgressData {
  final String nextAchievementName;
  final int currentProgress;
  final int targetProgress;
  final String description;

  const ProgressData({
    required this.nextAchievementName,
    required this.currentProgress,
    required this.targetProgress,
    this.description = '',
  });

  double get progressPercentage {
    if (targetProgress <= 0) return 0.0;
    return (currentProgress / targetProgress).clamp(0.0, 1.0);
  }

  int get remainingProgress =>
      (targetProgress - currentProgress).clamp(0, targetProgress);
}

/// Achievement notification widget
class AchievementNotification extends StatefulWidget {
  final AchievementData achievement;
  final ProgressData? nextProgress;
  final Function(String action)? onAction;
  final VoidCallback? onDismiss;
  final Duration? autoCloseAfter;
  final bool showActions;
  final bool showProgress;
  final bool enableHaptics;
  final EdgeInsets margin;

  const AchievementNotification({
    super.key,
    required this.achievement,
    this.nextProgress,
    this.onAction,
    this.onDismiss,
    this.autoCloseAfter = const Duration(seconds: 5),
    this.showActions = true,
    this.showProgress = true,
    this.enableHaptics = true,
    this.margin = const EdgeInsets.all(16),
  });

  @override
  State<AchievementNotification> createState() =>
      _AchievementNotificationState();
}

class _AchievementNotificationState extends State<AchievementNotification>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late AnimationController _dismissController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _dismissAnimation;

  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startEntryAnimation();
    _setupAutoClose();

    if (widget.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _dismissController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _dismissAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _dismissController, curve: Curves.easeInOut),
    );
  }

  void _startEntryAnimation() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _slideController.forward();
      _scaleController.forward();
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      _glowController.repeat(reverse: true);
    });
  }

  void _setupAutoClose() {
    if (widget.autoCloseAfter != null) {
      Future.delayed(widget.autoCloseAfter!, () {
        if (mounted && !_isDismissed) {
          _handleDismiss();
        }
      });
    }
  }

  void _handleDismiss() {
    if (_isDismissed) return;

    setState(() {
      _isDismissed = true;
    });

    _glowController.stop();
    _dismissController.forward().then((_) {
      widget.onDismiss?.call();
    });

    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleAction(String action) {
    widget.onAction?.call(action);

    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }

    // Auto-dismiss after action unless it's 'view'
    if (action != 'view') {
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleDismiss();
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dismissAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _dismissAnimation.value,
          child: Opacity(
            opacity: _dismissAnimation.value,
            child: Container(
              margin: widget.margin,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildNotificationCard(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.achievement.tierColor.withOpacity(
                  0.2 + 0.3 * _glowAnimation.value,
                ),
                blurRadius: 12 + 8 * _glowAnimation.value,
                spreadRadius: 2 + 2 * _glowAnimation.value,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: widget.achievement.tierColor.withOpacity(
                  0.3 + 0.4 * _glowAnimation.value,
                ),
                width: 2,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.achievement.tierColor.withOpacity(0.05),
                    widget.achievement.tierColor.withOpacity(0.02),
                    Colors.white,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(theme),
                  _buildMainContent(theme),
                  if (widget.showProgress && widget.nextProgress != null)
                    _buildProgressSection(theme),
                  if (widget.showActions) _buildActionButtons(theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: widget.achievement.tierColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: widget.achievement.tierColor,
                borderRadius: BorderRadius.circular(6),
                gradient: RadialGradient(
                  colors: [
                    widget.achievement.tierColor.withOpacity(0.8),
                    widget.achievement.tierColor,
                  ],
                ),
              ),
              child: Icon(
                widget.achievement.icon,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Achievement Unlocked!',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: widget.achievement.tierColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.achievement.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle, size: 16, color: Colors.green[600]),
                const SizedBox(width: 4),
                Text(
                  '+${widget.achievement.formattedPoints}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.green[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _handleDismiss,
            icon: Icon(Icons.close, color: Colors.grey[600], size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.achievement.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.achievement.tierColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.achievement.tier.name.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: widget.achievement.tierColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Just now',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(ThemeData theme) {
    final progress = widget.nextProgress!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                'Next Goal: ${progress.nextAchievementName}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                '${progress.currentProgress}/${progress.targetProgress}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progressPercentage,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
              minHeight: 6,
            ),
          ),
          if (progress.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              progress.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _handleAction('share'),
              icon: const Icon(Icons.share, size: 16),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _handleAction('view'),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('View'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                backgroundColor: widget.achievement.tierColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Achievement notification manager for handling multiple notifications
class AchievementNotificationManager extends StatefulWidget {
  final List<AchievementData> achievements;
  final Function(String, String)? onAction;
  final VoidCallback? onAllDismissed;
  final int maxVisible;
  final Duration stackDelay;

  const AchievementNotificationManager({
    super.key,
    required this.achievements,
    this.onAction,
    this.onAllDismissed,
    this.maxVisible = 3,
    this.stackDelay = const Duration(milliseconds: 300),
  });

  @override
  State<AchievementNotificationManager> createState() =>
      _AchievementNotificationManagerState();
}

class _AchievementNotificationManagerState
    extends State<AchievementNotificationManager> {
  final List<String> _visibleAchievements = [];
  final List<String> _dismissedAchievements = [];

  @override
  void initState() {
    super.initState();
    _scheduleNotifications();
  }

  void _scheduleNotifications() {
    for (
      int i = 0;
      i < widget.achievements.length && i < widget.maxVisible;
      i++
    ) {
      Future.delayed(widget.stackDelay * i, () {
        if (mounted) {
          setState(() {
            _visibleAchievements.add(widget.achievements[i].id);
          });
        }
      });
    }
  }

  void _handleDismiss(String achievementId) {
    setState(() {
      _visibleAchievements.remove(achievementId);
      _dismissedAchievements.add(achievementId);
    });

    // Show next achievement if available
    final nextIndex =
        _visibleAchievements.length + _dismissedAchievements.length;
    if (nextIndex < widget.achievements.length) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _visibleAchievements.add(widget.achievements[nextIndex].id);
          });
        }
      });
    }

    // Check if all are dismissed
    if (_dismissedAchievements.length == widget.achievements.length) {
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onAllDismissed?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (int i = 0; i < _visibleAchievements.length; i++)
          Positioned(
            top: MediaQuery.of(context).padding.top + (i * 60.0),
            left: 0,
            right: 0,
            child: AchievementNotification(
              key: ValueKey(_visibleAchievements[i]),
              achievement: widget.achievements.firstWhere(
                (a) => a.id == _visibleAchievements[i],
              ),
              onAction: (action) =>
                  widget.onAction?.call(_visibleAchievements[i], action),
              onDismiss: () => _handleDismiss(_visibleAchievements[i]),
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: i * 4.0),
            ),
          ),
      ],
    );
  }
}
