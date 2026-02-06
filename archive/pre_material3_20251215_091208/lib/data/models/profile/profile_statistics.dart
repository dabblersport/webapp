class ProfileStatistics {
  final int totalGamesPlayed;
  final int totalGamesOrganized;
  final int totalWins;
  final int totalLosses;
  final int totalDraws;
  final double totalHoursPlayed;
  final double averageGameDuration;
  final int currentWinStreak;
  final int longestWinStreak;
  final int currentPlayStreak; // consecutive days played
  final int longestPlayStreak;
  final int uniqueTeammates;
  final int uniqueVenues;
  final double averageRating;
  final int totalRatingsReceived;
  final List<String> achievements;
  final List<String> badges;
  final DateTime? lastGameDate;
  final Map<String, int> sportGamesCount; // sportId -> count

  const ProfileStatistics({
    this.totalGamesPlayed = 0,
    this.totalGamesOrganized = 0,
    this.totalWins = 0,
    this.totalLosses = 0,
    this.totalDraws = 0,
    this.totalHoursPlayed = 0.0,
    this.averageGameDuration = 0.0,
    this.currentWinStreak = 0,
    this.longestWinStreak = 0,
    this.currentPlayStreak = 0,
    this.longestPlayStreak = 0,
    this.uniqueTeammates = 0,
    this.uniqueVenues = 0,
    this.averageRating = 0.0,
    this.totalRatingsReceived = 0,
    this.achievements = const [],
    this.badges = const [],
    this.lastGameDate,
    this.sportGamesCount = const {},
  });

  /// Returns win percentage as a value between 0 and 1
  double getWinRate() {
    final totalCompetitiveGames = totalWins + totalLosses + totalDraws;
    if (totalCompetitiveGames == 0) return 0.0;
    return totalWins / totalCompetitiveGames;
  }

  /// Returns formatted play time as a string (e.g., "25.5 hours")
  String get formattedPlayTime {
    if (totalHoursPlayed == 0) return '0 hours';
    if (totalHoursPlayed < 1) {
      final minutes = (totalHoursPlayed * 60).round();
      return '$minutes minutes';
    }
    if (totalHoursPlayed == totalHoursPlayed.roundToDouble()) {
      return '${totalHoursPlayed.round()} hours';
    }
    return '${totalHoursPlayed.toStringAsFixed(1)} hours';
  }

  /// Returns reliability score based on various factors (0-100)
  double getReliabilityScore() {
    if (totalGamesPlayed == 0) return 0.0;

    // Base score from games played (up to 40 points)
    double score = (totalGamesPlayed * 2.0).clamp(0, 40);

    // Bonus for organizing games (up to 20 points)
    score += (totalGamesOrganized * 4.0).clamp(0, 20);

    // Bonus for consistent play (up to 20 points)
    score += (longestPlayStreak * 1.0).clamp(0, 20);

    // Bonus for good ratings (up to 20 points)
    if (totalRatingsReceived > 0) {
      score += ((averageRating - 2.5) * 8.0).clamp(0, 20);
    }

    return score.clamp(0, 100);
  }

  /// Returns activity level based on recent play
  String getActivityLevel() {
    if (lastGameDate == null) return 'Inactive';

    final daysSinceLastGame = DateTime.now().difference(lastGameDate!).inDays;

    if (daysSinceLastGame <= 7) return 'Very Active';
    if (daysSinceLastGame <= 30) return 'Active';
    if (daysSinceLastGame <= 90) return 'Moderate';
    return 'Inactive';
  }

  /// Returns the most played sport
  String? getMostPlayedSport() {
    if (sportGamesCount.isEmpty) return null;

    return sportGamesCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Returns true if player is considered experienced
  bool isExperiencedPlayer() {
    return totalGamesPlayed >= 10 &&
        getReliabilityScore() >= 60 &&
        averageRating >= 3.5;
  }

  /// Returns true if player is a regular organizer
  bool isRegularOrganizer() {
    return totalGamesOrganized >= 3 &&
        totalGamesOrganized / totalGamesPlayed >= 0.2;
  }

  // UI compatibility getters
  int get totalGames => totalGamesPlayed;
  int get gamesWon => totalWins;
  int get gamesLost => totalLosses;
  int get streakDays => currentPlayStreak;
  int get friendsCount => uniqueTeammates;
  int get achievementsUnlocked => achievements.length;
  List<String> get recentAchievements => achievements.take(3).toList();
  Map<String, int> get sportSpecificStats => sportGamesCount;
  Map<String, double> get skillRatings => {
    for (final entry in sportGamesCount.entries)
      entry.key: averageRating + (entry.value * 0.1).clamp(-1.0, 1.0),
  };
  double get improvementRate => getReliabilityScore() * 0.3;
  int get eventsAttended => totalGamesPlayed;
  int get mentorshipSessions => totalGamesOrganized;

  String get winRateFormatted {
    final rate = getWinRate() * 100;
    return '${rate.toStringAsFixed(1)}%';
  }

  String get ratingFormatted {
    return averageRating.toStringAsFixed(1);
  }

  String get lastActiveFormatted {
    if (lastGameDate == null) return 'Never';
    final now = DateTime.now();
    final difference = now.difference(lastGameDate!);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inMinutes} minutes ago';
    }
  }

  /// Creates a copy with updated fields
  ProfileStatistics copyWith({
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
    return ProfileStatistics(
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

  /// Creates ProfileStatistics from JSON
  factory ProfileStatistics.fromJson(Map<String, dynamic> json) {
    return ProfileStatistics(
      totalGamesPlayed: json['totalGamesPlayed'] as int? ?? 0,
      totalGamesOrganized: json['totalGamesOrganized'] as int? ?? 0,
      totalWins: json['totalWins'] as int? ?? 0,
      totalLosses: json['totalLosses'] as int? ?? 0,
      totalDraws: json['totalDraws'] as int? ?? 0,
      totalHoursPlayed: (json['totalHoursPlayed'] as num?)?.toDouble() ?? 0.0,
      averageGameDuration:
          (json['averageGameDuration'] as num?)?.toDouble() ?? 0.0,
      currentWinStreak: json['currentWinStreak'] as int? ?? 0,
      longestWinStreak: json['longestWinStreak'] as int? ?? 0,
      currentPlayStreak: json['currentPlayStreak'] as int? ?? 0,
      longestPlayStreak: json['longestPlayStreak'] as int? ?? 0,
      uniqueTeammates: json['uniqueTeammates'] as int? ?? 0,
      uniqueVenues: json['uniqueVenues'] as int? ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalRatingsReceived: json['totalRatingsReceived'] as int? ?? 0,
      achievements: List<String>.from(json['achievements'] as List? ?? []),
      badges: List<String>.from(json['badges'] as List? ?? []),
      lastGameDate: json['lastGameDate'] != null
          ? DateTime.parse(json['lastGameDate'] as String)
          : null,
      sportGamesCount: Map<String, int>.from(
        json['sportGamesCount'] as Map? ?? {},
      ),
    );
  }

  /// Converts ProfileStatistics to JSON
  Map<String, dynamic> toJson() {
    return {
      'totalGamesPlayed': totalGamesPlayed,
      'totalGamesOrganized': totalGamesOrganized,
      'totalWins': totalWins,
      'totalLosses': totalLosses,
      'totalDraws': totalDraws,
      'totalHoursPlayed': totalHoursPlayed,
      'averageGameDuration': averageGameDuration,
      'currentWinStreak': currentWinStreak,
      'longestWinStreak': longestWinStreak,
      'currentPlayStreak': currentPlayStreak,
      'longestPlayStreak': longestPlayStreak,
      'uniqueTeammates': uniqueTeammates,
      'uniqueVenues': uniqueVenues,
      'averageRating': averageRating,
      'totalRatingsReceived': totalRatingsReceived,
      'achievements': achievements,
      'badges': badges,
      'lastGameDate': lastGameDate?.toIso8601String(),
      'sportGamesCount': sportGamesCount,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileStatistics &&
        other.totalGamesPlayed == totalGamesPlayed &&
        other.totalGamesOrganized == totalGamesOrganized &&
        other.totalWins == totalWins &&
        other.totalLosses == totalLosses &&
        other.totalDraws == totalDraws &&
        other.totalHoursPlayed == totalHoursPlayed &&
        other.averageGameDuration == averageGameDuration &&
        other.currentWinStreak == currentWinStreak &&
        other.longestWinStreak == longestWinStreak &&
        other.currentPlayStreak == currentPlayStreak &&
        other.longestPlayStreak == longestPlayStreak &&
        other.uniqueTeammates == uniqueTeammates &&
        other.uniqueVenues == uniqueVenues &&
        other.averageRating == averageRating &&
        other.totalRatingsReceived == totalRatingsReceived &&
        _listEquals(other.achievements, achievements) &&
        _listEquals(other.badges, badges) &&
        other.lastGameDate == lastGameDate &&
        _mapEquals(other.sportGamesCount, sportGamesCount);
  }

  @override
  int get hashCode {
    return Object.hash(
      totalGamesPlayed,
      totalGamesOrganized,
      totalWins,
      totalLosses,
      totalDraws,
      totalHoursPlayed,
      averageGameDuration,
      currentWinStreak,
      longestWinStreak,
      currentPlayStreak,
      longestPlayStreak,
      uniqueTeammates,
      uniqueVenues,
      averageRating,
      totalRatingsReceived,
      Object.hashAll(achievements),
      Object.hashAll(badges),
      lastGameDate,
      Object.hashAll(sportGamesCount.entries),
    );
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (int index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  bool _mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
