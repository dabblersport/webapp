import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';

/// PDPL/GDPR export collectors for sport profiles and gameplay statistics
/// (KAN-893). Copied verbatim in behaviour from
/// `DataExportService._getEnhancedSportsProfileData` and
/// `_getEnhancedStatisticsData`; each returns `null` on failure and never
/// throws.

void _warning(String message, [dynamic error]) =>
    debugPrint('[WARNING] $message${error != null ? ': $error' : ''}');

Future<List<Map<String, dynamic>>?> collectSportsProfiles(
  SupabaseClient client,
  String userId,
) async {
  try {
    // First get profile_id from user_id
    final profileResponse = await client
        .from(SupabaseConfig.usersTable)
        .select('id')
        .eq('user_id', userId)
        .eq('profile_type', 'personal')
        .maybeSingle();

    if (profileResponse == null) {
      return [];
    }

    final profileId = profileResponse['id'] as String;

    final response = await client
        .from(SupabaseConfig.sportProfilesTable)
        .select('*')
        .eq('profile_id', profileId);

    return response
        .map<Map<String, dynamic>>(
          (item) => {
            ...item,
            'data_source': 'sport_profiles table',
            'purpose': 'Sports skill assessment and matching',
            'legal_basis': 'User consent and contract performance',
          },
        )
        .toList();
  } catch (e) {
    _warning('Could not fetch sports profile data', e);
    return null;
  }
}

Future<Map<String, dynamic>?> collectStatistics(
  SupabaseClient client,
  String userId,
) async {
  try {
    // Reconciled (KAN-103): `user_game_statistics` and
    // `performance_metrics` never existed as tables. The real gameplay
    // performance data lives directly on `sport_profiles` (per-sport
    // columns: matches_played, xp_*, form_score, attendance/cancellation/
    // punctuality/teamwork/reliability scores, performance_highlights,
    // performance_by_venue), and the cross-sport reputation aggregate
    // lives in `user_reputation_aggregate`. This is not a rename of a
    // missing table into an existing one used for something else — it's
    // the actual data this category was always meant to describe.
    final profileResponse = await client
        .from(SupabaseConfig.usersTable)
        .select('id')
        .eq('user_id', userId)
        .eq('profile_type', 'personal')
        .maybeSingle();

    List<dynamic> perSportPerformance = const [];
    if (profileResponse != null) {
      final profileId = profileResponse['id'] as String;
      perSportPerformance = await client
          .from(SupabaseConfig.sportProfilesTable)
          .select(
            'sport, skill_level, overall_level, xp_total, xp_level, '
            'matches_played, form_score, form_trend, last_5_matches, '
            'attendance_rate, cancellation_rate, punctuality_score, '
            'teamwork_score, reliability_score, rating_count, '
            'rating_total, performance_highlights, performance_by_venue',
          )
          .eq('profile_id', profileId);
    }

    final reputationAggregate = await client
        .from(SupabaseConfig.userReputationAggregateTable)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    return {
      'per_sport_performance': perSportPerformance,
      'reputation_aggregate': reputationAggregate,
      'data_source':
          'sport_profiles (performance columns), user_reputation_aggregate tables',
      'purpose': 'Performance tracking and skill assessment',
      'legal_basis': 'User consent',
      'retention_period': '3 years or until consent withdrawal',
      'note':
          'There is no separate user_game_statistics/performance_metrics '
          'table - this reflects the actual gameplay performance and '
          'reputation data Dabbler stores about you.',
    };
  } catch (e) {
    _warning('Could not fetch statistics data', e);
    return null;
  }
}
