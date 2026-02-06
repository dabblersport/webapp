import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dabbler/core/utils/logger.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';
import 'package:dabbler/data/models/sport_profiles/sport_profile.dart';
import 'package:dabbler/services/sport_profile_service.dart';

/// Game completion integration with rewards system
class GameCompletionRewardsHandler {
  GameCompletionRewardsHandler({SportProfileService? sportProfileService})
    : _sportProfileService = sportProfileService ?? SportProfileService();

  final SportProfileService _sportProfileService;

  static const String _logTag = 'GameCompletionRewardsHandler';

  /// Handle game completion with rewards integration
  Future<void> handleGameCompletion({
    required String userId,
    required String gameId,
    required String sport,
    required bool isWinner,
    required Duration gameDuration,
    required Map<String, dynamic> gameStats,
    BuildContext? context,
  }) async {
    try {
      Logger.debug(
        '$_logTag: handling completion for userId=$userId gameId=$gameId sport=$sport',
      );

      // Calculate base points for game completion
      final pointsEarned = _calculateGamePoints(
        sport: sport,
        isWinner: isWinner,
        gameDuration: gameDuration,
        gameStats: gameStats,
      );

      final profiles = await _sportProfileService.getSportProfilesForUser(
        userId,
      );
      if (profiles.isEmpty) {
        Logger.warning(
          '$_logTag: No sport profiles found for userId=$userId when recording match outcome',
        );
        return;
      }

      final profile = _selectProfileForSport(profiles, sport);
      if (profile == null) {
        Logger.warning(
          '$_logTag: No matching sport profile for sport=$sport userId=$userId',
        );
        return;
      }

      final sanitizedStats = Map<String, dynamic>.from(gameStats);
      final performanceRating = _extractPerformanceRating(sanitizedStats);
      final reliabilityDelta = _extractReliabilityDelta(
        sanitizedStats,
        isWinner,
      );
      final mlVector = _extractMlVector(sanitizedStats);

      await _sportProfileService.applyMatchOutcome(
        profileId: profile.profileId,
        sportKey: profile.sportKey,
        xpGained: pointsEarned,
        performanceRating: performanceRating,
        reliabilityDelta: reliabilityDelta,
        mlVector: mlVector,
      );

      Logger.debug(
        '$_logTag: Applied sport profile update for userId=$userId sport=${profile.sportKey} xp=$pointsEarned',
      );

      // Show haptic feedback
      if (context != null) {
        HapticFeedback.mediumImpact();
      }

      await _logNotableEvents(profile);
    } catch (e) {
      Logger.error('$_logTag: Error handling game completion rewards', e);
    }
  }

  SportProfile? _selectProfileForSport(
    List<SportProfile> profiles,
    String sport,
  ) {
    if (profiles.isEmpty) {
      return null;
    }

    final normalized = sport.toLowerCase();
    for (final profile in profiles) {
      if (profile.sportKey.toLowerCase() == normalized) {
        return profile;
      }
    }

    return profiles.first;
  }

  int? _extractPerformanceRating(Map<String, dynamic> stats) {
    final dynamic raw =
        stats['performance_rating'] ??
        stats['performanceRating'] ??
        stats['player_rating'] ??
        stats['rating'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  int? _extractReliabilityDelta(Map<String, dynamic> stats, bool isWinner) {
    final dynamic raw = stats['reliability_delta'] ?? stats['reliabilityDelta'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return isWinner ? 1 : null;
  }

  Map<String, dynamic>? _extractMlVector(Map<String, dynamic> stats) {
    final dynamic raw = stats['ml_vector'] ?? stats['mlVector'];
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is List) {
      return {'values': List<dynamic>.from(raw)};
    }
    return null;
  }

  Future<void> _logNotableEvents(SportProfile profile) async {
    try {
      final events = await _sportProfileService.getRecentSportProfileEvents(
        profile.profileId,
        profile.sportKey,
        limit: 5,
      );

      for (final event in events) {
        if (event.eventType == 'level_up' || event.eventType == 'form_boost') {
          Logger.debug(
            '$_logTag: Notable sport profile event recorded (${event.eventType})',
          );
          break;
        }
      }
    } catch (error) {
      Logger.warning(
        '$_logTag: Failed to read sport profile events after completion',
        error,
      );
    }
  }

  /// Calculate points earned from game completion
  int _calculateGamePoints({
    required String sport,
    required bool isWinner,
    required Duration gameDuration,
    required Map<String, dynamic> gameStats,
  }) {
    int basePoints = 50; // Base participation points

    // Bonus for winning
    if (isWinner) {
      basePoints += 25;
    }

    // Sport-specific multipliers
    final sportMultiplier = _getSportMultiplier(sport);
    basePoints = (basePoints * sportMultiplier).round();

    // Game duration bonus (longer games get slight bonus)
    if (gameDuration.inMinutes > 30) {
      basePoints += 10;
    }

    return basePoints;
  }

  /// Get sport-specific multiplier
  double _getSportMultiplier(String sport) {
    switch (sport.toLowerCase()) {
      case 'football':
      case 'soccer':
        return 1.2;
      case 'basketball':
        return 1.1;
      case 'tennis':
        return 1.3;
      case 'volleyball':
        return 1.0;
      default:
        return 1.0;
    }
  }

  /// Get tier based on milestone count
  BadgeTier _getTierForMilestone(int count) {
    if (count >= 100) return BadgeTier.diamond;
    if (count >= 50) return BadgeTier.platinum;
    if (count >= 25) return BadgeTier.gold;
    if (count >= 10) return BadgeTier.silver;
    return BadgeTier.bronze;
  }

  /// Get tier based on win streak
  BadgeTier _getTierForWinStreak(int streak) {
    if (streak >= 20) return BadgeTier.platinum;
    if (streak >= 10) return BadgeTier.gold;
    if (streak >= 5) return BadgeTier.silver;
    return BadgeTier.bronze;
  }

  /// Get milestone name for achievement
  String _getMilestoneName(int count) {
    switch (count) {
      case 5:
        return 'Newcomer';
      case 10:
        return 'Regular';
      case 25:
        return 'Veteran';
      case 50:
        return 'Expert';
      case 100:
        return 'Master';
      default:
        return 'Player';
    }
  }
}
