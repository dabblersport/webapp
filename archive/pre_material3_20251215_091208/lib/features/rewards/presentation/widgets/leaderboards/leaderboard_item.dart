import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';

/// User data for leaderboard display
class LeaderboardUser {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int points;
  final BadgeTier tier;
  final int rank;
  final int? previousRank;
  final List<Achievement> achievements;
  final bool isFriend;
  final bool isCurrentUser;
  final String? countryCode;
  final String? countryName;
  final DateTime lastActive;
  final int weeklyPoints;
  final int monthlyPoints;
  final double pointsPerDay;

  const LeaderboardUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.points,
    required this.tier,
    required this.rank,
    this.previousRank,
    this.achievements = const [],
    this.isFriend = false,
    this.isCurrentUser = false,
    this.countryCode,
    this.countryName,
    required this.lastActive,
    this.weeklyPoints = 0,
    this.monthlyPoints = 0,
    this.pointsPerDay = 0.0,
  });

  RankMovement get movement {
    if (previousRank == null) return RankMovement.new_entry;
    if (previousRank! > rank) return RankMovement.up;
    if (previousRank! < rank) return RankMovement.down;
    return RankMovement.same;
  }

  int get movementAmount {
    if (previousRank == null) return 0;
    return (previousRank! - rank).abs();
  }

  bool get isTopThree => rank <= 3;

  String get rankMedal {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }
}

enum RankMovement { up, down, same, new_entry }

/// Interactive leaderboard item widget
class LeaderboardItem extends StatefulWidget {
  final LeaderboardUser user;
  final VoidCallback? onTap;
  final Function(String action)? onAction;
  final bool showMovement;
  final bool showCountry;
  final bool showAchievements;
  final bool enableExpansion;
  final bool showFriendIndicator;
  final bool enableHaptics;
  final int? maxDisplayedAchievements;
  final EdgeInsets? padding;

  const LeaderboardItem({
    super.key,
    required this.user,
    this.onTap,
    this.onAction,
    this.showMovement = true,
    this.showCountry = true,
    this.showAchievements = false,
    this.enableExpansion = true,
    this.showFriendIndicator = true,
    this.enableHaptics = true,
    this.maxDisplayedAchievements = 3,
    this.padding,
  });

  @override
  State<LeaderboardItem> createState() => _LeaderboardItemState();
}

class _LeaderboardItemState extends State<LeaderboardItem>
    with TickerProviderStateMixin {
  late AnimationController _movementController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _expansionController;

  late Animation<double> _movementAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _expansionAnimation;

  bool _isExpanded = false;
  bool _showActionsMenu = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _movementController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _movementAnimation = CurvedAnimation(
      parent: _movementController,
      curve: Curves.elasticOut,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOut,
    );

    // Start animations
    if (widget.user.movement != RankMovement.same) {
      _movementController.forward();
    }

    if (widget.user.isCurrentUser) {
      _pulseController.repeat(reverse: true);
    }

    if (widget.user.isTopThree) {
      _shimmerController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _movementController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  Color _getTierColor(BadgeTier tier) {
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

  Color _getRankColor() {
    if (widget.user.isTopThree) {
      switch (widget.user.rank) {
        case 1:
          return const Color(0xFFFFD700); // Gold
        case 2:
          return const Color(0xFFC0C0C0); // Silver
        case 3:
          return const Color(0xFFCD7F32); // Bronze
      }
    }
    return Colors.grey[600]!;
  }

  Color _getMovementColor(RankMovement movement) {
    switch (movement) {
      case RankMovement.up:
        return Colors.green[600]!;
      case RankMovement.down:
        return Colors.red[600]!;
      case RankMovement.new_entry:
        return Colors.blue[600]!;
      case RankMovement.same:
        return Colors.grey[600]!;
    }
  }

  IconData _getMovementIcon(RankMovement movement) {
    switch (movement) {
      case RankMovement.up:
        return Icons.keyboard_arrow_up;
      case RankMovement.down:
        return Icons.keyboard_arrow_down;
      case RankMovement.new_entry:
        return Icons.fiber_new;
      case RankMovement.same:
        return Icons.remove;
    }
  }

  String _getTierName(BadgeTier tier) {
    return tier.toString().split('.').last.toUpperCase();
  }

  void _handleTap() {
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (widget.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _showActionsMenu = !_showActionsMenu;
    });
  }

  void _handleExpansionToggle() {
    if (!widget.enableExpansion) return;

    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _expansionController.forward();
    } else {
      _expansionController.reverse();
    }

    if (widget.enableHaptics) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleAction(String action) {
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _showActionsMenu = false;
    });
    widget.onAction?.call(action);
  }

  Widget _buildCountryFlag() {
    if (!widget.showCountry || widget.user.countryCode == null) {
      return const SizedBox.shrink();
    }

    // Simple country flag representation using emoji flags
    final countryCode = widget.user.countryCode!.toUpperCase();
    String flag = '';

    // Convert country code to flag emoji
    for (int i = 0; i < countryCode.length; i++) {
      flag += String.fromCharCode(0x1F1E6 + countryCode.codeUnitAt(i) - 65);
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Text(flag, style: const TextStyle(fontSize: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _getTierColor(widget.user.tier);
    final rankColor = _getRankColor();

    return AnimatedBuilder(
      animation: widget.user.isCurrentUser
          ? _pulseAnimation
          : _movementAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.user.isCurrentUser ? _pulseAnimation.value : 1.0,
          child: Container(
            margin: widget.padding ?? const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: widget.user.isCurrentUser
                  ? Border.all(color: tierColor, width: 2)
                  : null,
              boxShadow: widget.user.isTopThree
                  ? [
                      BoxShadow(
                        color: rankColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Card(
              elevation: widget.user.isTopThree ? 8 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: _handleTap,
                onLongPress: _handleLongPress,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: [
                    _buildMainRow(),
                    if (_showActionsMenu) _buildActionsMenu(),
                    AnimatedBuilder(
                      animation: _expansionAnimation,
                      builder: (context, child) {
                        return ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: _expansionAnimation.value,
                            child: _buildExpandedContent(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainRow() {
    final theme = Theme.of(context);
    final tierColor = _getTierColor(widget.user.tier);
    final rankColor = _getRankColor();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildRankSection(rankColor),
          const SizedBox(width: 16),
          _buildAvatarSection(),
          const SizedBox(width: 12),
          Expanded(child: _buildUserInfoSection(theme, tierColor)),
          _buildTrailingSection(theme, tierColor),
        ],
      ),
    );
  }

  Widget _buildRankSection(Color rankColor) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: widget.user.isTopThree
                ? rankColor.withOpacity(0.2)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(25),
            border: widget.user.isTopThree
                ? Border.all(color: rankColor, width: 2)
                : Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Center(
            child: widget.user.isTopThree
                ? AnimatedBuilder(
                    animation: _shimmerAnimation,
                    builder: (context, child) {
                      return Text(
                        widget.user.rankMedal,
                        style: TextStyle(
                          fontSize: 24,
                          shadows: [
                            Shadow(
                              color: rankColor.withOpacity(
                                0.5 + 0.5 * _shimmerAnimation.value,
                              ),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Text(
                    '${widget.user.rank}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                    ),
                  ),
          ),
        ),
        if (widget.showMovement) ...[
          const SizedBox(height: 4),
          _buildMovementIndicator(),
        ],
      ],
    );
  }

  Widget _buildMovementIndicator() {
    final movement = widget.user.movement;
    final movementColor = _getMovementColor(movement);
    final movementIcon = _getMovementIcon(movement);

    if (movement == RankMovement.same) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(movementIcon, size: 12, color: Colors.grey[600]),
      );
    }

    return AnimatedBuilder(
      animation: _movementAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _movementAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: movementColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(movementIcon, size: 12, color: movementColor),
                if (widget.user.movementAmount > 0) ...[
                  const SizedBox(width: 2),
                  Text(
                    '${widget.user.movementAmount}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: movementColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarSection() {
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: widget.user.isCurrentUser
                  ? _getTierColor(widget.user.tier)
                  : Colors.grey[300]!,
              width: widget.user.isCurrentUser ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: widget.user.avatarUrl != null
                ? Image.network(
                    widget.user.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildDefaultAvatar(),
                  )
                : _buildDefaultAvatar(),
          ),
        ),
        if (widget.showFriendIndicator && widget.user.isFriend)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.green[600],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.people, size: 12, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    final tierColor = _getTierColor(widget.user.tier);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tierColor.withOpacity(0.3), tierColor.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          widget.user.displayName.isNotEmpty
              ? widget.user.displayName[0].toUpperCase()
              : widget.user.username[0].toUpperCase(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: tierColor,
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoSection(ThemeData theme, Color tierColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildCountryFlag(),
            Expanded(
              child: Text(
                widget.user.displayName.isNotEmpty
                    ? widget.user.displayName
                    : widget.user.username,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.user.isCurrentUser ? tierColor : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.user.isCurrentUser)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'YOU',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: tierColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tierColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getTierName(widget.user.tier),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: tierColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.user.countryName != null)
              Expanded(
                child: Text(
                  widget.user.countryName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrailingSection(ThemeData theme, Color tierColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${widget.user.points}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: tierColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'points',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        if (widget.enableExpansion &&
            (widget.showAchievements && widget.user.achievements.isNotEmpty))
          GestureDetector(
            onTap: _handleExpansionToggle,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionsMenu() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.person,
            label: 'Profile',
            onTap: () => _handleAction('profile'),
          ),
          _buildActionButton(
            icon: Icons.message,
            label: 'Message',
            onTap: () => _handleAction('message'),
          ),
          if (!widget.user.isFriend && !widget.user.isCurrentUser)
            _buildActionButton(
              icon: Icons.person_add,
              label: 'Add Friend',
              onTap: () => _handleAction('add_friend'),
            ),
          _buildActionButton(
            icon: Icons.share,
            label: 'Share',
            onTap: () => _handleAction('share'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    if (!_isExpanded ||
        !widget.showAchievements ||
        widget.user.achievements.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayedAchievements = widget.user.achievements
        .take(widget.maxDisplayedAchievements ?? 3)
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                size: 16,
                color: _getTierColor(widget.user.tier),
              ),
              const SizedBox(width: 8),
              Text(
                'Recent Achievements',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...displayedAchievements.map(
            (achievement) => _buildAchievementItem(achievement),
          ),
          if (widget.user.achievements.length >
              (widget.maxDisplayedAchievements ?? 3)) ...[
            const SizedBox(height: 8),
            Text(
              '+${widget.user.achievements.length - (widget.maxDisplayedAchievements ?? 3)} more achievements',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildUserStats(),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(Achievement achievement) {
    final tierColor = _getTierColor(achievement.tier);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tierColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tierColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tierColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.emoji_events, size: 16, color: tierColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${achievement.points} points',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tierColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStats() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            label: 'Weekly',
            value: '${widget.user.weeklyPoints}',
            theme: theme,
          ),
          _buildStatItem(
            label: 'Monthly',
            value: '${widget.user.monthlyPoints}',
            theme: theme,
          ),
          _buildStatItem(
            label: 'Daily Avg',
            value: '${widget.user.pointsPerDay.toInt()}',
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
