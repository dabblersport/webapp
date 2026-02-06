import 'package:dabbler/data/models/profile/profile_statistics.dart';

class ProfileStatisticsModel extends ProfileStatistics {
  const ProfileStatisticsModel({
    super.totalGamesPlayed,
    super.totalGamesOrganized,
    super.totalWins,
    super.totalLosses,
    super.totalDraws,
    super.totalHoursPlayed,
    super.averageGameDuration,
    super.currentWinStreak,
    super.longestWinStreak,
    super.currentPlayStreak,
    super.longestPlayStreak,
    super.uniqueTeammates,
    super.uniqueVenues,
    super.averageRating,
    super.totalRatingsReceived,
    super.achievements,
    super.badges,
    super.lastGameDate,
    super.sportGamesCount,
  });

  /// Creates ProfileStatisticsModel from domain entity
  factory ProfileStatisticsModel.fromEntity(ProfileStatistics entity) {
    return ProfileStatisticsModel(
      totalGamesPlayed: entity.totalGamesPlayed,
      totalGamesOrganized: entity.totalGamesOrganized,
      totalWins: entity.totalWins,
      totalLosses: entity.totalLosses,
      totalDraws: entity.totalDraws,
      totalHoursPlayed: entity.totalHoursPlayed,
      averageGameDuration: entity.averageGameDuration,
      currentWinStreak: entity.currentWinStreak,
      longestWinStreak: entity.longestWinStreak,
      currentPlayStreak: entity.currentPlayStreak,
      longestPlayStreak: entity.longestPlayStreak,
      uniqueTeammates: entity.uniqueTeammates,
      uniqueVenues: entity.uniqueVenues,
      averageRating: entity.averageRating,
      totalRatingsReceived: entity.totalRatingsReceived,
      achievements: entity.achievements,
      badges: entity.badges,
      lastGameDate: entity.lastGameDate,
      sportGamesCount: entity.sportGamesCount,
    );
  }

  /// Creates ProfileStatisticsModel from JSON (Supabase response)
  factory ProfileStatisticsModel.fromJson(Map<String, dynamic> json) {
    return ProfileStatisticsModel(
      totalGamesPlayed: _parseIntWithDefault(json['total_games_played'], 0),
      totalGamesOrganized: _parseIntWithDefault(
        json['total_games_organized'],
        0,
      ),
      totalWins: _parseIntWithDefault(json['total_games_won'], 0),
      totalLosses: _parseIntWithDefault(json['total_games_lost'], 0),
      totalDraws: _parseIntWithDefault(json['total_draws'], 0),
      totalHoursPlayed: _parseDoubleWithDefault(
        json['total_hours_played'],
        0.0,
      ),
      averageGameDuration: _parseDoubleWithDefault(
        json['average_game_duration'],
        0.0,
      ),
      currentWinStreak: _parseIntWithDefault(json['current_win_streak'], 0),
      longestWinStreak: _parseIntWithDefault(json['longest_win_streak'], 0),
      currentPlayStreak: _parseIntWithDefault(json['current_play_streak'], 0),
      longestPlayStreak: _parseIntWithDefault(json['longest_play_streak'], 0),
      uniqueTeammates: _parseIntWithDefault(json['unique_teammates'], 0),
      uniqueVenues: _parseIntWithDefault(json['unique_venues'], 0),
      averageRating: _parseDoubleWithDefault(json['average_rating'], 0.0),
      totalRatingsReceived: _parseIntWithDefault(
        json['total_ratings_received'],
        0,
      ),
      achievements: _parseStringList(json['achievements']),
      badges: _parseStringList(json['badges']),
      lastGameDate: _parseDateTime(json['last_game_date']),
      sportGamesCount: _parseSportGamesCount(json['sport_games_count']),
    );
  }

  /// Creates ProfileStatisticsModel from Supabase aggregated query
  factory ProfileStatisticsModel.fromSupabaseAggregated(
    Map<String, dynamic> json,
  ) {
    // Handle aggregated statistics from complex queries
    return ProfileStatisticsModel(
      totalGamesPlayed: _parseIntWithDefault(json['games_count'], 0),
      totalGamesOrganized: _parseIntWithDefault(json['organized_count'], 0),
      totalWins: _parseIntWithDefault(json['wins_count'], 0),
      totalLosses: _parseIntWithDefault(json['losses_count'], 0),
      totalDraws: _parseIntWithDefault(json['draws_count'], 0),
      totalHoursPlayed: _calculateHoursFromMinutes(
        json['total_minutes_played'],
      ),
      averageGameDuration: _parseDoubleWithDefault(
        json['avg_game_duration_minutes'],
        0.0,
      ),
      currentWinStreak: _parseIntWithDefault(json['current_win_streak'], 0),
      longestWinStreak: _parseIntWithDefault(json['longest_win_streak'], 0),
      currentPlayStreak: _parseIntWithDefault(json['current_play_streak'], 0),
      longestPlayStreak: _parseIntWithDefault(json['longest_play_streak'], 0),
      uniqueTeammates: _parseIntWithDefault(json['unique_teammates_count'], 0),
      uniqueVenues: _parseIntWithDefault(json['unique_venues_count'], 0),
      averageRating: _parseDoubleWithDefault(json['avg_rating'], 0.0),
      totalRatingsReceived: _parseIntWithDefault(json['ratings_count'], 0),
      achievements: _parseStringList(json['achievements']),
      badges: _parseStringList(json['badges']),
      lastGameDate: _parseDateTime(json['last_game_date']),
      sportGamesCount: _extractSportGamesCount(json),
    );
  }

  /// Converts ProfileStatisticsModel to JSON for API requests
  @override
  Map<String, dynamic> toJson() {
    return {
      'total_games_played': totalGamesPlayed,
      'total_games_organized': totalGamesOrganized,
      'total_games_won': totalWins,
      'total_games_lost': totalLosses,
      'total_draws': totalDraws,
      'total_hours_played': totalHoursPlayed,
      'average_game_duration': averageGameDuration,
      'current_win_streak': currentWinStreak,
      'longest_win_streak': longestWinStreak,
      'current_play_streak': currentPlayStreak,
      'longest_play_streak': longestPlayStreak,
      'unique_teammates': uniqueTeammates,
      'unique_venues': uniqueVenues,
      'average_rating': averageRating,
      'total_ratings_received': totalRatingsReceived,
      'achievements': achievements,
      'badges': badges,
      'last_game_date': lastGameDate?.toIso8601String(),
      'sport_games_count': sportGamesCount,
    };
  }

  /// Converts to JSON for database updates (minimal fields)
  Map<String, dynamic> toUpdateJson() {
    return {
      'total_games_played': totalGamesPlayed,
      'total_games_organized': totalGamesOrganized,
      'total_games_won': totalWins,
      'total_games_lost': totalLosses,
      'total_draws': totalDraws,
      'total_hours_played': totalHoursPlayed,
      'average_game_duration': averageGameDuration,
      'current_win_streak': currentWinStreak,
      'longest_win_streak': longestWinStreak,
      'current_play_streak': currentPlayStreak,
      'longest_play_streak': longestPlayStreak,
      'unique_teammates': uniqueTeammates,
      'unique_venues': uniqueVenues,
      'average_rating': averageRating,
      'total_ratings_received': totalRatingsReceived,
      'achievements': achievements,
      'badges': badges,
      'last_game_date': lastGameDate?.toIso8601String(),
      'sport_games_count': sportGamesCount,
    };
  }

  // Helper methods for parsing

  static int _parseIntWithDefault(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static double _parseDoubleWithDefault(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      if (value.isEmpty) return [];
      // Handle JSON array strings
      if (value.startsWith('[') && value.endsWith(']')) {
        try {
          final parsed = value
              .substring(1, value.length - 1)
              .split(',')
              .map((e) => e.trim().replaceAll('"', ''))
              .where((e) => e.isNotEmpty)
              .toList();
          return parsed;
        } catch (e) {
          return [];
        }
      }
      // Handle comma-separated values
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  static Map<String, int> _parseSportGamesCount(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, int>) return value;
    if (value is Map) {
      return value.map(
        (key, value) =>
            MapEntry(key.toString(), _parseIntWithDefault(value, 0)),
      );
    }
    if (value is String) {
      try {
        // Handle JSON string representation of map
        if (value.startsWith('{') && value.endsWith('}')) {
          final cleanValue = value.substring(1, value.length - 1);
          final pairs = cleanValue.split(',');
          final result = <String, int>{};
          for (final pair in pairs) {
            final parts = pair.split(':');
            if (parts.length == 2) {
              final key = parts[0].trim().replaceAll('"', '');
              final value = _parseIntWithDefault(parts[1].trim(), 0);
              result[key] = value;
            }
          }
          return result;
        }
      } catch (e) {
        return {};
      }
    }
    return {};
  }

  static double _calculateHoursFromMinutes(dynamic minutes) {
    final totalMinutes = _parseDoubleWithDefault(minutes, 0.0);
    return totalMinutes / 60.0;
  }

  static Map<String, int> _extractSportGamesCount(Map<String, dynamic> json) {
    // Extract from sport type frequency data
    if (json.containsKey('sport_type_counts') &&
        json['sport_type_counts'] is Map) {
      final counts = json['sport_type_counts'] as Map<String, dynamic>;
      return counts.map(
        (key, value) => MapEntry(key, _parseIntWithDefault(value, 0)),
      );
    }

    return _parseSportGamesCount(json['sport_games_count']);
  }

  /// Creates a copy with updated fields
  @override
  ProfileStatisticsModel copyWith({
    int? totalGamesPlayed,
    int? totalGamesOrganized,
    int? totalWins,
    int? totalLosses,
    int? totalDraws,
    double? totalHoursPlayed,
    double? averageGameDuration,
    int? currentWinStreak,
    int? longestWinStreak,
    int? currentPlayStreak,
    int? longestPlayStreak,
    int? uniqueTeammates,
    int? uniqueVenues,
    double? averageRating,
    int? totalRatingsReceived,
    List<String>? achievements,
    List<String>? badges,
    DateTime? lastGameDate,
    Map<String, int>? sportGamesCount,
  }) {
    return ProfileStatisticsModel(
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      totalGamesOrganized: totalGamesOrganized ?? this.totalGamesOrganized,
      totalWins: totalWins ?? this.totalWins,
      totalLosses: totalLosses ?? this.totalLosses,
      totalDraws: totalDraws ?? this.totalDraws,
      totalHoursPlayed: totalHoursPlayed ?? this.totalHoursPlayed,
      averageGameDuration: averageGameDuration ?? this.averageGameDuration,
      currentWinStreak: currentWinStreak ?? this.currentWinStreak,
      longestWinStreak: longestWinStreak ?? this.longestWinStreak,
      currentPlayStreak: currentPlayStreak ?? this.currentPlayStreak,
      longestPlayStreak: longestPlayStreak ?? this.longestPlayStreak,
      uniqueTeammates: uniqueTeammates ?? this.uniqueTeammates,
      uniqueVenues: uniqueVenues ?? this.uniqueVenues,
      averageRating: averageRating ?? this.averageRating,
      totalRatingsReceived: totalRatingsReceived ?? this.totalRatingsReceived,
      achievements: achievements ?? this.achievements,
      badges: badges ?? this.badges,
      lastGameDate: lastGameDate ?? this.lastGameDate,
      sportGamesCount: sportGamesCount ?? this.sportGamesCount,
    );
  }

  /// Converts back to domain entity
  ProfileStatistics toEntity() {
    return ProfileStatistics(
      totalGamesPlayed: totalGamesPlayed,
      totalGamesOrganized: totalGamesOrganized,
      totalWins: totalWins,
      totalLosses: totalLosses,
      totalDraws: totalDraws,
      totalHoursPlayed: totalHoursPlayed,
      averageGameDuration: averageGameDuration,
      currentWinStreak: currentWinStreak,
      longestWinStreak: longestWinStreak,
      currentPlayStreak: currentPlayStreak,
      longestPlayStreak: longestPlayStreak,
      uniqueTeammates: uniqueTeammates,
      uniqueVenues: uniqueVenues,
      averageRating: averageRating,
      totalRatingsReceived: totalRatingsReceived,
      achievements: achievements,
      badges: badges,
      lastGameDate: lastGameDate,
      sportGamesCount: sportGamesCount,
    );
  }
}
