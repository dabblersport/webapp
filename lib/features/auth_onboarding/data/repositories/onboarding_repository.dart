import 'package:supabase_flutter/supabase_flutter.dart';
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
            .from('profiles')
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

  /// Check if persona extension exists (player, organiser, or hoster table)
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

  /// Map persona type to actual table name
  String _getPersonaTableName(String personaType) {
    switch (personaType.toLowerCase()) {
      case 'player':
        return 'player';
      case 'organiser':
      case 'business':
        return 'organiser';
      case 'host':
      case 'hoster':
        return 'hoster';
      default:
        return 'player'; // Default fallback
    }
  }

  /// Check if sport_profiles entry exists
  Future<Result<bool, Failure>> sportProfileExists({
    required String profileId,
  }) async {
    return Result.guard(
      () async {
        final response = await _client
            .from('sport_profiles')
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
  /// STEP 4: Create Profile (FIRST DB WRITE)
  /// ═══════════════════════════════════════════════════════════════

  /// Create or update profile
  /// IDEMPOTENT: If profile exists, returns existing profile
  Future<Result<Map<String, dynamic>, Failure>> createProfile({
    required String personaType,
    required String username,
    required String displayName,
    required int age,
    required String gender,
    String? city,
    String? country,
    String? language,
    String? preferredSport,
    String? primarySport,
    List<String>? interestIds,
  }) async {
    return Result.guard(
      () async {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        // Check if profile already exists
        final existingProfiles = await getUserProfiles();
        final profiles = existingProfiles.fold(
          (failure) => <Map<String, dynamic>>[],
          (profiles) => profiles,
        );

        // If profile exists with same persona_type, return it
        final existing = profiles
            .where((p) => p['persona_type'] == personaType)
            .firstOrNull;
        if (existing != null) {
          return existing;
        }

        // Create new profile
        // Keep all persona types separate (player, organiser, host, socialiser)
        final profileType = personaType;

        final profileData = {
          'user_id': userId,
          'profile_type': profileType,
          'persona_type': personaType,
          'username': username,
          'display_name': displayName,
          'age': age,
          'gender': gender,
          'city': city,
          'country': country,
          'language': language ?? 'en',
          'preferred_sport': preferredSport,
          'primary_sport': primarySport,
          'interests': interestIds ?? [],
          'onboard': false, // Not complete yet
          'profile_completion': 'started',
        };

        final response = await _client
            .from('profiles')
            .insert(profileData)
            .select()
            .single();

        return response;
      },
      (error) => Failure(
        category: FailureCode.server,
        message: 'Failed to create profile: $error',
        cause: error,
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// STEP 5: Create Persona Extension (SECOND DB WRITE)
  /// ═══════════════════════════════════════════════════════════════

  /// Create persona extension (player, organiser, or hoster table)
  /// IDEMPOTENT: If row exists, does nothing
  Future<Result<void, Failure>> createPersonaExtension({
    required String profileId,
    required String personaType,
  }) async {
    return Result.guard(
      () async {
        // Check if already exists
        final exists = await personaExtensionExists(
          profileId: profileId,
          personaType: personaType,
        );

        final alreadyExists = exists.fold(
          (failure) => false,
          (exists) => exists,
        );

        if (alreadyExists) {
          return; // Already created
        }

        final tableName = _getPersonaTableName(personaType);

        await _client.from(tableName).insert({'profile_id': profileId});
      },
      (error) => Failure(
        category: FailureCode.server,
        message: 'Failed to create persona extension: $error',
        cause: error,
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// STEP 6: Create Sport Profile (THIRD DB WRITE)
  /// ═══════════════════════════════════════════════════════════════

  /// Create sport_profiles entry and update primary_sport
  /// IDEMPOTENT: If entry exists, just updates primary_sport
  Future<Result<void, Failure>> createSportProfile({
    required String profileId,
    required String sportId,
  }) async {
    return Result.guard(
      () async {
        // Check if sport_profiles entry already exists
        final exists = await sportProfileExists(profileId: profileId);
        final alreadyExists = exists.fold(
          (failure) => false,
          (exists) => exists,
        );

        if (!alreadyExists) {
          // Create sport_profiles entry
          await _client.from('sport_profiles').insert({
            'profile_id': profileId,
            'sport_id': sportId,
          });
        }

        // Update profile with primary_sport and profile_completion
        await _client
            .from('profiles')
            .update({
              'primary_sport': sportId,
              'profile_completion': 'sport_added',
            })
            .eq('id', profileId);
      },
      (error) => Failure(
        category: FailureCode.server,
        message: 'Failed to create sport profile: $error',
        cause: error,
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════
  /// STEP 7: Finalize Onboarding (LAST DB WRITE)
  /// ═══════════════════════════════════════════════════════════════

  /// Mark onboarding as complete
  Future<Result<void, Failure>> finalizeOnboarding({
    required String profileId,
  }) async {
    return Result.guard(
      () async {
        await _client
            .from('profiles')
            .update({'onboard': true, 'profile_completion': 'complete'})
            .eq('id', profileId);
      },
      (error) => Failure(
        category: FailureCode.server,
        message: 'Failed to finalize onboarding: $error',
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
            .from('sports')
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
