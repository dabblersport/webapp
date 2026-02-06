/// Types of point transactions in the system
enum TransactionType {
  /// Points earned from completing achievements
  achievement,

  /// Points from game participation
  gameParticipation,

  /// Points from winning games
  gameVictory,

  /// Points from social interactions
  social,

  /// Daily login bonuses
  dailyBonus,

  /// Weekly streak bonuses
  weeklyBonus,

  /// Monthly rewards
  monthlyReward,

  /// Tournament participation
  tournament,

  /// Tournament winnings
  tournamentWin,

  /// Referee points for community contribution
  referee,

  /// Points from inviting friends
  referral,

  /// Special event bonuses
  specialEvent,

  /// Manual adjustments by admin
  adjustment,

  /// Points deducted for penalties
  penalty,

  /// Points spent on rewards/items
  spend,

  /// Refund transactions
  refund,
}

/// Point transaction entity for tracking all point movements
class PointTransaction {
  final String id;
  final String userId;
  final TransactionType type;
  final double basePoints;
  final Map<String, double> multipliersApplied;
  final double finalPoints;
  final double runningBalance;
  final String? referenceId; // Achievement ID, Game ID, etc.
  final String? referenceType; // 'achievement', 'game', 'tournament', etc.
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final bool isReversed;
  final String? reversalReason;
  final DateTime? reversedAt;

  const PointTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.basePoints,
    this.multipliersApplied = const {},
    required this.finalPoints,
    required this.runningBalance,
    this.referenceId,
    this.referenceType,
    required this.description,
    this.metadata,
    required this.createdAt,
    this.isReversed = false,
    this.reversalReason,
    this.reversedAt,
  });

  /// Calculates the total multiplier applied
  double getTotalMultiplier() {
    if (multipliersApplied.isEmpty) return 1.0;

    return multipliersApplied.values.reduce((a, b) => a * b);
  }

  /// Gets a breakdown of multipliers for display
  List<Map<String, dynamic>> getMultiplierBreakdown() {
    return multipliersApplied.entries
        .map(
          (entry) => {
            'name': _formatMultiplierName(entry.key),
            'value': entry.value,
            'formatted': '×${entry.value.toStringAsFixed(2)}',
          },
        )
        .toList();
  }

  String _formatMultiplierName(String key) {
    switch (key) {
      case 'tier_bonus':
        return 'Tier Bonus';
      case 'streak_bonus':
        return 'Streak Bonus';
      case 'weekend_bonus':
        return 'Weekend Bonus';
      case 'event_bonus':
        return 'Event Bonus';
      case 'first_time_bonus':
        return 'First Time Bonus';
      case 'skill_bonus':
        return 'Skill Bonus';
      case 'social_bonus':
        return 'Social Bonus';
      default:
        return key
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) =>
                  word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
            )
            .join(' ');
    }
  }

  /// Gets formatted description with additional context
  String getFormattedDescription() {
    final buffer = StringBuffer();
    buffer.write(description);

    if (referenceType != null && referenceId != null) {
      switch (referenceType) {
        case 'achievement':
          buffer.write(' (Achievement)');
          break;
        case 'game':
          buffer.write(' (Game)');
          break;
        case 'tournament':
          buffer.write(' (Tournament)');
          break;
        default:
          buffer.write(' (${referenceType!})');
      }
    }

    if (isReversed) {
      buffer.write(' [REVERSED]');
    }

    return buffer.toString();
  }

  /// Gets the transaction display icon
  String getTransactionIcon() {
    switch (type) {
      case TransactionType.achievement:
        return 'trophy';
      case TransactionType.gameParticipation:
        return 'play_arrow';
      case TransactionType.gameVictory:
        return 'emoji_events';
      case TransactionType.social:
        return 'people';
      case TransactionType.dailyBonus:
        return 'today';
      case TransactionType.weeklyBonus:
        return 'date_range';
      case TransactionType.monthlyReward:
        return 'calendar_month';
      case TransactionType.tournament:
      case TransactionType.tournamentWin:
        return 'military_tech';
      case TransactionType.referee:
        return 'sports';
      case TransactionType.referral:
        return 'person_add';
      case TransactionType.specialEvent:
        return 'celebration';
      case TransactionType.adjustment:
        return 'tune';
      case TransactionType.penalty:
        return 'warning';
      case TransactionType.spend:
        return 'shopping_cart';
      case TransactionType.refund:
        return 'undo';
    }
  }

  /// Gets the transaction color for UI display
  String getTransactionColor() {
    if (isReversed) return '#808080'; // Gray for reversed

    if (finalPoints >= 0) {
      // Positive transactions
      switch (type) {
        case TransactionType.achievement:
          return '#FFD700'; // Gold
        case TransactionType.gameVictory:
          return '#32CD32'; // Lime Green
        case TransactionType.tournamentWin:
          return '#FF6B35'; // Orange
        case TransactionType.specialEvent:
          return '#8A2BE2'; // Blue Violet
        default:
          return '#4CAF50'; // Green
      }
    } else {
      // Negative transactions
      switch (type) {
        case TransactionType.penalty:
          return '#F44336'; // Red
        case TransactionType.spend:
          return '#2196F3'; // Blue
        default:
          return '#FF9800'; // Orange
      }
    }
  }

  /// Gets the points change with proper formatting
  String getFormattedPointsChange() {
    if (isReversed) return '0';

    final points = finalPoints;
    final prefix = points >= 0 ? '+' : '';
    return '$prefix${points.toStringAsFixed(0)}';
  }

  /// Checks if this is a bonus transaction (has multipliers > 1.0)
  bool hasBonus() {
    return multipliersApplied.values.any((multiplier) => multiplier > 1.0);
  }

  /// Gets bonus percentage if applicable
  double? getBonusPercentage() {
    if (!hasBonus()) return null;

    final totalMultiplier = getTotalMultiplier();
    return (totalMultiplier - 1.0) * 100;
  }

  /// Gets transaction category for grouping
  String getTransactionCategory() {
    switch (type) {
      case TransactionType.achievement:
        return 'Achievements';
      case TransactionType.gameParticipation:
      case TransactionType.gameVictory:
        return 'Games';
      case TransactionType.tournament:
      case TransactionType.tournamentWin:
        return 'Tournaments';
      case TransactionType.social:
      case TransactionType.referral:
        return 'Social';
      case TransactionType.dailyBonus:
      case TransactionType.weeklyBonus:
      case TransactionType.monthlyReward:
        return 'Bonuses';
      case TransactionType.specialEvent:
        return 'Events';
      case TransactionType.referee:
        return 'Community';
      case TransactionType.spend:
      case TransactionType.refund:
        return 'Store';
      case TransactionType.adjustment:
      case TransactionType.penalty:
        return 'Adjustments';
    }
  }

  /// Gets time-based display text (e.g., "2 hours ago")
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Gets summary for transaction aggregation
  Map<String, dynamic> getSummary() {
    return {
      'type': type.name,
      'category': getTransactionCategory(),
      'base_points': basePoints,
      'final_points': finalPoints,
      'has_bonus': hasBonus(),
      'bonus_percentage': getBonusPercentage(),
      'is_reversed': isReversed,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy with updated values
  PointTransaction copyWith({
    String? id,
    String? userId,
    TransactionType? type,
    double? basePoints,
    Map<String, double>? multipliersApplied,
    double? finalPoints,
    double? runningBalance,
    String? referenceId,
    String? referenceType,
    String? description,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    bool? isReversed,
    String? reversalReason,
    DateTime? reversedAt,
  }) {
    return PointTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      basePoints: basePoints ?? this.basePoints,
      multipliersApplied: multipliersApplied ?? this.multipliersApplied,
      finalPoints: finalPoints ?? this.finalPoints,
      runningBalance: runningBalance ?? this.runningBalance,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      isReversed: isReversed ?? this.isReversed,
      reversalReason: reversalReason ?? this.reversalReason,
      reversedAt: reversedAt ?? this.reversedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PointTransaction &&
        other.id == id &&
        other.userId == userId &&
        other.type == type &&
        other.finalPoints == finalPoints;
  }

  @override
  int get hashCode {
    return id.hashCode ^ userId.hashCode ^ type.hashCode ^ finalPoints.hashCode;
  }

  @override
  String toString() {
    return 'PointTransaction(id: $id, type: $type, points: $finalPoints, '
        'balance: $runningBalance)';
  }
}
