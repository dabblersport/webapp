import 'tier.dart';

/// Movement direction for leaderboard ranking changes
enum RankMovement {
  /// Rank improved (moved up)
  up,

  /// Rank declined (moved down)
  down,

  /// Rank stayed the same
  same,

  /// New entry (first time on leaderboard)
  newEntry,

  /// Returned to leaderboard after absence
  returned,
}

/// Time period for leaderboard entries
enum LeaderboardPeriod { daily, weekly, monthly, yearly, allTime }

/// Leaderboard entry entity representing a user's position and stats
class LeaderboardEntry {
  final String id;
  final String userId;
  final String username;
  final String? avatarUrl;
  final int currentRank;
  final int? previousRank;
  final double totalPoints;
  final double periodPoints; // Points for the specific leaderboard period
  final TierLevel tier;
  final Map<String, double>
  pointsByCategory; // e.g., {'basketball': 1500, 'football': 800}
  final List<String> recentAchievements; // Achievement IDs
  final RankMovement movement;
  final int movementAmount; // How many positions moved
  final LeaderboardPeriod period;
  final DateTime lastActiveAt;
  final DateTime entryCreatedAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  const LeaderboardEntry({
    required this.id,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.currentRank,
    this.previousRank,
    required this.totalPoints,
    required this.periodPoints,
    required this.tier,
    this.pointsByCategory = const {},
    this.recentAchievements = const [],
    required this.movement,
    this.movementAmount = 0,
    required this.period,
    required this.lastActiveAt,
    required this.entryCreatedAt,
    required this.updatedAt,
    this.metadata,
  });

  /// Gets formatted rank with proper suffix (1st, 2nd, 3rd, etc.)
  String getFormattedRank() {
    final rank = currentRank;
    if (rank % 100 >= 11 && rank % 100 <= 13) {
      return '${rank}th';
    }

    switch (rank % 10) {
      case 1:
        return '${rank}st';
      case 2:
        return '${rank}nd';
      case 3:
        return '${rank}rd';
      default:
        return '${rank}th';
    }
  }

  /// Checks if the user has improved their rank
  bool hasImproved() {
    return movement == RankMovement.up;
  }

  /// Checks if this is a podium position (top 3)
  bool isPodiumPosition() {
    return currentRank <= 3;
  }

  /// Checks if this is a top 10 position
  bool isTopTen() {
    return currentRank <= 10;
  }

  /// Gets the movement description for display
  String getMovementDescription() {
    switch (movement) {
      case RankMovement.up:
        return movementAmount > 0
            ? 'Up $movementAmount position${movementAmount == 1 ? '' : 's'}'
            : 'Improved';
      case RankMovement.down:
        return movementAmount > 0
            ? 'Down $movementAmount position${movementAmount == 1 ? '' : 's'}'
            : 'Declined';
      case RankMovement.same:
        return 'No change';
      case RankMovement.newEntry:
        return 'New entry';
      case RankMovement.returned:
        return 'Returned';
    }
  }

  /// Gets the movement icon for UI display
  String getMovementIcon() {
    switch (movement) {
      case RankMovement.up:
        return 'trending_up';
      case RankMovement.down:
        return 'trending_down';
      case RankMovement.same:
        return 'trending_flat';
      case RankMovement.newEntry:
        return 'fiber_new';
      case RankMovement.returned:
        return 'refresh';
    }
  }

  /// Gets the movement color for UI display
  String getMovementColor() {
    switch (movement) {
      case RankMovement.up:
        return '#4CAF50'; // Green
      case RankMovement.down:
        return '#F44336'; // Red
      case RankMovement.same:
        return '#9E9E9E'; // Gray
      case RankMovement.newEntry:
        return '#2196F3'; // Blue
      case RankMovement.returned:
        return '#FF9800'; // Orange
    }
  }

  /// Gets the rank badge color based on position
  String getRankBadgeColor() {
    switch (currentRank) {
      case 1:
        return '#FFD700'; // Gold
      case 2:
        return '#C0C0C0'; // Silver
      case 3:
        return '#CD7F32'; // Bronze
      default:
        if (currentRank <= 10) {
          return '#4CAF50'; // Green for top 10
        } else if (currentRank <= 50) {
          return '#2196F3'; // Blue for top 50
        } else {
          return '#9E9E9E'; // Gray for others
        }
    }
  }

  /// Gets points breakdown as formatted strings
  Map<String, String> getFormattedPointsBreakdown() {
    final breakdown = <String, String>{};

    for (final entry in pointsByCategory.entries) {
      final category = entry.key;
      final points = entry.value;
      final percentage = totalPoints > 0 ? (points / totalPoints * 100) : 0;

      breakdown[_formatCategoryName(category)] =
          '${points.toStringAsFixed(0)} pts (${percentage.toStringAsFixed(1)}%)';
    }

    return breakdown;
  }

  String _formatCategoryName(String category) {
    return category
        .split('_')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  /// Gets the dominant category (highest points)
  String? getDominantCategory() {
    if (pointsByCategory.isEmpty) return null;

    final entry = pointsByCategory.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    return _formatCategoryName(entry.key);
  }

  /// Gets activity status description
  String getActivityStatus() {
    final now = DateTime.now();
    final daysSinceActive = now.difference(lastActiveAt).inDays;

    if (daysSinceActive == 0) {
      return 'Active today';
    } else if (daysSinceActive == 1) {
      return 'Active yesterday';
    } else if (daysSinceActive <= 7) {
      return 'Active this week';
    } else if (daysSinceActive <= 30) {
      return 'Active this month';
    } else {
      return 'Inactive';
    }
  }

  /// Checks if user is currently active (active within last 7 days)
  bool isActiveUser() {
    final daysSinceActive = DateTime.now().difference(lastActiveAt).inDays;
    return daysSinceActive <= 7;
  }

  /// Gets the period display name
  String getPeriodDisplayName() {
    switch (period) {
      case LeaderboardPeriod.daily:
        return 'Daily';
      case LeaderboardPeriod.weekly:
        return 'Weekly';
      case LeaderboardPeriod.monthly:
        return 'Monthly';
      case LeaderboardPeriod.yearly:
        return 'Yearly';
      case LeaderboardPeriod.allTime:
        return 'All Time';
    }
  }

  /// Gets leaderboard entry summary for display
  Map<String, dynamic> getSummary() {
    return {
      'user': {
        'id': userId,
        'username': username,
        'avatar_url': avatarUrl,
        'tier': tier.displayName,
        'is_active': isActiveUser(),
      },
      'ranking': {
        'current_rank': currentRank,
        'previous_rank': previousRank,
        'formatted_rank': getFormattedRank(),
        'is_podium': isPodiumPosition(),
        'is_top_ten': isTopTen(),
      },
      'points': {
        'total_points': totalPoints,
        'period_points': periodPoints,
        'dominant_category': getDominantCategory(),
        'categories_breakdown': getFormattedPointsBreakdown(),
      },
      'movement': {
        'direction': movement.name,
        'amount': movementAmount,
        'description': getMovementDescription(),
        'color': getMovementColor(),
      },
      'meta': {
        'period': getPeriodDisplayName(),
        'activity_status': getActivityStatus(),
        'recent_achievements_count': recentAchievements.length,
      },
    };
  }

  /// Gets display title based on rank and achievements
  String getDisplayTitle() {
    if (isPodiumPosition()) {
      switch (currentRank) {
        case 1:
          return '🥇 Champion';
        case 2:
          return '🥈 Runner-up';
        case 3:
          return '🥉 Third Place';
      }
    }

    if (isTopTen()) {
      return '⭐ Top Player';
    }

    if (currentRank <= 50) {
      return '🔥 Rising Star';
    }

    return '🎮 Player';
  }

  /// Creates a copy with updated values
  LeaderboardEntry copyWith({
    String? id,
    String? userId,
    String? username,
    String? avatarUrl,
    int? currentRank,
    int? previousRank,
    double? totalPoints,
    double? periodPoints,
    TierLevel? tier,
    Map<String, double>? pointsByCategory,
    List<String>? recentAchievements,
    RankMovement? movement,
    int? movementAmount,
    LeaderboardPeriod? period,
    DateTime? lastActiveAt,
    DateTime? entryCreatedAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return LeaderboardEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currentRank: currentRank ?? this.currentRank,
      previousRank: previousRank ?? this.previousRank,
      totalPoints: totalPoints ?? this.totalPoints,
      periodPoints: periodPoints ?? this.periodPoints,
      tier: tier ?? this.tier,
      pointsByCategory: pointsByCategory ?? this.pointsByCategory,
      recentAchievements: recentAchievements ?? this.recentAchievements,
      movement: movement ?? this.movement,
      movementAmount: movementAmount ?? this.movementAmount,
      period: period ?? this.period,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      entryCreatedAt: entryCreatedAt ?? this.entryCreatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LeaderboardEntry &&
        other.id == id &&
        other.userId == userId &&
        other.currentRank == currentRank &&
        other.period == period;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        currentRank.hashCode ^
        period.hashCode;
  }

  @override
  String toString() {
    return 'LeaderboardEntry(id: $id, userId: $userId, rank: $currentRank, '
        'points: $totalPoints, tier: ${tier.displayName})';
  }
}
