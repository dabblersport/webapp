import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;
import 'profile_remote_datasource.dart';
import 'package:dabbler/data/models/models.dart';

/// Supabase implementation of ProfileRemoteDataSource
class SupabaseProfileDataSource implements ProfileRemoteDataSource {
  final SupabaseClient _client;
  final String _usersTable = 'profiles'; // Changed from 'users' to 'profiles'
  // Profile columns from public.profiles (no email/phone - those are in auth.users)
  static const String _baseProfileColumns =
      'id, user_id, username, display_name, avatar_url, created_at, updated_at, bio, age, city, country, gender, profile_type, intention, preferred_sport, interests, language, verified, is_active, geo_lat, geo_lng';
  final String _sportProfilesTable = 'sport_profiles';
  // Note: user_statistics table does not exist - feature disabled for MVP1
  final String _avatarBucket = 'avatars';
  final String _blockedUsersTable = 'blocked_users';
  final String _profileViewsTable = 'profile_views';
  final String _reportsTable = 'profile_reports';

  SupabaseProfileDataSource(this._client);

  @override
  Future<UserProfile> getProfile(
    String userId, {
    bool includeSports = true,
    String? profileType,
  }) async {
    try {
      final response = profileType != null
          ? await _fetchProfileRow(
              userId,
              includeSports: includeSports,
              profileType: profileType,
            )
          : await _preferPlayerProfile(userId, includeSports: includeSports);

      if (response == null) {
        throw const DataNotFoundException(message: 'Profile not found');
      }

      return UserProfile.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const DataNotFoundException(message: 'Profile not found');
      }
      throw ServerException(
        message: 'Database error: ${e.message}',
        details: e,
      );
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Failed to fetch profile: $e');
    }
  }

  /// Get all profiles for a user (player and organiser)
  Future<List<UserProfile>> getAllProfiles(
    String userId, {
    bool includeSports = true,
  }) async {
    try {
      final response = await _client
          .from(_usersTable)
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      if (response.isEmpty) {
        return [];
      }

      final profiles = <UserProfile>[];
      for (final row in response) {
        final result = Map<String, dynamic>.from(row);
        await _enrichWithAuthData(result, userId);

        if (includeSports) {
          await _enrichWithSportProfiles(result, result['id'] as String);
        }

        profiles.add(UserProfile.fromJson(result));
      }

      return profiles;
    } on PostgrestException catch (e) {
      throw ServerException(
        message: 'Database error: ${e.message}',
        details: e,
      );
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Failed to fetch profiles: $e');
    }
  }

  Future<Map<String, dynamic>?> _preferPlayerProfile(
    String userId, {
    required bool includeSports,
  }) async {
    // Try to load the player's profile first; fall back to organiser/any profile.
    final playerProfile = await _fetchProfileRow(
      userId,
      includeSports: includeSports,
      profileType: 'player',
    );

    if (playerProfile != null) {
      return playerProfile;
    }

    final organiserProfile = await _fetchProfileRow(
      userId,
      includeSports: includeSports,
      profileType: 'organiser',
    );

    if (organiserProfile != null) {
      return organiserProfile;
    }

    return _fetchProfileRow(userId, includeSports: includeSports);
  }

  Future<Map<String, dynamic>?> _fetchProfileRow(
    String userId, {
    required bool includeSports,
    String? profileType,
  }) async {
    // Build select query - fetch profile first
    var query = _client.from(_usersTable).select('*').eq('user_id', userId);

    if (profileType != null) {
      query = query.eq('profile_type', profileType);
      final response = await query.maybeSingle();
      if (response == null) {
        return null;
      }
      final result = Map<String, dynamic>.from(response);

      // Fetch email and phone from auth.users separately
      await _enrichWithAuthData(result, userId);

      // Fetch sport_profiles separately if requested
      if (includeSports) {
        await _enrichWithSportProfiles(result, result['id'] as String);
      }

      return result;
    }

    final response = await query
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final result = Map<String, dynamic>.from(response);

    // Fetch email and phone from auth.users separately
    await _enrichWithAuthData(result, userId);

    // Fetch sport_profiles separately if requested
    if (includeSports) {
      await _enrichWithSportProfiles(result, result['id'] as String);
    }

    return result;
  }

  /// Enriches profile data with sport_profiles from sport_profiles table
  Future<void> _enrichWithSportProfiles(
    Map<String, dynamic> profile,
    String profileId,
  ) async {
    try {
      final sportProfilesResponse = await _client
          .from(_sportProfilesTable)
          .select('*')
          .eq('profile_id', profileId);

      // Supabase select always returns a List
      profile['sport_profiles'] = sportProfilesResponse as List;
    } on PostgrestException {
      // Log the error for debugging but don't fail the profile fetch
      profile['sport_profiles'] = [];
    } catch (e) {
      // If we can't get sport profiles, set empty list
      // This is not critical as UserProfile handles empty sport_profiles
      profile['sport_profiles'] = [];
    }
  }

  /// Enriches profile data with email and phone from auth.users
  Future<void> _enrichWithAuthData(
    Map<String, dynamic> profile,
    String userId,
  ) async {
    try {
      // Query auth.users through RPC or admin API if available
      // For now, we'll try to get it from the current session
      final user = _client.auth.currentUser;
      if (user != null && user.id == userId) {
        profile['email'] = user.email;
        profile['phone_number'] = user.phone;
      }
    } catch (e) {
      // If we can't get auth data, leave it null
      // This is not critical as UserProfile handles null email/phone
    }
  }

  @override
  Future<UserProfile> createProfile(UserProfile profile) async {
    try {
      // Validate profile data
      final profileData = profile.toJson();
      _validateProfileData(profileData);

      // Check if profile already exists
      final existing = await profileExists(profile.id);
      if (existing) {
        throw const ConflictException(message: 'Profile already exists');
      }

      // Insert profile
      final response = await _client
          .from(_usersTable)
          .insert(profileData)
          .select(_baseProfileColumns)
          .single();

      // Note: Statistics feature disabled for MVP1 - user_statistics table does not exist
      // await _client.from(_statisticsTable).insert({
      //   'id': profile.id,
      //   'profile_views': 0,
      //   'games_played': 0,
      //   'games_won': 0,
      //   'total_playtime_hours': 0,
      //   'average_rating': 0.0,
      //   'achievements_unlocked': 0,
      //   'streak_days': 0,
      //   'longest_streak': 0,
      //   'created_at': DateTime.now().toIso8601String(),
      //   'updated_at': DateTime.now().toIso8601String(),
      // });

      return UserProfile.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Unique constraint violation
        throw const ConflictException(message: 'Profile already exists');
      }
      throw ServerException(
        message: 'Database error: ${e.message}',
        details: e,
      );
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Failed to create profile: $e');
    }
  }

  @override
  Future<UserProfile> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Validate updates
      _validateProfileUpdates(updates);

      // Add updated timestamp
      final updateData = {
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from(_usersTable)
          .update(updateData)
          .eq('user_id', userId)
          .select(_baseProfileColumns)
          .single();

      return UserProfile.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const DataNotFoundException(message: 'Profile not found');
      }
      throw ServerException(
        message: 'Database error: ${e.message}',
        details: e,
      );
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Failed to update profile: $e');
    }
  }

  @override
  Future<void> deleteProfile(String userId) async {
    try {
      // Delete in order: sport_profiles, then profile
      // Note: Statistics feature disabled for MVP1
      // await _client.from(_statisticsTable).delete().eq('user_id', userId);

      // Get profile ID first
      final profileResponse = await _client
          .from(_usersTable)
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (profileResponse != null) {
        final profileId = profileResponse['id'] as String;
        await _client
            .from(_sportProfilesTable)
            .delete()
            .eq('profile_id', profileId);
      }

      final response = await _client
          .from(_usersTable)
          .delete()
          .eq('user_id', userId)
          .select('id');

      if (response.isEmpty) {
        throw const DataNotFoundException(message: 'Profile not found');
      }

      // Also delete avatar if exists
      try {
        await deleteAvatar(userId);
      } catch (e) {
        // Avatar deletion failure shouldn't block profile deletion
        // ...existing code...
      }
    } on PostgrestException catch (e) {
      throw ServerException(
        message: 'Database error: ${e.message}',
        details: e,
      );
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Failed to delete profile: $e');
    }
  }

  @override
  Future<bool> profileExists(String userId) async {
    try {
      final response = await _client
          .from(_usersTable)
          .select('user_id')
          .eq('user_id', userId)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      throw NetworkException(message: 'Failed to check profile existence: $e');
    }
  }

  @override
  Future<String> uploadAvatar(
    String userId,
    File imageFile, {
    String? fileName,
    Map<String, String>? metadata,
    Function(double)? onProgress,
  }) async {
    try {
      // Validate file
      await _validateImageFile(imageFile);

      final fileExt = imageFile.path.split('.').last.toLowerCase();
      final filePath = '$userId/avatar.$fileExt';

      // Read file bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to storage
      await _client.storage
          .from(_avatarBucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$fileExt',
            ),
          );

      // Get public URL
      final publicUrl = _client.storage
          .from(_avatarBucket)
          .getPublicUrl(filePath);

      // Update profile with new avatar URL
      await updateAvatarUrl(userId, publicUrl);

      return publicUrl;
    } on StorageException catch (e) {
      if (e.message.contains('storage quota')) {
        throw const StorageQuotaException(message: 'Storage quota exceeded');
      }
      throw StorageException(
        message: 'Upload failed: ${e.message}',
        details: e,
      );
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw StorageException(message: 'Avatar upload failed: $e');
    }
  }

  @override
  Future<UserProfile> updateAvatarUrl(String userId, String avatarUrl) async {
    try {
      return await updateProfile(userId, {'avatar_url': avatarUrl});
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw ValidationException(
        message: 'Failed to update avatar URL',
        errors: ['Invalid avatar URL: $avatarUrl'],
      );
    }
  }

  @override
  Future<void> deleteAvatar(String userId) async {
    try {
      // Get current profile to find avatar path
      final profile = await getProfile(userId, includeSports: false);

      if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
        // Extract file path from URL
        final uri = Uri.parse(profile.avatarUrl!);
        final pathSegments = uri.pathSegments;

        if (pathSegments.length >= 2) {
          final filePath = pathSegments
              .sublist(pathSegments.length - 2)
              .join('/');

          // Delete from storage
          await _client.storage.from(_avatarBucket).remove([filePath]);
        }

        // Remove avatar URL from profile
        await updateProfile(userId, {'avatar_url': null});
      }
    } on StorageException catch (e) {
      throw StorageException(
        message: 'Failed to delete avatar: ${e.message}',
        details: e,
      );
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw StorageException(message: 'Avatar deletion failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getAvatarUploadUrl(
    String userId,
    String fileName,
  ) async {
    try {
      final fileExt = fileName.split('.').last.toLowerCase();
      final filePath = '$userId/avatar.$fileExt';

      final signedUrl = await _client.storage
          .from(_avatarBucket)
          .createSignedUploadUrl(filePath);

      return {
        'upload_url': signedUrl,
        'file_path': filePath,
        'expires_in': 3600, // 1 hour
      };
    } catch (e) {
      throw StorageException(message: 'Failed to generate upload URL: $e');
    }
  }

  @override
  Future<List<SportProfileModel>> getSportProfiles(String userId) async {
    try {
      // First get profile_id from user_id
      final profileResponse = await _client
          .from(_usersTable)
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (profileResponse == null) {
        return [];
      }

      final profileId = profileResponse['id'] as String;

      // Query sport_profiles using profile_id (simple schema)
      final response = await _client
          .from(_sportProfilesTable)
          .select('*')
          .eq('profile_id', profileId);

      return response
          .map<SportProfileModel>((json) => SportProfileModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(
        message: 'Database error: ${e.message}',
        details: e,
      );
    } catch (e) {
      throw NetworkException(message: 'Failed to fetch sport profiles: $e');
    }
  }

  @override
  Future<SportProfileModel> addSportProfile(
    String userId,
    SportProfileModel sportProfile,
  ) async {
    try {
      // Get profile_id from user_id
      final profileResponse = await _client
          .from(_usersTable)
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (profileResponse == null) {
        throw const DataNotFoundException(message: 'Profile not found');
      }

      final profileId = profileResponse['id'] as String;

      // Use simple schema: profile_id, sport_key, skill_level
      final profileData = sportProfile.toInsertJson();
      profileData['profile_id'] = profileId; // Override with actual profile_id

      final response = await _client
          .from(_sportProfilesTable)
          .insert(profileData)
          .select('*')
          .single();

      return SportProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Unique constraint violation
        throw const ConflictException(message: 'Sport profile already exists');
      }
      throw ServerException(
        message: 'Database error: ${e.message}',
        details: e,
      );
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Failed to add sport profile: $e');
    }
  }

  @override
  Future<SportProfileModel> updateSportProfile(
    String userId,
    String sportId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Get profile_id from user_id
      final profileResponse = await _client
          .from(_usersTable)
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (profileResponse == null) {
        throw const DataNotFoundException(message: 'Profile not found');
      }

      final profileId = profileResponse['id'] as String;

      // Simple schema only supports updating skill_level
      final updateData = <String, dynamic>{};
      if (updates.containsKey('skill_level') ||
          updates.containsKey('skillLevel')) {
        final skillLevel = updates['skill_level'] ?? updates['skillLevel'];
        if (skillLevel is int) {
          updateData['skill_level'] = skillLevel;
        } else if (skillLevel is SkillLevel) {
          updateData['skill_level'] = skillLevel.index;
        }
      }

      final response = await _client
          .from(_sportProfilesTable)
          .update(updateData)
          .eq('profile_id', profileId)
          .eq('sport_key', sportId) // Use sport_key instead of sport_id
          .select('*')
          .single();

      return SportProfileModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw const DataNotFoundException(message: 'Sport profile not found');
      }
      throw ServerException(
        message: 'Database error: ${e.message}',
        details: e,
      );
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Failed to update sport profile: $e');
    }
  }

  @override
  Future<void> removeSportProfile(String userId, String sportId) async {
    try {
      // Get profile_id from user_id
      final profileResponse = await _client
          .from(_usersTable)
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (profileResponse == null) {
        throw const DataNotFoundException(message: 'Profile not found');
      }

      final profileId = profileResponse['id'] as String;

      // Delete using profile_id and sport_key (simple schema)
      await _client
          .from(_sportProfilesTable)
          .delete()
          .eq('profile_id', profileId)
          .eq('sport_key', sportId);
    } on PostgrestException catch (e) {
      throw ServerException(
        message: 'Database error: ${e.message}',
        details: e,
      );
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Failed to remove sport profile: $e');
    }
  }

  @override
  Future<List<SportProfileModel>> bulkUpdateSportProfiles(
    String userId,
    List<Map<String, dynamic>> updates,
  ) async {
    try {
      final List<SportProfileModel> updatedProfiles = [];

      for (final update in updates) {
        // Support both sport_id and sport_key for backward compatibility
        final sportId =
            update['sport_key'] as String? ?? update['sport_id'] as String?;

        if (sportId == null) {
          throw const ValidationException(
            message: 'sport_key is required for bulk updates',
            errors: ['Missing sport_key in update data'],
          );
        }

        final updateData = Map<String, dynamic>.from(update)
          ..remove('sport_id')
          ..remove('sport_key');

        final updatedProfile = await updateSportProfile(
          userId,
          sportId,
          updateData,
        );
        updatedProfiles.add(updatedProfile);
      }

      return updatedProfiles;
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Bulk update failed: $e');
    }
  }

  @override
  Future<ProfileStatisticsModel> getProfileStatistics(String userId) async {
    // Note: Statistics feature disabled for MVP1 - user_statistics table does not exist
    // Return empty statistics model
    return const ProfileStatisticsModel(
      totalGamesPlayed: 0,
      totalGamesOrganized: 0,
      totalWins: 0,
      totalLosses: 0,
      totalDraws: 0,
      totalHoursPlayed: 0.0,
      averageGameDuration: 0.0,
      currentWinStreak: 0,
      longestWinStreak: 0,
      currentPlayStreak: 0,
      longestPlayStreak: 0,
      uniqueTeammates: 0,
      uniqueVenues: 0,
      averageRating: 0.0,
      totalRatingsReceived: 0,
      achievements: [],
      badges: [],
      lastGameDate: null,
      sportGamesCount: {},
    );
  }

  @override
  Future<ProfileStatisticsModel> updateStatistics(
    String userId,
    Map<String, dynamic> stats,
  ) async {
    // Note: Statistics feature disabled for MVP1 - user_statistics table does not exist
    // Return empty statistics model
    return const ProfileStatisticsModel(
      totalGamesPlayed: 0,
      totalGamesOrganized: 0,
      totalWins: 0,
      totalLosses: 0,
      totalDraws: 0,
      totalHoursPlayed: 0.0,
      averageGameDuration: 0.0,
      currentWinStreak: 0,
      longestWinStreak: 0,
      currentPlayStreak: 0,
      longestPlayStreak: 0,
      uniqueTeammates: 0,
      uniqueVenues: 0,
      averageRating: 0.0,
      totalRatingsReceived: 0,
      achievements: [],
      badges: [],
      lastGameDate: null,
      sportGamesCount: {},
    );
  }

  @override
  Future<ProfileStatisticsModel> incrementStats(
    String userId,
    Map<String, int> counters,
  ) async {
    try {
      // Build SQL for atomic increments - use direct RPC call
      await _client.rpc(
        'increment_profile_stats',
        params: {'user_id_param': userId, 'increments': counters},
      );

      // Fetch updated statistics
      return await getProfileStatistics(userId);
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Failed to increment statistics: $e');
    }
  }

  @override
  Future<ProfileStatisticsModel> resetStatistics(
    String userId,
    List<String> statKeys,
  ) async {
    try {
      final resetData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      for (final key in statKeys) {
        resetData[key] = 0;
      }

      return await updateStatistics(userId, resetData);
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Failed to reset statistics: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> searchProfiles({
    String? query,
    List<String>? sportTypes,
    String? location,
    int? skillLevel,
    List<int>? ageRange,
    String? gender,
    double? maxDistance,
    Map<String, double>? coordinates,
    int limit = 20,
    int offset = 0,
    String sortBy = 'relevance',
  }) async {
    try {
      dynamic searchQuery = _client.from(_usersTable).select('*');

      // Apply filters
      if (query != null && query.isNotEmpty) {
        searchQuery = searchQuery.textSearch('display_name,bio', query);
      }

      if (gender != null) {
        searchQuery = searchQuery.eq('gender', gender);
      }

      if (ageRange != null && ageRange.length == 2) {
        final minAge = ageRange[0];
        final maxAge = ageRange[1];
        final minBirthYear = DateTime.now().year - maxAge;
        final maxBirthYear = DateTime.now().year - minAge;

        searchQuery = searchQuery
            .gte('birth_year', minBirthYear)
            .lte('birth_year', maxBirthYear);
      }

      if (location != null) {
        searchQuery = searchQuery.ilike('location', '%$location%');
      }

      // Apply pagination and sorting
      searchQuery = searchQuery.range(offset, offset + limit - 1);

      switch (sortBy) {
        case 'created_at':
          searchQuery = searchQuery.order('created_at', ascending: false);
          break;
        case 'updated_at':
          searchQuery = searchQuery.order('updated_at', ascending: false);
          break;
        case 'name':
          searchQuery = searchQuery.order('display_name');
          break;
        default:
          // For relevance, we'll use created_at for now
          searchQuery = searchQuery.order('created_at', ascending: false);
      }

      final response = await searchQuery;

      // Enrich each profile with sport_profiles
      final profilesList = <Map<String, dynamic>>[];
      for (final json in response) {
        final profileJson = Map<String, dynamic>.from(json);
        await _enrichWithSportProfiles(
          profileJson,
          profileJson['id'] as String,
        );
        profilesList.add(profileJson);
      }

      final profiles = profilesList
          .map<UserProfile>((json) => UserProfile.fromJson(json))
          .toList();

      // Get total count for pagination
      var countQuery = _client.from(_usersTable).select('*');

      if (query != null && query.isNotEmpty) {
        countQuery = countQuery.textSearch('display_name,bio', query);
      }
      if (gender != null) {
        countQuery = countQuery.eq('gender', gender);
      }

      final countResponse = await countQuery;
      final totalCount = countResponse.length;

      return {
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'total_count': totalCount,
        'limit': limit,
        'offset': offset,
        'has_more': totalCount > (offset + limit),
      };
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Profile search failed: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getRecommendations(
    String userId, {
    int limit = 10,
    List<String>? sportTypes,
    String? location,
    double? maxDistance,
  }) async {
    try {
      // This would typically use a more sophisticated recommendation algorithm
      // For now, we'll return profiles with similar sports and location
      final userProfile = await getProfile(userId, includeSports: true);
      final userSports = userProfile.sportsProfiles
          .map((sp) => sp.sportId)
          .toList();

      dynamic query = _client.from(_usersTable).select('*').neq('id', userId);

      if (userProfile.city != null || userProfile.country != null) {
        if (userProfile.city != null) {
          query = query.ilike('city', '%${userProfile.city}%');
        }
        if (userProfile.country != null) {
          query = query.ilike('country', '%${userProfile.country}%');
        }
      }

      if (sportTypes != null) {
        // This would require a more complex query with joins
        // For now, we'll fetch all and filter in memory
      }

      query = query.limit(limit * 2); // Get more to filter and rank

      final response = await query;

      // Enrich each profile with sport_profiles
      final profilesList = <Map<String, dynamic>>[];
      for (final json in response) {
        final profileJson = Map<String, dynamic>.from(json);
        await _enrichWithSportProfiles(
          profileJson,
          profileJson['id'] as String,
        );
        profilesList.add(profileJson);
      }

      final profiles = profilesList
          .map<UserProfile>((json) => UserProfile.fromJson(json))
          .toList();

      // Simple scoring based on common sports
      final recommendations = profiles
          .map((profile) {
            final profileSports = profile.sportsProfiles
                .map((sp) => sp.sportId)
                .toList();
            final commonSports = userSports
                .where((sport) => profileSports.contains(sport))
                .length;

            return {
              'profile': profile.toJson(),
              'similarity_score':
                  commonSports.toDouble() /
                  (userSports.length + profileSports.length - commonSports)
                      .clamp(1, double.infinity),
              'common_sports': commonSports,
            };
          })
          .where((item) => (item['similarity_score'] as double) > 0)
          .toList();

      recommendations.sort(
        (a, b) => (b['similarity_score'] as double).compareTo(
          a['similarity_score'] as double,
        ),
      );

      return recommendations.take(limit).toList();
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Failed to get recommendations: $e');
    }
  }

  @override
  Future<List<UserProfile>> getProfilesNearLocation(
    double latitude,
    double longitude,
    double radiusKm, {
    int limit = 20,
    List<String>? sportTypes,
  }) async {
    try {
      // This would typically use PostGIS for geographic queries
      // For now, we'll use a simple coordinate-based filter
      final response = await _client.rpc(
        'get_profiles_near_location',
        params: {
          'lat': latitude,
          'lng': longitude,
          'radius_km': radiusKm,
          'max_results': limit,
          'sport_types': sportTypes,
        },
      );

      return (response as List)
          .map<UserProfile>((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(
        message: 'Failed to get profiles near location: $e',
      );
    }
  }

  // Helper methods for validation
  void _validateProfileData(Map<String, dynamic> data) {
    final errors = <String>[];

    if (data['user_id'] == null || data['user_id'].toString().isEmpty) {
      errors.add('User ID is required');
    }

    if (data['display_name'] == null ||
        data['display_name'].toString().isEmpty) {
      errors.add('Display name is required');
    }

    // Note: email and phone_number are in auth.users, not profiles table
    // Don't validate them here as they shouldn't be in profile updates

    if (errors.isNotEmpty) {
      throw ValidationException(
        message: 'Profile validation failed',
        errors: errors,
      );
    }
  }

  void _validateProfileUpdates(Map<String, dynamic> updates) {
    final errors = <String>[];

    // Note: email and phone_number are in auth.users, not profiles table
    // Remove them from updates if present
    updates.remove('email');
    updates.remove('phone_number');

    if (updates.containsKey('birth_year')) {
      final birthYear = updates['birth_year'];
      if (birthYear != null &&
          (birthYear < 1900 || birthYear > DateTime.now().year)) {
        errors.add('Invalid birth year');
      }
    }

    if (errors.isNotEmpty) {
      throw ValidationException(
        message: 'Profile update validation failed',
        errors: errors,
      );
    }
  }

  Future<void> _validateImageFile(File file) async {
    final fileSize = await file.length();
    const maxSizeBytes = 5 * 1024 * 1024; // 5MB

    if (fileSize > maxSizeBytes) {
      throw const ValidationException(
        message: 'Image file too large',
        errors: ['File size exceeds 5MB limit'],
      );
    }

    final fileName = file.path.toLowerCase();
    if (!fileName.endsWith('.jpg') &&
        !fileName.endsWith('.jpeg') &&
        !fileName.endsWith('.png') &&
        !fileName.endsWith('.webp')) {
      throw const ValidationException(
        message: 'Invalid image format',
        errors: ['Only JPG, JPEG, PNG, and WebP images are supported'],
      );
    }
  }

  @override
  Future<void> blockProfile(String userId, String blockedUserId) async {
    try {
      await _client.from(_blockedUsersTable).insert({
        'user_id': userId,
        'blocked_user_id': blockedUserId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ConflictException(message: 'User is already blocked');
      }
      throw ServerException(
        message: 'Database error: ${e.message}',
        details: e,
      );
    } catch (e) {
      throw NetworkException(message: 'Failed to block profile: $e');
    }
  }

  @override
  Future<void> unblockProfile(String userId, String blockedUserId) async {
    try {
      final response = await _client
          .from(_blockedUsersTable)
          .delete()
          .eq('user_id', userId)
          .eq('blocked_user_id', blockedUserId)
          .select();

      if (response.isEmpty) {
        throw const DataNotFoundException(message: 'User is not blocked');
      }
    } catch (e) {
      if (e is ProfileRemoteDataSourceException) rethrow;
      throw NetworkException(message: 'Failed to unblock profile: $e');
    }
  }

  @override
  Future<List<String>> getBlockedProfiles(String userId) async {
    try {
      final response = await _client
          .from(_blockedUsersTable)
          .select('blocked_user_id')
          .eq('user_id', userId);

      return response
          .map<String>((row) => row['blocked_user_id'] as String)
          .toList();
    } catch (e) {
      throw NetworkException(message: 'Failed to get blocked profiles: $e');
    }
  }

  @override
  Future<bool> isBlockedBy(String userId, String otherUserId) async {
    try {
      final response = await _client
          .from(_blockedUsersTable)
          .select('id')
          .eq('user_id', otherUserId)
          .eq('blocked_user_id', userId)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      throw NetworkException(message: 'Failed to check block status: $e');
    }
  }

  @override
  Future<void> reportProfile(
    String reporterId,
    String reportedUserId, {
    required String reason,
    String? description,
    List<String>? evidence,
  }) async {
    try {
      await _client.from(_reportsTable).insert({
        'reporter_id': reporterId,
        'reported_user_id': reportedUserId,
        'reason': reason,
        'description': description,
        'evidence': evidence,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw NetworkException(message: 'Failed to report profile: $e');
    }
  }

  @override
  Future<UserProfile> updateVisibility(
    String userId,
    Map<String, bool> visibilitySettings,
  ) async {
    return await updateProfile(userId, {
      'visibility_settings': visibilitySettings,
    });
  }

  @override
  Future<bool> isVisibleTo(String profileUserId, String viewerUserId) async {
    try {
      // Check if viewer is blocked
      final isBlocked = await isBlockedBy(viewerUserId, profileUserId);
      if (isBlocked) return false;

      // Get profile privacy settings
      final profile = await getProfile(profileUserId, includeSports: false);
      final privacySettings = profile.privacySettings;

      // Default to public if no settings
      return privacySettings.canViewProfile(viewerUserId);
    } catch (e) {
      throw NetworkException(message: 'Failed to check visibility: $e');
    }
  }

  @override
  Future<Map<String, bool>> getViewPermissions(
    String profileUserId,
    String viewerUserId,
  ) async {
    try {
      final profile = await getProfile(profileUserId, includeSports: false);
      final privacySettings = profile.privacySettings;

      // Check if viewer is blocked
      final isBlocked = await isBlockedBy(viewerUserId, profileUserId);

      if (isBlocked) {
        return {
          'can_view_profile': false,
          'can_view_sports': false,
          'can_view_statistics': false,
          'can_view_contact': false,
        };
      }

      return {
        'can_view_profile': privacySettings.canViewProfile(viewerUserId),
        'can_view_sports': privacySettings.showSportsProfiles,
        'can_view_statistics': privacySettings.showStats,
        'can_view_contact':
            privacySettings.showPhone || privacySettings.showEmail,
      };
    } catch (e) {
      throw NetworkException(message: 'Failed to get view permissions: $e');
    }
  }

  @override
  Future<Map<String, UserProfile>> batchGetProfiles(
    List<String> userIds, {
    bool includeSports = true,
  }) async {
    try {
      final response = await _client
          .from(_usersTable)
          .select('*')
          .inFilter('user_id', userIds);

      final profiles = <String, UserProfile>{};
      for (final json in response) {
        final profileJson = Map<String, dynamic>.from(json);

        // Enrich with sport_profiles if requested
        if (includeSports) {
          await _enrichWithSportProfiles(
            profileJson,
            profileJson['id'] as String,
          );
        }

        final profile = UserProfile.fromJson(profileJson);
        profiles[profile.id] = profile;
      }

      return profiles;
    } catch (e) {
      throw NetworkException(message: 'Batch get profiles failed: $e');
    }
  }

  @override
  Future<Map<String, UserProfile>> batchUpdateProfiles(
    Map<String, Map<String, dynamic>> updates,
  ) async {
    try {
      final results = <String, UserProfile>{};

      for (final entry in updates.entries) {
        final userId = entry.key;
        final updateData = entry.value;

        final updated = await updateProfile(userId, updateData);
        results[userId] = updated;
      }

      return results;
    } catch (e) {
      throw NetworkException(message: 'Batch update profiles failed: $e');
    }
  }

  @override
  Future<void> preloadProfiles(List<String> userIds) async {
    // Implementation would cache profiles for better performance
    await batchGetProfiles(userIds);
  }

  @override
  Future<void> invalidateCache(String userId) async {
    // Implementation would clear cached data
    // This is a placeholder for cache invalidation logic
  }

  @override
  Future<void> warmUpCache(String userId) async {
    // Implementation would preload commonly accessed data
    await getProfile(userId, includeSports: true);
    await getProfileStatistics(userId);
  }

  @override
  Future<void> trackProfileView(String viewerId, String profileUserId) async {
    try {
      await _client.from(_profileViewsTable).insert({
        'viewer_id': viewerId,
        'profile_user_id': profileUserId,
        'viewed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Don't throw errors for analytics tracking
      // ...existing code...
    }
  }

  @override
  Future<void> trackProfileInteraction(
    String userId,
    String interactionType,
    Map<String, dynamic> data,
  ) async {
    try {
      await _client.rpc(
        'track_profile_interaction',
        params: {
          'user_id_param': userId,
          'interaction_type_param': interactionType,
          'data_param': data,
        },
      );
    } catch (e) {
      // ...existing code...
    }
  }

  @override
  Future<Map<String, dynamic>> getEngagementMetrics(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _client.rpc(
        'get_engagement_metrics',
        params: {
          'user_id_param': userId,
          'start_date_param': startDate?.toIso8601String(),
          'end_date_param': endDate?.toIso8601String(),
        },
      );
    } catch (e) {
      throw NetworkException(message: 'Failed to get engagement metrics: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      // Test database connectivity
      await _client.from(_usersTable).select('count').limit(1);

      return {
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
        'database_accessible': true,
        'storage_accessible': true,
      };
    } catch (e) {
      return {
        'status': 'unhealthy',
        'timestamp': DateTime.now().toIso8601String(),
        'database_accessible': false,
        'error': e.toString(),
      };
    }
  }

  @override
  Future<bool> isConnected() async {
    try {
      await _client.from(_usersTable).select('count').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getMetrics() async {
    try {
      return await _client.rpc('get_data_source_metrics');
    } catch (e) {
      return {
        'error': 'Failed to get metrics: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
