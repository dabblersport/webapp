/// User tier levels representing progression in the system
enum TierLevel {
  freshPlayer(1, 'Fresh Player', 0, 99),
  rookie(2, 'Rookie', 100, 249),
  novice(3, 'Novice', 250, 499),
  amateur(4, 'Amateur', 500, 999),
  enthusiast(5, 'Enthusiast', 1000, 1999),
  competitor(6, 'Competitor', 2000, 3499),
  skilled(7, 'Skilled', 3500, 5999),
  expert(8, 'Expert', 6000, 9999),
  veteran(9, 'Veteran', 10000, 15999),
  elite(10, 'Elite', 16000, 24999),
  master(11, 'Master', 25000, 39999),
  grandmaster(12, 'Grandmaster', 40000, 64999),
  legend(13, 'Legend', 65000, 99999),
  champion(14, 'Champion', 100000, 149999),
  dabbler(15, 'Dabbler', 150000, double.infinity);

  const TierLevel(this.level, this.displayName, this.minPoints, this.maxPoints);

  final int level;
  final String displayName;
  final double minPoints;
  final double maxPoints;

  /// Gets tier by level number
  static TierLevel? fromLevel(int level) {
    for (final tier in TierLevel.values) {
      if (tier.level == level) return tier;
    }
    return null;
  }

  /// Gets tier by point amount
  static TierLevel fromPoints(double points) {
    for (final tier in TierLevel.values) {
      if (points >= tier.minPoints && points <= tier.maxPoints) {
        return tier;
      }
    }
    return TierLevel.dabbler; // Fallback to highest tier
  }

  /// Gets the next tier level
  TierLevel? get nextTier {
    if (level >= 15) return null;
    return fromLevel(level + 1);
  }

  /// Gets the previous tier level
  TierLevel? get previousTier {
    if (level <= 1) return null;
    return fromLevel(level - 1);
  }

  /// Checks if this is the maximum tier
  bool get isMaxTier => level == 15;

  /// Gets the points range as a formatted string
  String get pointsRange {
    if (maxPoints == double.infinity) {
      return '${minPoints.toInt()}+';
    }
    return '${minPoints.toInt()} - ${maxPoints.toInt()}';
  }
}

/// User tier entity representing player progression status
class UserTier {
  final String id;
  final String userId;
  final TierLevel level;
  final double currentPoints;
  final double pointsInTier; // Points within current tier
  final Map<String, dynamic> benefits;
  final Map<String, dynamic> privileges;
  final Map<String, String> customization;
  final DateTime achievedAt;
  final DateTime? previousTierAt;
  final bool hasNotificationSent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserTier({
    required this.id,
    required this.userId,
    required this.level,
    required this.currentPoints,
    required this.pointsInTier,
    this.benefits = const {},
    this.privileges = const {},
    this.customization = const {},
    required this.achievedAt,
    this.previousTierAt,
    this.hasNotificationSent = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Gets the next tier level
  TierLevel? getNextTier() {
    return level.nextTier;
  }

  /// Calculates progress to next tier (0-100%)
  double calculateProgress() {
    final nextTier = getNextTier();
    if (nextTier == null) return 100.0; // Max tier reached

    final pointsInCurrentTier = currentPoints - level.minPoints;
    final pointsNeededForTier = nextTier.minPoints - level.minPoints;

    return (pointsInCurrentTier / pointsNeededForTier * 100).clamp(0.0, 100.0);
  }

  /// Gets points needed for next tier
  double getPointsToNextTier() {
    final nextTier = getNextTier();
    if (nextTier == null) return 0.0;

    return nextTier.minPoints - currentPoints;
  }

  /// Checks if user has a specific privilege
  bool hasPrivilege(String privilege) {
    return privileges.containsKey(privilege) && privileges[privilege] == true;
  }

  /// Gets the tier color for UI display
  String getTierColor() {
    switch (level) {
      case TierLevel.freshPlayer:
        return '#8B4513'; // Brown
      case TierLevel.rookie:
        return '#CD7F32'; // Bronze
      case TierLevel.novice:
        return '#C0C0C0'; // Silver
      case TierLevel.amateur:
        return '#FFD700'; // Gold
      case TierLevel.enthusiast:
        return '#50C878'; // Emerald
      case TierLevel.competitor:
        return '#4169E1'; // Royal Blue
      case TierLevel.skilled:
        return '#8A2BE2'; // Blue Violet
      case TierLevel.expert:
        return '#FF6347'; // Tomato
      case TierLevel.veteran:
        return '#FF1493'; // Deep Pink
      case TierLevel.elite:
        return '#00CED1'; // Dark Turquoise
      case TierLevel.master:
        return '#FF4500'; // Orange Red
      case TierLevel.grandmaster:
        return '#DC143C'; // Crimson
      case TierLevel.legend:
        return '#8B0000'; // Dark Red
      case TierLevel.champion:
        return '#FFD700'; // Gold (enhanced)
      case TierLevel.dabbler:
        return '#FF6B35'; // Legendary Orange
    }
  }

  /// Gets the tier icon name
  String getTierIcon() {
    switch (level) {
      case TierLevel.freshPlayer:
        return 'seedling';
      case TierLevel.rookie:
        return 'star';
      case TierLevel.novice:
        return 'shield';
      case TierLevel.amateur:
        return 'medal';
      case TierLevel.enthusiast:
        return 'fire';
      case TierLevel.competitor:
        return 'sword';
      case TierLevel.skilled:
        return 'gem';
      case TierLevel.expert:
        return 'crown';
      case TierLevel.veteran:
        return 'mountain';
      case TierLevel.elite:
        return 'diamond';
      case TierLevel.master:
        return 'scroll';
      case TierLevel.grandmaster:
        return 'wings';
      case TierLevel.legend:
        return 'phoenix';
      case TierLevel.champion:
        return 'trophy';
      case TierLevel.dabbler:
        return 'infinity';
    }
  }

  /// Gets default benefits for the tier
  Map<String, dynamic> getDefaultBenefits() {
    final baseBenefits = <String, dynamic>{
      'daily_point_bonus': _getDailyPointBonus(),
      'achievement_point_multiplier': _getAchievementMultiplier(),
      'leaderboard_highlight': level.level >= 6,
      'custom_profile_themes': level.level >= 4,
      'priority_matchmaking': level.level >= 8,
      'exclusive_events_access': level.level >= 10,
      'early_feature_access': level.level >= 12,
    };

    // Add tier-specific benefits
    if (level.level >= 3) {
      baseBenefits['profile_customization_slots'] = (level.level / 3).ceil();
    }

    if (level.level >= 5) {
      baseBenefits['monthly_exclusive_rewards'] = true;
    }

    if (level.level >= 7) {
      baseBenefits['tournament_seed_bonus'] = true;
    }

    if (level.level >= 11) {
      baseBenefits['mentor_program_access'] = true;
    }

    if (level.level >= 13) {
      baseBenefits['legend_only_competitions'] = true;
    }

    return baseBenefits;
  }

  int _getDailyPointBonus() {
    return (level.level * 5).clamp(5, 75);
  }

  double _getAchievementMultiplier() {
    return 1.0 + (level.level - 1) * 0.05;
  }

  /// Gets default privileges for the tier
  Map<String, dynamic> getDefaultPrivileges() {
    return {
      'create_private_tournaments': level.level >= 6,
      'invite_friends_to_events': level.level >= 4,
      'access_advanced_statistics': level.level >= 8,
      'custom_game_settings': level.level >= 10,
      'priority_customer_support': level.level >= 12,
      'beta_testing_participation': level.level >= 14,
      'influence_game_development': level.level >= 15,
    };
  }

  /// Gets tier progression summary
  Map<String, dynamic> getProgressionSummary() {
    final nextTier = getNextTier();
    final progress = calculateProgress();

    return {
      'current_tier': {
        'level': level.level,
        'name': level.displayName,
        'color': getTierColor(),
        'icon': getTierIcon(),
      },
      'points': {
        'current': currentPoints,
        'in_tier': pointsInTier,
        'tier_range': level.pointsRange,
      },
      'progress': {
        'percentage': progress,
        'points_to_next': nextTier != null ? getPointsToNextTier() : 0,
        'next_tier': nextTier?.displayName,
        'is_max_tier': level.isMaxTier,
      },
    };
  }

  /// Gets formatted tier display text
  String getFormattedTierText() {
    return '${level.displayName} (Level ${level.level})';
  }

  /// Creates a copy with updated values
  UserTier copyWith({
    String? id,
    String? userId,
    TierLevel? level,
    double? currentPoints,
    double? pointsInTier,
    Map<String, dynamic>? benefits,
    Map<String, dynamic>? privileges,
    Map<String, String>? customization,
    DateTime? achievedAt,
    DateTime? previousTierAt,
    bool? hasNotificationSent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserTier(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      level: level ?? this.level,
      currentPoints: currentPoints ?? this.currentPoints,
      pointsInTier: pointsInTier ?? this.pointsInTier,
      benefits: benefits ?? this.benefits,
      privileges: privileges ?? this.privileges,
      customization: customization ?? this.customization,
      achievedAt: achievedAt ?? this.achievedAt,
      previousTierAt: previousTierAt ?? this.previousTierAt,
      hasNotificationSent: hasNotificationSent ?? this.hasNotificationSent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserTier &&
        other.id == id &&
        other.userId == userId &&
        other.level == level;
  }

  @override
  int get hashCode {
    return id.hashCode ^ userId.hashCode ^ level.hashCode;
  }

  @override
  String toString() {
    return 'UserTier(id: $id, userId: $userId, level: ${level.displayName}, '
        'points: $currentPoints, progress: ${calculateProgress().toStringAsFixed(1)}%)';
  }
}
