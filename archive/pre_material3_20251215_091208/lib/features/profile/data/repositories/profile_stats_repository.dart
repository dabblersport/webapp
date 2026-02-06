import 'package:dabbler/data/models/profile/profile_statistics.dart';

/// Profile statistics repository interface
class ProfileStatsRepository {
  /// Get profile statistics
  Future<ProfileStatistics> getProfileStats(String userId) async {
    throw UnimplementedError(
      'ProfileStatsRepository.getProfileStats not implemented',
    );
  }

  /// Update profile statistics
  Future<void> updateProfileStats(
    String userId,
    ProfileStatistics stats,
  ) async {
    throw UnimplementedError(
      'ProfileStatsRepository.updateProfileStats not implemented',
    );
  }

  /// Increment games played
  Future<void> incrementGamesPlayed(String userId, {String? sportId}) async {
    throw UnimplementedError(
      'ProfileStatsRepository.incrementGamesPlayed not implemented',
    );
  }

  /// Update rating
  Future<void> updateRating(
    String userId,
    double newRating, {
    String? sportId,
  }) async {
    throw UnimplementedError(
      'ProfileStatsRepository.updateRating not implemented',
    );
  }

  /// Record game outcome
  Future<void> recordGameOutcome(
    String userId, {
    required bool isWin,
    String? sportId,
    double? performanceRating,
  }) async {
    throw UnimplementedError(
      'ProfileStatsRepository.recordGameOutcome not implemented',
    );
  }

  /// Get leaderboard position
  Future<int> getLeaderboardPosition(String userId, {String? sportId}) async {
    throw UnimplementedError(
      'ProfileStatsRepository.getLeaderboardPosition not implemented',
    );
  }

  /// Get profile view count
  Future<int> getProfileViews(String userId) async {
    throw UnimplementedError(
      'ProfileStatsRepository.getProfileViews not implemented',
    );
  }

  /// Increment profile view count
  Future<void> incrementProfileViews(String userId) async {
    throw UnimplementedError(
      'ProfileStatsRepository.incrementProfileViews not implemented',
    );
  }
}
