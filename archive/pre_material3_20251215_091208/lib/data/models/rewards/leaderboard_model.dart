import 'package:dabbler/data/models/rewards/leaderboard.dart';

/// Tier level for leaderboard entries
enum TierLevel {
  competitor,
  bronze,
  silver,
  gold,
  platinum,
  diamond;

  String get displayName {
    switch (this) {
      case TierLevel.competitor:
        return 'Competitor';
      case TierLevel.bronze:
        return 'Bronze';
      case TierLevel.silver:
        return 'Silver';
      case TierLevel.gold:
        return 'Gold';
      case TierLevel.platinum:
        return 'Platinum';
      case TierLevel.diamond:
        return 'Diamond';
    }
  }
}

/// Rank movement indicator
enum RankMovement {
  up,
  down,
  same,
  newEntry,
  returned;

  String get displayName {
    switch (this) {
      case RankMovement.up:
        return 'Up';
      case RankMovement.down:
        return 'Down';
      case RankMovement.same:
        return 'Same';
      case RankMovement.newEntry:
        return 'New Entry';
      case RankMovement.returned:
        return 'Returned';
    }
  }
}

/// Data model for paginated leaderboard responses
class LeaderboardModel {
  final List<LeaderboardEntryModel> entries;
  final LeaderboardPeriod period;
  final int totalEntries;
  final int currentPage;
  final int pageSize;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final DateTime cacheTimestamp;
  final Duration cacheExpiry;
  final Map<String, dynamic> filterMetadata;
  final Map<String, dynamic> sortMetadata;
  final Map<String, dynamic> aggregateStats;

  const LeaderboardModel({
    required this.entries,
    required this.period,
    required this.totalEntries,
    required this.currentPage,
    required this.pageSize,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.cacheTimestamp,
    required this.cacheExpiry,
    this.filterMetadata = const {},
    this.sortMetadata = const {},
    this.aggregateStats = const {},
  });

  /// Creates a LeaderboardModel from JSON
  factory LeaderboardModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardModel(
      entries: (json['entries'] as List<dynamic>? ?? [])
          .map(
            (entry) =>
                LeaderboardEntryModel.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      period: _parseLeaderboardPeriod(json['period']),
      totalEntries: json['total_entries'] as int? ?? 0,
      currentPage: json['current_page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 25,
      totalPages: json['total_pages'] as int? ?? 1,
      hasNextPage: json['has_next_page'] as bool? ?? false,
      hasPreviousPage: json['has_previous_page'] as bool? ?? false,
      cacheTimestamp: _parseDateTime(json['cache_timestamp']) ?? DateTime.now(),
      cacheExpiry: _parseDuration(json['cache_expiry']),
      filterMetadata: _parseMap(json['filter_metadata']),
      sortMetadata: _parseMap(json['sort_metadata']),
      aggregateStats: _parseMap(json['aggregate_stats']),
    );
  }

  /// Converts the model to JSON
  Map<String, dynamic> toJson() {
    return {
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'period': period.name,
      'total_entries': totalEntries,
      'current_page': currentPage,
      'page_size': pageSize,
      'total_pages': totalPages,
      'has_next_page': hasNextPage,
      'has_previous_page': hasPreviousPage,
      'cache_timestamp': cacheTimestamp.toIso8601String(),
      'cache_expiry': cacheExpiry.inMilliseconds,
      'filter_metadata': filterMetadata,
      'sort_metadata': sortMetadata,
      'aggregate_stats': aggregateStats,
    };
  }

  // Static parsing methods

  static LeaderboardPeriod _parseLeaderboardPeriod(dynamic value) {
    if (value == null) return LeaderboardPeriod.allTime;

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'daily':
          return LeaderboardPeriod.daily;
        case 'weekly':
          return LeaderboardPeriod.weekly;
        case 'monthly':
          return LeaderboardPeriod.monthly;
        case 'yearly':
          return LeaderboardPeriod.yearly;
        case 'all_time':
        case 'alltime':
          return LeaderboardPeriod.allTime;
        default:
          return LeaderboardPeriod.allTime;
      }
    }

    return LeaderboardPeriod.allTime;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    if (value is DateTime) return value;
    return null;
  }

  static Duration _parseDuration(dynamic value) {
    if (value == null) return const Duration(minutes: 15);
    if (value is int) return Duration(milliseconds: value);
    if (value is String) {
      final milliseconds = int.tryParse(value);
      if (milliseconds != null) {
        return Duration(milliseconds: milliseconds);
      }
    }
    return const Duration(minutes: 15);
  }

  static Map<String, dynamic> _parseMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  /// Checks if cache is still valid
  bool get isCacheValid {
    return DateTime.now().difference(cacheTimestamp) < cacheExpiry;
  }

  /// Gets pagination info
  Map<String, dynamic> get paginationInfo {
    return {
      'current_page': currentPage,
      'total_pages': totalPages,
      'page_size': pageSize,
      'total_entries': totalEntries,
      'has_next_page': hasNextPage,
      'has_previous_page': hasPreviousPage,
      'start_rank': ((currentPage - 1) * pageSize) + 1,
      'end_rank': (currentPage * pageSize).clamp(1, totalEntries),
    };
  }

  /// Gets leaderboard summary
  Map<String, dynamic> get summary {
    return {
      'period': period.name,
      'period_display': _getPeriodDisplayName(),
      'total_entries': totalEntries,
      'cache_status': isCacheValid ? 'valid' : 'expired',
      'last_updated': cacheTimestamp.toIso8601String(),
      'entries_count': entries.length,
      'top_score': entries.isNotEmpty ? entries.first.score : 0,
      'average_score': _calculateAverageScore(),
      'active_users': entries.where((e) => e.isActiveUser).length,
    };
  }

  double _calculateAverageScore() {
    if (entries.isEmpty) return 0.0;
    final totalPoints = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.score,
    );
    return totalPoints / entries.length;
  }

  String _getPeriodDisplayName() {
    switch (period) {
      case LeaderboardPeriod.daily:
        return 'Daily';
      case LeaderboardPeriod.weekly:
        return 'Weekly';
      case LeaderboardPeriod.monthly:
        return 'Monthly';
      case LeaderboardPeriod.quarterly:
        return 'Quarterly';
      case LeaderboardPeriod.yearly:
        return 'Yearly';
      case LeaderboardPeriod.allTime:
        return 'All Time';
    }
  }

  /// Creates a copy with updated values
  LeaderboardModel copyWith({
    List<LeaderboardEntryModel>? entries,
    LeaderboardPeriod? period,
    int? totalEntries,
    int? currentPage,
    int? pageSize,
    int? totalPages,
    bool? hasNextPage,
    bool? hasPreviousPage,
    DateTime? cacheTimestamp,
    Duration? cacheExpiry,
    Map<String, dynamic>? filterMetadata,
    Map<String, dynamic>? sortMetadata,
    Map<String, dynamic>? aggregateStats,
  }) {
    return LeaderboardModel(
      entries: entries ?? this.entries,
      period: period ?? this.period,
      totalEntries: totalEntries ?? this.totalEntries,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalPages: totalPages ?? this.totalPages,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      cacheTimestamp: cacheTimestamp ?? this.cacheTimestamp,
      cacheExpiry: cacheExpiry ?? this.cacheExpiry,
      filterMetadata: filterMetadata ?? this.filterMetadata,
      sortMetadata: sortMetadata ?? this.sortMetadata,
      aggregateStats: aggregateStats ?? this.aggregateStats,
    );
  }

  /// Creates a mock LeaderboardModel for testing
  factory LeaderboardModel.mock({
    LeaderboardPeriod period = LeaderboardPeriod.allTime,
    int entryCount = 10,
    int currentPage = 1,
    int pageSize = 25,
  }) {
    final mockEntries = List.generate(entryCount, (index) {
      return LeaderboardEntryModel.mock(
        rank: index + 1,
        score: 1000 - (index * 50).toDouble(),
        userId: 'user_${index + 1}',
        displayName: 'Player ${index + 1}',
      );
    });

    return LeaderboardModel(
      entries: mockEntries,
      period: period,
      totalEntries: entryCount,
      currentPage: currentPage,
      pageSize: pageSize,
      totalPages: (entryCount / pageSize).ceil(),
      hasNextPage: currentPage * pageSize < entryCount,
      hasPreviousPage: currentPage > 1,
      cacheTimestamp: DateTime.now(),
      cacheExpiry: const Duration(minutes: 15),
    );
  }

  /// Updates cache timestamp
  LeaderboardModel updateCache() {
    return copyWith(cacheTimestamp: DateTime.now());
  }

  /// Finds a user's entry in the leaderboard
  LeaderboardEntryModel? findUserEntry(String userId) {
    try {
      return entries.firstWhere((entry) => entry.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Gets entries by tier (simplified - returns all entries since no tier field)
  List<LeaderboardEntryModel> getEntriesByTier(TierLevel tier) {
    // Simplified since current model doesn't have tier field
    return entries;
  }

  /// Gets podium entries (top 3)
  List<LeaderboardEntryModel> get podiumEntries {
    return entries.where((entry) => entry.isPodiumPosition).toList();
  }

  /// Gets tier distribution
  Map<String, int> get tierDistribution {
    final distribution = <String, int>{};

    for (final entry in entries) {
      // Use entry to determine tier (simplified for now)
      final tierName = entry.score > 500 ? 'high' : 'general';
      distribution[tierName] = (distribution[tierName] ?? 0) + 1;
    }

    return distribution;
  }

  /// Gets movement statistics
  Map<String, int> get movementStats {
    final stats = <String, int>{
      'improved': 0,
      'declined': 0,
      'same': 0,
      'new_entries': 0,
      'returned': 0,
    };

    for (final entry in entries) {
      // Calculate movement from rank comparison
      if (entry.previousRank > entry.rank) {
        stats['improved'] = (stats['improved'] ?? 0) + 1;
      } else if (entry.previousRank < entry.rank) {
        stats['declined'] = (stats['declined'] ?? 0) + 1;
      } else {
        stats['same'] = (stats['same'] ?? 0) + 1;
      }
    }

    return stats;
  }
}

/// Data model for LeaderboardEntry with JSON serialization
class LeaderboardEntryModel {
  final String id;
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

  /// Additional model-specific properties
  final DateTime? cacheTimestamp;
  final Map<String, dynamic> trackingData;

  const LeaderboardEntryModel({
    required this.id,
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
    this.cacheTimestamp,
    this.trackingData = const {},
  });

  /// Creates a LeaderboardEntryModel from JSON
  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      id: json['id'] as String? ?? json['user_id'] as String,
      userId: json['user_id'] as String,
      displayName:
          json['display_name'] as String? ??
          json['username'] as String? ??
          'Unknown',
      avatarUrl: json['avatar_url'] as String?,
      rank: json['rank'] as int? ?? json['current_rank'] as int? ?? 0,
      previousRank: json['previous_rank'] as int? ?? 0,
      score: _parseDouble(json['score'] ?? json['total_points'] ?? 0),
      previousScore: _parseDouble(json['previous_score'] ?? 0),
      stats: _parseMap(json['stats']),
      lastUpdated:
          _parseDateTime(json['last_updated'] ?? json['updated_at']) ??
          DateTime.now(),
      isCurrentUser: json['is_current_user'] as bool? ?? false,
      badges: _parseMap(json['badges']),
      cacheTimestamp: _parseDateTime(json['cache_timestamp']),
      trackingData: _parseMap(json['tracking_data']),
    );
  }

  /// Converts the model to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'cache_timestamp': cacheTimestamp?.toIso8601String(),
      'tracking_data': trackingData,
    };
  }

  // Static parsing methods

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    if (value is DateTime) return value;
    return null;
  }

  static Map<String, dynamic> _parseMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  /// Creates a copy of this LeaderboardEntryModel with the given fields replaced with new values.
  LeaderboardEntryModel copyWith({
    String? id,
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
    DateTime? cacheTimestamp,
    Map<String, dynamic>? trackingData,
  }) {
    return LeaderboardEntryModel(
      id: id ?? this.id,
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
      cacheTimestamp: cacheTimestamp ?? this.cacheTimestamp,
      trackingData: trackingData ?? this.trackingData,
    );
  }

  /// Creates a mock LeaderboardEntryModel for testing
  factory LeaderboardEntryModel.mock({
    String? id,
    String? userId,
    String? displayName,
    int rank = 1,
    double score = 1000,
    bool isCurrentUser = false,
  }) {
    return LeaderboardEntryModel(
      id: id ?? 'mock_entry_$rank',
      userId: userId ?? 'mock_user_$rank',
      displayName: displayName ?? 'Player $rank',
      rank: rank,
      previousRank: rank + 1,
      score: score,
      previousScore: score * 0.8,
      stats: {'games_played': 10, 'wins': 7},
      lastUpdated: DateTime.now(),
      isCurrentUser: isCurrentUser,
      badges: {'newcomer': true},
      cacheTimestamp: DateTime.now(),
    );
  }

  /// Check if this entry represents the current/active user
  bool get isActiveUser => isCurrentUser;

  /// Check if this entry is in podium position (top 3)
  bool get isPodiumPosition => rank <= 3;

  @override
  String toString() {
    return 'LeaderboardEntryModel(id: $id, rank: $rank, '
        'user: $displayName, score: $score, isCurrentUser: $isCurrentUser)';
  }
}
