import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/features/profile/domain/models/persona_rules.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';

/// Service to handle profile creation for the ADD PERSONA flow
///
/// This service creates a new profile for an existing authenticated user.
/// It does NOT create a new account, only a new profile row with associated
/// persona-specific tables.
///
/// Tables affected:
/// - profiles: New row with persona_type
/// - sport_profiles: New row for primary sport
/// - player/organiser/hoster: New row if applicable
/// - profile_tiers: New tier assignment (defaults to 'member')
class ProfileCreationService {
  final SupabaseClient _client;

  ProfileCreationService(this._client);

  /// Create a new profile for the given persona
  ///
  /// [data] - The collected add persona data
  ///
  /// Returns the created profile ID on success
  ///
  /// For CONVERSION flows, [deactivateProfileId] should be provided
  /// to mark the old profile as inactive before creating the new one.
  Future<String> createProfile({
    required AddPersonaData data,
    String? deactivateProfileId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Validate required data
    if (data.primarySport == null || data.primarySport!.isEmpty) {
      throw Exception('Primary sport is required');
    }
    if (data.displayName == null || data.displayName!.isEmpty) {
      throw Exception('Display name is required');
    }
    if (data.username == null || data.username!.isEmpty) {
      throw Exception('Username is required');
    }

    // Map persona_type to profile_type (structural container type)
    final String profileType;
    switch (data.targetPersona) {
      case PersonaType.player:
        profileType = 'personal';
        break;
      case PersonaType.organiser:
        profileType = 'business';
        break;
      case PersonaType.hoster:
        profileType = 'venue';
        break;
      case PersonaType.socialiser:
        profileType = 'personal';
        break;
    }

    try {
      // 1️⃣ If conversion, deactivate old profile first
      // This ensures profile count stays within limit
      if (deactivateProfileId != null) {
        await _client
            .from('profiles')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', deactivateProfileId)
            .eq('user_id', user.id);
      }

      // 2️⃣ Check current active profile count (excluding deactivated profile)
      final activeProfilesResponse = await _client
          .from('profiles')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_active', true);

      final activeCount = (activeProfilesResponse as List).length;

      // Verify profile limit before creating new profile
      if (!PersonaRules.canAddNewProfile(activeCount)) {
        throw ProfileLimitException(
          'You can have up to ${PersonaRules.maxActiveProfiles} profiles. '
          'To create a new one, deactivate an existing profile.',
        );
      }

      // 3️⃣ Check if a profile with same user_id + profile_type already exists
      final existingProfile = await _client
          .from('profiles')
          .select('id, persona_type, is_active')
          .eq('user_id', user.id)
          .eq('profile_type', profileType)
          .maybeSingle();

      if (existingProfile != null) {
        final existingPersona = existingProfile['persona_type'] as String?;
        final existingId = existingProfile['id'] as String;
        final isActive = existingProfile['is_active'] as bool? ?? true;

        // If same persona_type and active, this persona already exists
        if (existingPersona == data.targetPersona.name && isActive) {
          throw Exception(
            'You already have an active ${data.targetPersona.displayName} profile.',
          );
        }

        // If same profile_type but different persona or inactive, update it
        // Map persona to intention
        final String intention;
        switch (data.targetPersona) {
          case PersonaType.player:
            intention = 'compete';
            break;
          case PersonaType.organiser:
            intention = 'organise';
            break;
          case PersonaType.hoster:
            intention = 'host';
            break;
          case PersonaType.socialiser:
            intention = 'socialise';
            break;
        }

        final updateData = {
          'display_name': data.displayName,
          'username': data.username,
          'age': data.age,
          'gender': data.gender?.toLowerCase(),
          'persona_type': data.targetPersona.name,
          'preferred_sport': data.primarySport!, // UUID
          'primary_sport': data.primarySport!, // UUID
          'interests': data.interests, // list of sport UUIDs
          'intention': intention,
          'is_player': data.targetPersona == PersonaType.player,
          'skill_level': 1,
          'onboard': true,
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _client
            .from('profiles')
            .update(updateData)
            .eq('id', existingId)
            .eq('user_id', user.id);

        // Use existing profile ID for subsequent operations
        final profileId = existingId;

        // Continue with sport profiles etc using this ID
        return await _setupProfileExtras(profileId: profileId, data: data);
      }

      // 4️⃣ Create new profile row (no existing profile with this profile_type)
      // Map persona to intention
      final String intention;
      switch (data.targetPersona) {
        case PersonaType.player:
          intention = 'compete';
          break;
        case PersonaType.organiser:
          intention = 'organise';
          break;
        case PersonaType.hoster:
          intention = 'host';
          break;
        case PersonaType.socialiser:
          intention = 'socialise';
          break;
      }

      final profileData = {
        'user_id': user.id,
        'display_name': data.displayName,
        'username': data.username,
        'age': data.age,
        'gender': data.gender?.toLowerCase(),
        'profile_type': profileType,
        'persona_type': data.targetPersona.name,
        'preferred_sport': data.primarySport!, // UUID
        'primary_sport': data.primarySport!, // UUID
        'interests': data.interests, // list of sport UUIDs
        'intention': intention,
        'is_player': data.targetPersona == PersonaType.player,
        'skill_level': 1,
        'onboard': true,
        'is_active': true,
      };

      final insertedProfile = await _client
          .from('profiles')
          .insert(profileData)
          .select('id')
          .single();

      final profileId = insertedProfile['id'] as String;

      // 5️⃣ Set up sport profiles, persona tables, and tier
      return await _setupProfileExtras(profileId: profileId, data: data);
    } on PostgrestException catch (e) {
      // Handle Supabase database errors
      if (e.message.contains('more than 2 active profiles') ||
          e.code == '23514') {
        // Check constraint violation for profile limit
        throw ProfileLimitException(
          'You can have up to ${PersonaRules.maxActiveProfiles} profiles. '
          'To create a new one, deactivate an existing profile.',
        );
      }
      // Re-throw other database errors
      rethrow;
    } on ProfileLimitException {
      // Don't wrap ProfileLimitException
      rethrow;
    }
  }

  /// Helper to set up sport profiles, persona-specific tables, and tier
  Future<String> _setupProfileExtras({
    required String profileId,
    required AddPersonaData data,
  }) async {
    // Get sport record from sports table using UUID (primarySport is a UUID)
    final sportRecord = await _client
        .from('sports')
        .select('id, sport_key')
        .eq('id', data.primarySport!)
        .maybeSingle();

    if (sportRecord == null) {
      throw Exception(
        'Sport with ID "${data.primarySport}" not found in sports table.',
      );
    }

    final sportId = sportRecord['id'] as String;
    final sportKey = sportRecord['sport_key'] as String;

    // Check if sport_profile already exists for this profile
    // Note: sport_profiles uses composite key (profile_id, sport_id), not a separate id column
    final existingSportProfile = await _client
        .from('sport_profiles')
        .select('profile_id')
        .eq('profile_id', profileId)
        .eq('sport_id', sportId)
        .maybeSingle();

    if (existingSportProfile == null) {
      // Create sport_profiles row
      final sportProfileData = {
        'profile_id': profileId,
        'sport': sportKey, // text sport_key for legacy column
        'sport_id': sportId, // UUID
        'skill_level': 1, // Beginner level
      };

      await _client.from('sport_profiles').insert(sportProfileData);
    }

    // Create persona-specific table row if applicable
    switch (data.targetPersona) {
      case PersonaType.player:
        await _createPlayerProfile(profileId);
        break;
      case PersonaType.organiser:
        await _createOrganiserProfile(profileId);
        break;
      case PersonaType.hoster:
        await _createHosterProfile(profileId);
        break;
      case PersonaType.socialiser:
        // Socialiser has no separate table
        break;
    }

    // Assign tier (defaults to 'member')
    await _assignProfileTier(profileId);

    return profileId;
  }

  /// Create player profile row
  Future<void> _createPlayerProfile(String profileId) async {
    try {
      // Check if row already exists
      final existing = await _client
          .from('player')
          .select('profile_id')
          .eq('profile_id', profileId)
          .maybeSingle();

      if (existing == null) {
        await _client.from('player').insert({'profile_id': profileId});
      }
    } catch (e) {
      // Player table insert is best-effort
      // Some deployments may not have triggers configured
    }
  }

  /// Create organiser profile row
  Future<void> _createOrganiserProfile(String profileId) async {
    try {
      final existing = await _client
          .from('organiser')
          .select('profile_id')
          .eq('profile_id', profileId)
          .maybeSingle();

      if (existing == null) {
        await _client.from('organiser').insert({'profile_id': profileId});
      }
    } catch (e) {
      // Organiser table insert is best-effort
    }
  }

  /// Create hoster profile row
  Future<void> _createHosterProfile(String profileId) async {
    try {
      final existing = await _client
          .from('hoster')
          .select('profile_id')
          .eq('profile_id', profileId)
          .maybeSingle();

      if (existing == null) {
        await _client.from('hoster').insert({'profile_id': profileId});
      }
    } catch (e) {
      // Hoster table insert is best-effort
    }
  }

  /// Assign profile tier (defaults to 'member')
  Future<void> _assignProfileTier(String profileId) async {
    try {
      // Get member tier ID
      final tierRecord = await _client
          .from('tiers')
          .select('id')
          .eq('name', 'member')
          .maybeSingle();

      if (tierRecord != null) {
        final tierId = tierRecord['id'] as String;

        // Check if tier assignment exists
        final existing = await _client
            .from('profile_tiers')
            .select('id')
            .eq('profile_id', profileId)
            .maybeSingle();

        if (existing == null) {
          await _client.from('profile_tiers').insert({
            'profile_id': profileId,
            'tier_id': tierId,
          });
        }
      }
    } catch (e) {
      // Tier assignment is best-effort
    }
  }

  /// Check if a username is available
  Future<bool> isUsernameAvailable(String username) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final result = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .neq('user_id', user.id) // Exclude current user's profiles
        .limit(1)
        .maybeSingle();

    return result == null;
  }
}

/// Exception thrown when user tries to exceed the profile limit
class ProfileLimitException implements Exception {
  final String message;

  ProfileLimitException(this.message);

  @override
  String toString() => message;
}
