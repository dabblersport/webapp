/// Types of leaderboards available in the system
enum LeaderboardType {
  global('global', 'Global Leaderboard'),
  friends('friends', 'Friends Leaderboard'),
  local('local', 'Local Area Leaderboard'),
  category('category', 'Category Leaderboard'),
  challenge('challenge', 'Challenge Leaderboard');

  const LeaderboardType(this.value, this.displayName);

  final String value;
  final String displayName;
}

/// Time periods for leaderboard rankings
enum LeaderboardPeriod {
  daily('daily', 'Today'),
  weekly('weekly', 'This Week'),
  monthly('monthly', 'This Month'),
  quarterly('quarterly', 'This Quarter'),
  yearly('yearly', 'This Year'),
  allTime('all_time', 'All Time');

  const LeaderboardPeriod(this.value, this.displayName);

  final String value;
  final String displayName;
}

/// Single entry in a leaderboard
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int rank;
  final int previousRank;
  final double score;
  final double previousScore;
  final Map<String, dynamic> stats;
  final DateTime lastUpdated;
  final bool isCurrentUser;
  final Map<String, dynamic> badges;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.rank,
    required this.previousRank,
    required this.score,
    required this.previousScore,
    this.stats = const {},
    required this.lastUpdated,
    this.isCurrentUser = false,
    this.badges = const {},
  });

  /// Gets rank change from previous period
  int get rankChange => previousRank - rank;

  /// Gets score change from previous period
  double get scoreChange => score - previousScore;

  /// Whether user moved up in rankings
  bool get movedUp => rankChange > 0;

  /// Whether user moved down in rankings
  bool get movedDown => rankChange < 0;

  /// Whether user rank is unchanged
  bool get rankUnchanged => rankChange == 0;

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'rank': rank,
      'previous_rank': previousRank,
      'score': score,
      'previous_score': previousScore,
      'stats': stats,
      'last_updated': lastUpdated.toIso8601String(),
      'is_current_user': isCurrentUser,
      'badges': badges,
    };
  }

  /// Create from JSON
  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      rank: json['rank'] as int,
      previousRank: json['previous_rank'] as int? ?? json['rank'] as int,
      score: (json['score'] as num).toDouble(),
      previousScore: (json['previous_score'] as num?)?.toDouble() ?? 0.0,
      stats: json['stats'] as Map<String, dynamic>? ?? {},
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      isCurrentUser: json['is_current_user'] as bool? ?? false,
      badges: json['badges'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Create a copy with modifications
  LeaderboardEntry copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    int? rank,
    int? previousRank,
    double? score,
    double? previousScore,
    Map<String, dynamic>? stats,
    DateTime? lastUpdated,
    bool? isCurrentUser,
    Map<String, dynamic>? badges,
  }) {
    return LeaderboardEntry(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rank: rank ?? this.rank,
      previousRank: previousRank ?? this.previousRank,
      score: score ?? this.score,
      previousScore: previousScore ?? this.previousScore,
      stats: stats ?? this.stats,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      badges: badges ?? this.badges,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaderboardEntry &&
        other.userId == userId &&
        other.rank == rank;
  }

  @override
  int get hashCode => Object.hash(userId, rank);
}

/// Complete leaderboard with metadata
class Leaderboard {
  final String id;
  final LeaderboardType type;
  final LeaderboardPeriod period;
  final String? categoryFilter;
  final List<LeaderboardEntry> entries;
  final int totalParticipants;
  final int currentPage;
  final int totalPages;
  final DateTime lastUpdated;
  final Map<String, dynamic> metadata;

  const Leaderboard({
    required this.id,
    required this.type,
    required this.period,
    this.categoryFilter,
    required this.entries,
    required this.totalParticipants,
    required this.currentPage,
    required this.totalPages,
    required this.lastUpdated,
    this.metadata = const {},
  });

  /// Whether there are more pages available
  bool get hasNextPage => currentPage < totalPages;

  /// Whether there are previous pages
  bool get hasPreviousPage => currentPage > 1;

  /// Get the top entry (rank 1)
  LeaderboardEntry? get topEntry {
    return entries.isNotEmpty ? entries.first : null;
  }

  /// Find entry for specific user
  LeaderboardEntry? findUserEntry(String userId) {
    try {
      return entries.firstWhere((entry) => entry.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Get entries in a specific rank range
  List<LeaderboardEntry> getEntriesInRange(int startRank, int endRank) {
    return entries
        .where((entry) => entry.rank >= startRank && entry.rank <= endRank)
        .toList();
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'period': period.value,
      'category_filter': categoryFilter,
      'entries': entries.map((e) => e.toJson()).toList(),
      'total_participants': totalParticipants,
      'current_page': currentPage,
      'total_pages': totalPages,
      'last_updated': lastUpdated.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory Leaderboard.fromJson(Map<String, dynamic> json) {
    return Leaderboard(
      id: json['id'] as String,
      type: LeaderboardType.values.firstWhere(
        (t) => t.value == json['type'],
        orElse: () => LeaderboardType.global,
      ),
      period: LeaderboardPeriod.values.firstWhere(
        (p) => p.value == json['period'],
        orElse: () => LeaderboardPeriod.allTime,
      ),
      categoryFilter: json['category_filter'] as String?,
      entries: (json['entries'] as List)
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalParticipants: json['total_participants'] as int? ?? 0,
      currentPage: json['current_page'] as int? ?? 1,
      totalPages: json['total_pages'] as int? ?? 1,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// User's rank information
class UserRank {
  final String userId;
  final int rank;
  final int previousRank;
  final double score;
  final double previousScore;
  final int totalParticipants;
  final double percentile;
  final LeaderboardType type;
  final LeaderboardPeriod period;
  final DateTime lastUpdated;

  const UserRank({
    required this.userId,
    required this.rank,
    required this.previousRank,
    required this.score,
    required this.previousScore,
    required this.totalParticipants,
    required this.percentile,
    required this.type,
    required this.period,
    required this.lastUpdated,
  });

  /// Gets rank change from previous period
  int get rankChange => previousRank - rank;

  /// Gets score change from previous period
  double get scoreChange => score - previousScore;

  /// Whether user moved up in rankings
  bool get movedUp => rankChange > 0;

  /// Whether user moved down in rankings
  bool get movedDown => rankChange < 0;

  /// Whether user rank is unchanged
  bool get rankUnchanged => rankChange == 0;

  /// Whether user is in top 10%
  bool get isTopTier => percentile >= 90.0;

  /// Whether user is in top 25%
  bool get isHighPerformer => percentile >= 75.0;

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'rank': rank,
      'previous_rank': previousRank,
      'score': score,
      'previous_score': previousScore,
      'total_participants': totalParticipants,
      'percentile': percentile,
      'type': type.value,
      'period': period.value,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  /// Create from JSON
  factory UserRank.fromJson(Map<String, dynamic> json) {
    return UserRank(
      userId: json['user_id'] as String,
      rank: json['rank'] as int,
      previousRank: json['previous_rank'] as int? ?? json['rank'] as int,
      score: (json['score'] as num).toDouble(),
      previousScore: (json['previous_score'] as num?)?.toDouble() ?? 0.0,
      totalParticipants: json['total_participants'] as int,
      percentile: (json['percentile'] as num?)?.toDouble() ?? 0.0,
      type: LeaderboardType.values.firstWhere(
        (t) => t.value == json['type'],
        orElse: () => LeaderboardType.global,
      ),
      period: LeaderboardPeriod.values.firstWhere(
        (p) => p.value == json['period'],
        orElse: () => LeaderboardPeriod.allTime,
      ),
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }
}

/// Leaderboard statistics
class LeaderboardStats {
  final int totalParticipants;
  final double averageScore;
  final double topScore;
  final DateTime lastUpdated;
  final LeaderboardType type;
  final LeaderboardPeriod period;
  final Map<String, dynamic> distribution;

  const LeaderboardStats({
    required this.totalParticipants,
    required this.averageScore,
    required this.topScore,
    required this.lastUpdated,
    required this.type,
    required this.period,
    this.distribution = const {},
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'total_participants': totalParticipants,
      'average_score': averageScore,
      'top_score': topScore,
      'last_updated': lastUpdated.toIso8601String(),
      'type': type.value,
      'period': period.value,
      'distribution': distribution,
    };
  }

  /// Create from JSON
  factory LeaderboardStats.fromJson(Map<String, dynamic> json) {
    return LeaderboardStats(
      totalParticipants: json['total_participants'] as int? ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      topScore: (json['top_score'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      type: LeaderboardType.values.firstWhere(
        (t) => t.value == json['type'],
        orElse: () => LeaderboardType.global,
      ),
      period: LeaderboardPeriod.values.firstWhere(
        (p) => p.value == json['period'],
        orElse: () => LeaderboardPeriod.allTime,
      ),
      distribution: json['distribution'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Historical rank data for a user
class UserRankHistory {
  final String id;
  final String userId;
  final int rank;
  final double score;
  final LeaderboardType type;
  final LeaderboardPeriod period;
  final DateTime recordedAt;

  const UserRankHistory({
    required this.id,
    required this.userId,
    required this.rank,
    required this.score,
    required this.type,
    required this.period,
    required this.recordedAt,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'rank': rank,
      'score': score,
      'leaderboard_type': type.value,
      'period': period.value,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory UserRankHistory.fromJson(Map<String, dynamic> json) {
    return UserRankHistory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      rank: json['rank'] as int,
      score: (json['score'] as num).toDouble(),
      type: LeaderboardType.values.firstWhere(
        (t) => t.value == json['leaderboard_type'],
        orElse: () => LeaderboardType.global,
      ),
      period: LeaderboardPeriod.values.firstWhere(
        (p) => p.value == json['period'],
        orElse: () => LeaderboardPeriod.allTime,
      ),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }
}
