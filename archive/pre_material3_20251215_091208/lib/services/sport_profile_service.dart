import 'package:dabbler/core/utils/logger.dart';
import 'package:dabbler/data/models/sport_profiles/sport_profile.dart';
import 'package:dabbler/data/models/sport_profiles/sport_profile_badge.dart';
import 'package:dabbler/data/models/sport_profiles/sport_profile_event.dart';
import 'package:dabbler/data/models/sport_profiles/sport_profile_tier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SportProfileServiceException implements Exception {
  SportProfileServiceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'SportProfileServiceException: $message';
}

class SportProfileService {
  SportProfileService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _logTag = 'SportProfileService';

  Future<SportProfile?> getSportProfile(
    String profileId,
    String sportKey,
  ) async {
    try {
      final response = await _supabase
          .from('sport_profiles')
          .select()
          .eq('profile_id', profileId)
          .eq('sport', sportKey)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        Logger.debug(
          '$_logTag: Sport profile not found for profileId=$profileId sportKey=$sportKey',
        );
        return null;
      }

      return SportProfile.fromJson(
        Map<String, dynamic>.from(response as Map<dynamic, dynamic>),
      );
    } on PostgrestException catch (e) {
      Logger.error(
        '$_logTag: Failed to fetch sport profile for profileId=$profileId sportKey=$sportKey',
        e,
      );
      throw SportProfileServiceException(
        'Failed to fetch sport profile',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error fetching sport profile for profileId=$profileId sportKey=$sportKey',
        e,
      );
      throw SportProfileServiceException(
        'Failed to fetch sport profile',
        cause: e,
      );
    }
  }

  Future<List<SportProfile>> getSportProfilesForUser(String userId) async {
    try {
      // First, get the profile_id(s) for this user_id
      final profilesResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('user_id', userId);

      if (profilesResponse.isEmpty) {
        Logger.debug('$_logTag: No profiles found for userId=$userId');
        return [];
      }

      // Extract profile IDs
      final profileIds = (profilesResponse as List)
          .map((p) => (p as Map<String, dynamic>)['id'] as String)
          .toList();

      if (profileIds.isEmpty) {
        return [];
      }

      // Now fetch sport_profiles using profile_id
      final response = await _supabase
          .from('sport_profiles')
          .select('*')
          .inFilter('profile_id', profileIds);

      final data = (response as List)
          .map(
            (dynamic item) =>
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .map(SportProfile.fromJson)
          .toList();

      return data;
    } on PostgrestException catch (e) {
      Logger.error(
        '$_logTag: Failed to fetch sport profiles for userId=$userId',
        e,
      );
      throw SportProfileServiceException(
        'Failed to fetch sport profiles',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error fetching sport profiles for userId=$userId',
        e,
      );
      throw SportProfileServiceException(
        'Failed to fetch sport profiles',
        cause: e,
      );
    }
  }

  Future<List<SportProfileEvent>> getRecentSportProfileEvents(
    String profileId,
    String sportKey, {
    int limit = 20,
  }) async {
    final fetchLimit = limit <= 0 ? 20 : limit;

    try {
      final response = await _supabase
          .from('sport_profile_events')
          .select()
          .eq('profile_id', profileId)
          .eq('sport', sportKey)
          .order('created_at', ascending: false)
          .limit(fetchLimit);

      return (response as List)
          .map(
            (dynamic item) =>
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .map(SportProfileEvent.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      Logger.error(
        '$_logTag: Failed to fetch sport profile events for profileId=$profileId sportKey=$sportKey',
        e,
      );
      throw SportProfileServiceException(
        'Failed to fetch sport profile events',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error fetching sport profile events for profileId=$profileId sportKey=$sportKey',
        e,
      );
      throw SportProfileServiceException(
        'Failed to fetch sport profile events',
        cause: e,
      );
    }
  }

  Future<List<SportProfileBadge>> getPlayerBadges(
    String profileId,
    String sportKey,
  ) async {
    try {
      final response = await _supabase
          .from('sport_profile_profile_badges')
          .select('badge:sport_profile_badges!inner(*)')
          .eq('profile_id', profileId)
          .eq('sport', sportKey)
          .order('awarded_at', ascending: false);

      final rows = (response as List)
          .map(
            (dynamic item) =>
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .map((map) => map['badge'])
          .whereType<Map<dynamic, dynamic>>()
          .map((badge) => Map<String, dynamic>.from(badge))
          .map(SportProfileBadge.fromJson)
          .toList();

      return rows;
    } on PostgrestException catch (e) {
      Logger.error(
        '$_logTag: Failed to fetch player badges for profileId=$profileId sportKey=$sportKey',
        e,
      );
      throw SportProfileServiceException(
        'Failed to fetch sport profile badges',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error fetching player badges for profileId=$profileId sportKey=$sportKey',
        e,
      );
      throw SportProfileServiceException(
        'Failed to fetch sport profile badges',
        cause: e,
      );
    }
  }

  Future<SportProfileTier?> getTierById(String? tierId) async {
    if (tierId == null || tierId.isEmpty) {
      return null;
    }

    try {
      final response = await _supabase
          .from('sport_profile_tiers')
          .select()
          .eq('id', tierId)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return SportProfileTier.fromJson(
        Map<String, dynamic>.from(response as Map<dynamic, dynamic>),
      );
    } on PostgrestException catch (e) {
      Logger.error(
        '$_logTag: Failed to fetch sport profile tier for tierId=$tierId',
        e,
      );
      throw SportProfileServiceException(
        'Failed to fetch sport profile tier',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error fetching sport profile tier for tierId=$tierId',
        e,
      );
      throw SportProfileServiceException(
        'Failed to fetch sport profile tier',
        cause: e,
      );
    }
  }

  Future<void> applyMatchOutcome({
    required String profileId,
    required String sportKey,
    required int xpGained,
    int? performanceRating,
    int? reliabilityDelta,
    Map<String, dynamic>? mlVector,
  }) async {
    try {
      final response = await _supabase
          .from('sport_profiles')
          .select(
            'xp_total,matches_played,last_5_matches,reliability_score,ml_avg_vector,ml_vector_count',
          )
          .eq('profile_id', profileId)
          .eq('sport', sportKey)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        Logger.warning(
          '$_logTag: Sport profile not found when applying match outcome for profileId=$profileId sportKey=$sportKey',
        );
        return;
      }

      final existing = Map<String, dynamic>.from(
        response as Map<dynamic, dynamic>,
      );

      final currentXp = _asDouble(existing['xp_total']);
      final currentMatches = _asInt(existing['matches_played']);
      final currentReliability = _asDouble(existing['reliability_score']);
      final currentLastMatches = _asList(
        existing['last_5_matches'] ?? existing['last5_matches'],
      );

      final updates = <String, dynamic>{
        'xp_total': currentXp + xpGained.toDouble(),
        'matches_played': currentMatches + 1,
      };

      final updatedLastMatches = _buildUpdatedLastMatches(
        currentLastMatches,
        performanceRating,
      );
      if (updatedLastMatches != null) {
        updates['last_5_matches'] = updatedLastMatches;
      }

      if (reliabilityDelta != null) {
        updates['reliability_score'] =
            currentReliability + reliabilityDelta.toDouble();
      }

      final extractedVector = _extractVectorValues(mlVector);
      if (extractedVector != null) {
        final currentAverage = _asList(existing['ml_avg_vector']);
        final currentCount = _asInt(existing['ml_vector_count']);
        updates['ml_last_vector'] = extractedVector;
        updates['ml_avg_vector'] = _recalculateAverageVector(
          currentAverage,
          extractedVector,
          currentCount,
        );
        updates['ml_vector_count'] = currentCount + 1;
      }

      await _supabase
          .from('sport_profiles')
          .update(updates)
          .eq('profile_id', profileId)
          .eq('sport', sportKey);

      Logger.debug(
        '$_logTag: Applied match outcome for profileId=$profileId sportKey=$sportKey (xp +$xpGained)',
      );
    } on PostgrestException catch (e) {
      Logger.error(
        '$_logTag: Failed to apply match outcome for profileId=$profileId sportKey=$sportKey',
        e,
      );
      throw SportProfileServiceException(
        'Failed to update sport profile after match',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error applying match outcome for profileId=$profileId sportKey=$sportKey',
        e,
      );
      throw SportProfileServiceException(
        'Failed to update sport profile after match',
        cause: e,
      );
    }
  }
}

double _asDouble(dynamic value) {
  if (value == null) {
    return 0.0;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

int _asInt(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

List<dynamic> _asList(dynamic value) {
  if (value == null) {
    return <dynamic>[];
  }
  if (value is List<dynamic>) {
    return List<dynamic>.from(value);
  }
  if (value is List) {
    return value.map((dynamic item) => item).toList();
  }
  return <dynamic>[];
}

List<dynamic>? _buildUpdatedLastMatches(
  List<dynamic> existing,
  int? performanceRating,
) {
  if (performanceRating == null) {
    return null;
  }

  final updated = List<dynamic>.from(existing);
  updated.add(performanceRating);

  while (updated.length > 5) {
    updated.removeAt(0);
  }

  return updated;
}

List<double>? _extractVectorValues(Map<String, dynamic>? mlVector) {
  if (mlVector == null) {
    return null;
  }

  final dynamic raw =
      mlVector['values'] ??
      mlVector['vector'] ??
      mlVector['embedding'] ??
      mlVector['data'];
  if (raw is! List) {
    return null;
  }

  final converted = <double>[];
  for (final item in raw) {
    if (item is num) {
      converted.add(item.toDouble());
    } else {
      final parsed = double.tryParse(item.toString());
      if (parsed != null) {
        converted.add(parsed);
      }
    }
  }

  if (converted.isEmpty) {
    return null;
  }

  return converted;
}

List<double> _recalculateAverageVector(
  List<dynamic> existingAverage,
  List<double> newVector,
  int existingCount,
) {
  if (existingCount <= 0 || existingAverage.isEmpty) {
    return newVector;
  }

  final currentAverage = <double>[];
  for (final item in existingAverage) {
    if (item is num) {
      currentAverage.add(item.toDouble());
    } else {
      final parsed = double.tryParse(item.toString());
      if (parsed != null) {
        currentAverage.add(parsed);
      }
    }
  }

  if (currentAverage.length != newVector.length) {
    return newVector;
  }

  final updated = <double>[];
  final updatedCount = existingCount + 1;
  for (var i = 0; i < newVector.length; i++) {
    final combined =
        ((currentAverage[i] * existingCount) + newVector[i]) / updatedCount;
    updated.add(combined);
  }

  return updated;
}
