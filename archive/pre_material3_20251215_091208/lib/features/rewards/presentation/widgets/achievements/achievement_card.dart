import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/user_progress.dart';

enum AchievementCardMode { grid, list }

class AchievementCard extends StatefulWidget {
  final Achievement achievement;
  final UserProgress? userProgress;
  final AchievementCardMode mode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showProgressIndicator;
  final bool showPointsBadge;
  final bool enableAnimations;
  final EdgeInsets? padding;

  const AchievementCard({
    super.key,
    required this.achievement,
    this.userProgress,
    this.mode = AchievementCardMode.grid,
    this.onTap,
    this.onLongPress,
    this.showProgressIndicator = true,
    this.showPointsBadge = true,
    this.enableAnimations = true,
    this.padding,
  });

  @override
  State<AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<AchievementCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _bounceController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _bounceAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    if (widget.enableAnimations) {
      _pulseController = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      );

      _glowController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );

      _bounceController = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );

      _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      );

      _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
      );

      _bounceAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
      );

      // Start pulse animation for completed achievements
      if (_isCompleted) {
        _pulseController.repeat(reverse: true);
        _glowController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    if (widget.enableAnimations) {
      _pulseController.dispose();
      _glowController.dispose();
      _bounceController.dispose();
    }
    super.dispose();
  }

  bool get _isCompleted =>
      widget.userProgress?.status == ProgressStatus.completed;

  bool get _isLocked =>
      widget.userProgress?.status == ProgressStatus.notStarted ||
      widget.userProgress == null;

  double get _progress => widget.userProgress?.calculateProgress() ?? 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _handleTapDown(),
      onTapUp: (_) => _handleTapUp(),
      onTapCancel: () => _handleTapUp(),
      onTap: widget.onTap,
      onLongPress: () => _handleLongPress(),
      child: AnimatedBuilder(
        animation: widget.enableAnimations
            ? Listenable.merge([
                _pulseController,
                _glowController,
                _bounceController,
              ])
            : AnimationController(vsync: this),
        builder: (context, child) {
          return Transform.scale(
            scale: widget.enableAnimations
                ? (_isPressed ? _bounceAnimation.value : _pulseAnimation.value)
                : 1.0,
            child: _buildCard(),
          );
        },
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: widget.padding ?? _getDefaultPadding(),
      child: Stack(
        children: [
          // Main card
          _buildMainCard(),

          // Lock overlay for unavailable achievements
          if (_isLocked) _buildLockOverlay(),

          // Completion checkmark animation
          if (_isCompleted && widget.enableAnimations)
            _buildCompletionCheckmark(),

          // Progress indicator
          if (widget.showProgressIndicator && !_isLocked)
            _buildProgressIndicator(),

          // Points badge
          if (widget.showPointsBadge) _buildPointsBadge(),

          // Glow effect for completed achievements
          if (_isCompleted && widget.enableAnimations) _buildGlowEffect(),
        ],
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      width: widget.mode == AchievementCardMode.grid ? null : double.infinity,
      height: widget.mode == AchievementCardMode.grid ? null : 100,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor(), width: _getBorderWidth()),
        boxShadow: [
          BoxShadow(
            color: _getShadowColor(),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: _isCompleted ? _getCompletionGradient() : null,
      ),
      child: widget.mode == AchievementCardMode.grid
          ? _buildGridContent()
          : _buildListContent(),
    );
  }

  Widget _buildGridContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Achievement icon
          _buildAchievementIcon(),
          const SizedBox(height: 12),

          // Achievement name
          Text(
            widget.achievement.name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _getTextColor(),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Achievement description
          Text(
            widget.achievement.description,
            style: TextStyle(fontSize: 11, color: _getSecondaryTextColor()),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Tier badge
          _buildTierBadge(),
        ],
      ),
    );
  }

  Widget _buildListContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Achievement icon
          _buildAchievementIcon(),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Achievement name and tier
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.achievement.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getTextColor(),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTierBadge(),
                  ],
                ),
                const SizedBox(height: 4),

                // Achievement description
                Text(
                  widget.achievement.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getSecondaryTextColor(),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Progress text
                if (widget.userProgress != null)
                  Text(
                    _getProgressText(),
                    style: TextStyle(
                      fontSize: 11,
                      color: _getProgressTextColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementIcon() {
    final iconSize = widget.mode == AchievementCardMode.grid ? 48.0 : 40.0;

    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getIconBackgroundColor(),
        border: Border.all(color: _getTierColor(), width: 3),
        boxShadow: [
          BoxShadow(
            color: _getTierColor().withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isLocked
          ? Icon(Icons.lock, size: iconSize * 0.5, color: Colors.grey[400])
          : _buildCategoryIcon(iconSize * 0.6),
    );
  }

  Widget _buildCategoryIcon(double size) {
    IconData iconData = Icons.star; // Default icon

    switch (widget.achievement.category) {
      case AchievementCategory.gaming:
        iconData = Icons.sports_soccer;
        break;
      case AchievementCategory.gameParticipation:
        iconData = Icons.sports_soccer;
        break;
      case AchievementCategory.social:
        iconData = Icons.people;
        break;
      case AchievementCategory.profile:
        iconData = Icons.person;
        break;
      case AchievementCategory.venue:
        iconData = Icons.location_city;
        break;
      case AchievementCategory.engagement:
        iconData = Icons.favorite;
        break;
      case AchievementCategory.skillPerformance:
        iconData = Icons.trending_up;
        break;
      case AchievementCategory.milestone:
        iconData = Icons.flag;
        break;
      case AchievementCategory.special:
        iconData = Icons.star;
        break;
    }

    return Icon(
      iconData,
      size: size,
      color: _isCompleted ? Colors.white : _getTierColor(),
    );
  }

  Widget _buildTierBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getTierColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        widget.achievement.getTierDisplayName(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (_isCompleted || _isLocked) return const SizedBox.shrink();

    return Positioned(
      bottom: 8,
      left: 8,
      right: widget.showPointsBadge ? 48 : 8,
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: Colors.grey[300],
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: _progress / 100,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [_getTierColor().withOpacity(0.8), _getTierColor()],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPointsBadge() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stars, size: 12, color: Colors.white),
            const SizedBox(width: 2),
            Text(
              '${widget.achievement.points}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(Icons.lock, size: 32, color: Colors.white),
      ),
    );
  }

  Widget _buildCompletionCheckmark() {
    return Positioned(
      top: 8,
      left: 8,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(_glowAnimation.value * 0.5),
                  blurRadius: _glowAnimation.value * 8,
                  spreadRadius: _glowAnimation.value * 2,
                ),
              ],
            ),
            child: const Icon(Icons.check, size: 16, color: Colors.white),
          );
        },
      ),
    ).animate().scale(
      delay: const Duration(milliseconds: 500),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
    );
  }

  Widget _buildGlowEffect() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _getTierColor().withOpacity(_glowAnimation.value * 0.3),
                blurRadius: _glowAnimation.value * 12,
                spreadRadius: _glowAnimation.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }

  EdgeInsets _getDefaultPadding() {
    return widget.mode == AchievementCardMode.grid
        ? const EdgeInsets.all(8)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  }

  Color _getBackgroundColor() {
    if (_isCompleted) {
      return _getTierColor().withOpacity(0.1);
    }
    if (_isLocked) {
      return Colors.grey[100]!;
    }
    return Colors.white;
  }

  Color _getBorderColor() {
    if (_isCompleted) {
      return _getTierColor();
    }
    if (_isLocked) {
      return Colors.grey[300]!;
    }
    return _getTierColor().withOpacity(0.3);
  }

  double _getBorderWidth() {
    return _isCompleted ? 2.0 : 1.0;
  }

  Color _getShadowColor() {
    if (_isCompleted) {
      return _getTierColor().withOpacity(0.2);
    }
    return Colors.black.withOpacity(0.1);
  }

  Color _getTierColor() {
    return Color(
      int.parse('0xFF${widget.achievement.getTierColorHex().substring(1)}'),
    );
  }

  Color _getTextColor() {
    if (_isLocked) return Colors.grey[600]!;
    return Colors.black87;
  }

  Color _getSecondaryTextColor() {
    if (_isLocked) return Colors.grey[400]!;
    return Colors.grey[600]!;
  }

  Color _getIconBackgroundColor() {
    if (_isCompleted) {
      return _getTierColor();
    }
    if (_isLocked) {
      return Colors.grey[200]!;
    }
    return Colors.white;
  }

  LinearGradient? _getCompletionGradient() {
    final tierColor = _getTierColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [tierColor.withOpacity(0.1), tierColor.withOpacity(0.05)],
    );
  }

  String _getProgressText() {
    if (_isCompleted) return 'Completed!';
    if (_isLocked) return 'Locked';

    return widget.userProgress?.getProgressDescription() ?? 'Not started';
  }

  Color _getProgressTextColor() {
    if (_isCompleted) return Colors.green;
    if (_isLocked) return Colors.grey[400]!;
    return _getTierColor();
  }

  void _handleTapDown() {
    if (!widget.enableAnimations) return;

    setState(() {
      _isPressed = true;
    });
    _bounceController.forward();
    HapticFeedback.lightImpact();
  }

  void _handleTapUp() {
    if (!widget.enableAnimations) return;

    setState(() {
      _isPressed = false;
    });
    _bounceController.reverse();
  }

  void _handleLongPress() {
    HapticFeedback.mediumImpact();

    if (widget.onLongPress != null) {
      widget.onLongPress!();
    } else {
      // Default long press action - share
      _shareAchievement();
    }
  }

  void _shareAchievement() {
    final text = _isCompleted
        ? 'I just unlocked the "${widget.achievement.name}" achievement in Dabbler! 🏆'
        : 'Working on the "${widget.achievement.name}" achievement in Dabbler! ${_progress.toStringAsFixed(0)}% complete 💪';

    Share.share(text);
  }
}
