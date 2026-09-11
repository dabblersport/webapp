import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';

/// Repository for onboarding-related database operations
///
/// CRITICAL: All methods are idempotent and crash-safe
/// Follows DB-authoritative pattern - never assumes state
class OnboardingRepository {
  final SupabaseClient _client;

  OnboardingRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// ═══════════════════════════════════════════════════════════════
  /// STEP 1: Resume Check - Query existing profiles
  /// ═══════════════════════════════════════════════════════════════

  /// Get all profiles for current user
  /// Returns: List of profile maps (can be 0, 1, or 2 profiles)
  Future<Result<List<Map<String, dynamic>>, Failure>> getUserProfiles() async {
    return Result.guard(
      () async {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        final response = await _client
            .from(SupabaseConfig.usersTable)
            .select('''
              id,
              user_id,
              persona_type,
              username,
              display_name,
              age,
              gender,
              city,
              country,
              language,
              preferred_sport,
              primary_sport,
              interests,
              onboard,
              profile_completion
            ''')
            .eq('user_id', userId)
            .timeout(const Duration(seconds: 8));

        return List<Map<String, dynamic>>.from(response as List);
      },
      (error) => Failure(
        category: FailureCode.server,
        message: 'Failed to get user profiles: $error',
        cause: error,
      ),
    );
  }

  /// Check if persona extension exists (player, organiser, or host table)
  Future<Result<bool, Failure>> personaExtensionExists({
    required String profileId,
    required String personaType,
  }) async {
    return Result.guard(
      () async {
        // Map persona type to actual table name
        final tableName = _getPersonaTableName(personaType);

        final response = await _client
            .from(tableName)
            .select('profile_id')
            .eq('profile_id', profileId)
            .maybeSingle();

        return response != null;
      },
      (error) => Failure(
        category: FailureCode.server,
        message: 'Failed to check persona extension: $error',
        cause: error,
      ),
    );
  }

  /// Map persona type to actual table name.
  ///
  /// Throws on an unrecognised persona rather than defaulting to `'player'`
  /// (T-037) — that default was why `socialiser` profiles were checked
  /// against the `player` table instead of being recognised as having no
  /// extension table at all.
  String _getPersonaTableName(String personaType) {
    switch (personaType.toLowerCase()) {
      case 'player':
        return 'player';
      case 'organiser':
      case 'business':
        return 'organiser';
      case 'host':
        return 'host';
      default:
        throw Exception('Unrecognised persona type: $personaType');
    }
  }

  /// Check if sport_profiles entry exists
  Future<Result<bool, Failure>> sportProfileExists({
    required String profileId,
  }) async {
    return Result.guard(
      () async {
        final response = await _client
            .from(SupabaseConfig.sportProfilesTable)
            .select('id')
            .eq('profile_id', profileId)
            .maybeSingle();

        return response != null;
      },
      (error) => Failure(
        category: FailureCode.server,
        message: 'Failed to check sport profile: $error',
        cause: error,
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// UTILITY: Get sport by slug
  /// ═══════════════════════════════════════════════════════════════

  /// Get sport ID from slug
  Future<Result<String, Failure>> getSportIdBySlug(String slug) async {
    return Result.guard(
      () async {
        final response = await _client
            .from(SupabaseConfig.sportsTable)
            .select('id')
            .eq('slug', slug)
            .single();

        return response['id'] as String;
      },
      (error) => Failure(
        category: FailureCode.notFound,
        message: 'Sport not found: $slug',
        cause: error,
      ),
    );
  }
}
