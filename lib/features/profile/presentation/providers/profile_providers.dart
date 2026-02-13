import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/logger.dart';
import 'package:dabbler/data/models/sport_profiles/sport_profile.dart'
    as advanced_profile;
import 'package:dabbler/data/models/sport_profiles/sport_profile_badge.dart'
    as advanced_badge;
import 'package:dabbler/data/models/sport_profiles/sport_profile_tier.dart'
    as advanced_tier;
import 'package:dabbler/services/sport_profile_service.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../data/datasources/supabase_profile_datasource.dart';
import '../../data/datasources/profile_data_sources.dart'
    show ProfileLocalDataSource, ProfileLocalDataSourceImpl;
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/social/block_providers.dart';

// Domain layer imports
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/profile/user_settings.dart';
import 'package:dabbler/data/models/profile/user_preferences.dart';
import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';

// Controller imports
import '../controllers/profile_controller.dart';
import '../controllers/profile_edit_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/preferences_controller.dart';
import '../controllers/privacy_controller.dart';
import '../controllers/sports_profile_controller.dart';
import '../controllers/organiser_profile_controller.dart';

// Settings repository
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/usecases/manage_privacy_usecase.dart';

// =============================================================================
// CONTROLLER PROVIDERS (Simplified)
// =============================================================================

// Infrastructure: Supabase client
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final sportProfileServiceProvider = Provider<SportProfileService>((ref) {
  final client = ref.watch(supabaseProvider);
  return SportProfileService(supabase: client);
});

// Data sources
final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  final client = ref.watch(supabaseProvider);
  return SupabaseProfileDataSource(client);
});

final profileLocalDataSourceProvider = Provider<ProfileLocalDataSource>((ref) {
  return ProfileLocalDataSourceImpl();
});

// Repository
final profileRepositoryProvider = Provider<ProfileRepositoryImpl>((ref) {
  return ProfileRepositoryImpl(
    remoteDataSource: ref.watch(profileRemoteDataSourceProvider),
    localDataSource: ref.watch(profileLocalDataSourceProvider),
  );
});

/// Method to clear profile cache for a specific user
/// Call this when profile data is updated externally (e.g., profile edit screen)
Future<void> clearProfileCache(WidgetRef ref, String userId) async {
  final localDataSource = ref.read(profileLocalDataSourceProvider);
  await localDataSource.clearUserCache(userId);
}

// Use cases
final getProfileUseCaseProvider = Provider<GetProfileUseCase>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return GetProfileUseCase(repo);
});

/// Main profile controller provider
final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
      return ProfileController(
        getProfileUseCase: ref.watch(getProfileUseCaseProvider),
      );
    });

/// Sports profile controller provider
final sportsProfileControllerProvider =
    StateNotifierProvider<SportsProfileController, SportsProfileState>((ref) {
      return SportsProfileController();
    });

/// Organiser profile controller provider
final organiserProfileControllerProvider =
    StateNotifierProvider<OrganiserProfileController, OrganiserProfileState>((
      ref,
    ) {
      return OrganiserProfileController();
    });

class SportProfileHeaderData {
  const SportProfileHeaderData({
    required this.profile,
    this.tier,
    this.badges = const <advanced_badge.SportProfileBadge>[],
  });

  final advanced_profile.SportProfile profile;
  final advanced_tier.SportProfileTier? tier;
  final List<advanced_badge.SportProfileBadge> badges;
}

final sportProfileHeaderProvider = FutureProvider.autoDispose
    .family<SportProfileHeaderData?, String>((ref, userId) async {
      if (userId.isEmpty) {
        return null;
      }

      final service = ref.watch(sportProfileServiceProvider);

      try {
        final profiles = await service.getSportProfilesForUser(userId);
        if (profiles.isEmpty) {
          return null;
        }

        final selectedProfile = _selectPrimarySportProfile(profiles);

        final badges = await service.getPlayerBadges(
          selectedProfile.profileId,
          selectedProfile.sportKey,
        );
        final tier = await service.getTierById(selectedProfile.tierId);

        return SportProfileHeaderData(
          profile: selectedProfile,
          tier: tier,
          badges: badges,
        );
      } on SportProfileServiceException catch (error) {
        Logger.warning(
          'Failed to load sport profile header for userId=$userId',
          error,
        );
        return null;
      } catch (error) {
        Logger.error(
          'Unexpected error loading sport profile header for userId=$userId',
          error,
        );
        return null;
      }
    });

/// Profile edit controller provider
final profileEditControllerProvider =
    StateNotifierProvider<ProfileEditController, ProfileEditState>((ref) {
      return ProfileEditController();
    });

/// Settings controller provider
final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
      return SettingsController();
    });

/// Preferences controller provider
final preferencesControllerProvider =
    StateNotifierProvider<PreferencesController, PreferencesState>((ref) {
      return PreferencesController();
    });

/// Settings repository provider (privacy persistence)
final settingsRepositoryProvider = Provider<SettingsRepositoryImpl>((ref) {
  final client = ref.watch(supabaseProvider);
  return SettingsRepositoryImpl(client);
});

/// Privacy use case provider
final managePrivacyUseCaseProvider = Provider<ManagePrivacyUseCase>((ref) {
  return ManagePrivacyUseCase(ref.watch(settingsRepositoryProvider));
});

/// Privacy controller provider
final privacyControllerProvider =
    StateNotifierProvider<PrivacyController, PrivacyState>((ref) {
      return PrivacyController(
        settingsRepository: ref.watch(settingsRepositoryProvider),
        managePrivacyUseCase: ref.watch(managePrivacyUseCaseProvider),
      );
    });

// =============================================================================
// COMPUTED STATE PROVIDERS
// =============================================================================

/// Current user profile provider
final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  final profileState = ref.watch(profileControllerProvider);
  return profileState.profile;
});

/// Current user settings provider
final currentUserSettingsProvider = Provider<UserSettings?>((ref) {
  final settingsState = ref.watch(settingsControllerProvider);
  return settingsState.settings;
});

/// Current user preferences provider
final currentUserPreferencesProvider = Provider<UserPreferences?>((ref) {
  final preferencesState = ref.watch(preferencesControllerProvider);
  return preferencesState.preferences;
});

/// Current privacy settings provider
final currentPrivacySettingsProvider = Provider<PrivacySettings?>((ref) {
  final privacyState = ref.watch(privacyControllerProvider);
  return privacyState.settings;
});

/// All sports profiles provider
final allSportsProfilesProvider = Provider<List<SportProfile>>((ref) {
  final sportsState = ref.watch(sportsProfileControllerProvider);
  return sportsState.profiles;
});

/// Active sports profiles provider
final activeSportsProfilesProvider = Provider<List<SportProfile>>((ref) {
  final allProfiles = ref.watch(allSportsProfilesProvider);
  return allProfiles.where((profile) => profile.gamesPlayed > 0).toList();
});

/// Primary sport profile provider
final primarySportProfileProvider = Provider<SportProfile?>((ref) {
  final allProfiles = ref.watch(allSportsProfilesProvider);
  try {
    return allProfiles.firstWhere((profile) => profile.isPrimarySport);
  } catch (e) {
    return null;
  }
});

/// Profile completion percentage provider
final profileCompletionProvider = Provider<double>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  final settings = ref.watch(currentUserSettingsProvider);
  final preferences = ref.watch(currentUserPreferencesProvider);
  final sportsProfiles = ref.watch(allSportsProfilesProvider);

  if (profile == null) return 0.0;

  double completion = 0.0;

  // Basic profile info (40%)
  if (profile.username?.isNotEmpty == true) completion += 8.0;
  if (profile.displayName.isNotEmpty == true) completion += 8.0;
  if (profile.email?.isNotEmpty ?? false) completion += 8.0;
  if (profile.phoneNumber?.isNotEmpty == true) completion += 8.0;
  if (profile.city?.isNotEmpty == true) completion += 8.0;

  // Settings (20%)
  if (settings != null) completion += 20.0;

  // Preferences (20%)
  if (preferences != null) {
    completion += 10.0;
    if (preferences.preferredGameTypes.isNotEmpty) completion += 10.0;
  }

  // Sports profiles (20%)
  if (sportsProfiles.isNotEmpty) {
    completion += 10.0;
    if (sportsProfiles.any((p) => p.isPrimarySport)) completion += 10.0;
  }

  return completion.clamp(0.0, 100.0);
});

/// Profile loading state provider
final isProfileLoadingProvider = Provider<bool>((ref) {
  final profileState = ref.watch(profileControllerProvider);
  final settingsState = ref.watch(settingsControllerProvider);
  final preferencesState = ref.watch(preferencesControllerProvider);
  final privacyState = ref.watch(privacyControllerProvider);
  final sportsState = ref.watch(sportsProfileControllerProvider);

  return profileState.isLoading ||
      settingsState.isLoading ||
      preferencesState.isLoading ||
      privacyState.isLoading ||
      sportsState.isLoading;
});

/// Profile has unsaved changes provider
final hasUnsavedChangesProvider = Provider<bool>((ref) {
  final profileState = ref.watch(profileControllerProvider);
  final settingsState = ref.watch(settingsControllerProvider);
  final preferencesState = ref.watch(preferencesControllerProvider);
  final privacyState = ref.watch(privacyControllerProvider);
  final sportsState = ref.watch(sportsProfileControllerProvider);

  return profileState.hasUnsavedChanges ||
      settingsState.hasUnsavedChanges ||
      preferencesState.hasUnsavedChanges ||
      privacyState.hasUnsavedChanges ||
      sportsState.hasUnsavedChanges;
});

// =============================================================================
// FAMILY PROVIDERS
// =============================================================================

/// Get sports profile by ID
final sportsProfileByIdProvider = Provider.family<SportProfile?, String>((
  ref,
  sportId,
) {
  final sportsController = ref.watch(sportsProfileControllerProvider.notifier);
  return sportsController.getProfileBySport(sportId);
});

// =============================================================================
// UTILITY PROVIDERS
// =============================================================================

/// Available profiles provider - lists all profiles (player/organiser) for current user
final availableProfilesProvider = FutureProvider.autoDispose<List<UserProfile>>((
  ref,
) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null || userId.isEmpty) {
    return [];
  }

  try {
    // Fetch all profiles directly from Supabase
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('profiles')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    if (response.isEmpty) {
      return [];
    }

    final profiles = <UserProfile>[];
    for (final row in response) {
      final result = Map<String, dynamic>.from(row);

      // Enrich with auth data (email, phone)
      try {
        final authUser = client.auth.currentUser;
        if (authUser != null) {
          result['email'] = authUser.email;
          result['phone_number'] = authUser.phone;
        }
      } catch (_) {
        // Ignore auth data enrichment errors
      }

      // Enrich with sport profiles
      try {
        final profileId = result['id'] as String;
        final personaType = result['persona_type'] as String?;

        if (personaType == 'player') {
          final sportProfilesResponse = await client
              .from('sport_profiles')
              .select(
                'sport, skill_level, matches_played, primary_position, rating_total, rating_count',
              )
              .eq('profile_id', profileId);

          final sportProfiles = (sportProfilesResponse as List)
              .map((sp) => SportProfile.fromJson(Map<String, dynamic>.from(sp)))
              .toList();
          result['sports_profiles'] = sportProfiles
              .map((sp) => sp.toJson())
              .toList();
        } else if (personaType == 'organiser' || personaType == 'hoster') {
          final organiserResponse = await client
              .from('organiser')
              .select('*')
              .eq('profile_id', profileId);

          // For now, just mark that organiser records exist
          result['organiser_records'] = organiserResponse;
        }
      } catch (_) {
        // Ignore sport profile enrichment errors
      }

      profiles.add(UserProfile.fromJson(result));
    }

    return profiles;
  } catch (e) {
    Logger.error('Failed to load available profiles', e);
    return [];
  }
});

/// Active profile type provider - tracks which profile type is currently selected
/// This is a simple state holder. It must NOT watch other providers,
/// otherwise manual state changes get reset when dependencies rebuild.
final activeProfileTypeProvider = StateProvider<String?>((ref) => null);

/// SharedPreferences key for the last-used profile type.
const _kLastActiveProfileType = 'last_active_profile_type';

/// Persists the active profile type to SharedPreferences so it survives
/// logout / session refresh / app restart.
Future<void> persistActiveProfileType(String? profileType) async {
  final prefs = await SharedPreferences.getInstance();
  if (profileType != null && profileType.isNotEmpty) {
    await prefs.setString(_kLastActiveProfileType, profileType);
  } else {
    await prefs.remove(_kLastActiveProfileType);
  }
}

/// Reads the last-used profile type from SharedPreferences.
Future<String?> loadPersistedProfileType() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kLastActiveProfileType);
}

/// Initialize all profile data provider
final initializeProfileDataProvider = FutureProvider<bool>((ref) async {
  final profileController = ref.read(profileControllerProvider.notifier);
  final settingsController = ref.read(settingsControllerProvider.notifier);
  final preferencesController = ref.read(
    preferencesControllerProvider.notifier,
  );
  final privacyController = ref.read(privacyControllerProvider.notifier);
  final sportsController = ref.read(sportsProfileControllerProvider.notifier);
  final organiserController = ref.read(
    organiserProfileControllerProvider.notifier,
  );

  // Resolve current authenticated user id
  final userId = ref.read(currentUserIdProvider);

  try {
    if (userId != null && userId.isNotEmpty) {
      // Restore the last-used persona from SharedPreferences so the user
      // returns to the same profile after logout / session refresh.
      final persistedType = await loadPersistedProfileType();

      // Try the persisted type first, then fall back to player → organiser.
      final typesToTry = <String>[
        if (persistedType != null) persistedType,
        'player',
        'organiser',
      ];

      // Deduplicate while preserving order
      final seen = <String>{};
      final uniqueTypes = typesToTry.where((t) => seen.add(t)).toList();

      for (final type in uniqueTypes) {
        await profileController.loadProfile(userId, profileType: type);
        final ps = ref.read(profileControllerProvider);
        if (ps.profile != null) break;
      }

      var profileState = ref.read(profileControllerProvider);

      final profile = profileState.profile;
      if (profile != null) {
        final effectiveType = profile.personaType ?? profile.profileType;

        // Seed the active persona so myProfileIdProvider returns the right
        // profile from the very first app launch.
        ref.read(activeProfileTypeProvider.notifier).state = effectiveType;
        // Persist so the next session starts on the same persona.
        unawaited(persistActiveProfileType(effectiveType));

        if (effectiveType == 'organiser') {
          await organiserController.loadOrganiserProfiles(userId);
        } else {
          await sportsController.loadSportsProfiles(userId);
        }
      }

      await Future.wait([
        settingsController.loadSettings(userId),
        preferencesController.loadPreferences(userId),
        privacyController.loadPrivacySettings(userId),
      ]);
    } else {
      return false;
    }
    return true;
  } catch (e) {
    Logger.error('Failed to initialize profile data', e);
    return false;
  }
});

/// Tracks whether profile bootstrap has completed for the current session
final profileBootstrapCompletedProvider = StateProvider<bool>((ref) => false);

/// Save all profile changes provider
final saveAllProfileChangesProvider = FutureProvider<bool>((ref) async {
  final hasChanges = ref.read(hasUnsavedChangesProvider);
  if (!hasChanges) return true;

  final settingsController = ref.read(settingsControllerProvider.notifier);
  final preferencesController = ref.read(
    preferencesControllerProvider.notifier,
  );
  final privacyController = ref.read(privacyControllerProvider.notifier);

  // Privacy controller now needs the userId.
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return false;

  final results = await Future.wait([
    settingsController.saveAllChanges(),
    preferencesController.saveAllChanges(),
    privacyController.saveAllChanges(userId),
  ]);

  return results.every((success) => success);
});

// =============================================================================
// CURRENT USER AND UTILITY PROVIDERS
// =============================================================================

// Current user provider that returns UserProfile for profile features
final currentUserProvider = Provider<UserProfile?>((ref) {
  // Use AuthService singleton to read the authenticated user and convert to minimal UserProfile
  final authUser = AuthService().getCurrentUser();
  if (authUser == null) return null;
  final now = DateTime.now();
  final metadata = authUser.userMetadata;
  final displayName =
      (metadata?['display_name'] as String?) ??
      (metadata?['full_name'] as String?) ??
      (authUser.email ?? '');
  final avatarUrl = metadata?['avatar_url'] as String?;

  // Safely convert timestamps that may be DateTime or String or other
  DateTime asDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? now;
    return now;
  }

  return UserProfile(
    id: authUser.id,
    userId: authUser.id,
    email: authUser.email ?? '',
    displayName: displayName,
    avatarUrl: avatarUrl,
    createdAt: asDateTime(authUser.createdAt),
    updatedAt: asDateTime(authUser.updatedAt),
  );
});

// Profile loading provider
final profileLoadingProvider = Provider<bool>((ref) {
  final profileState = ref.watch(profileControllerProvider);
  final sportsState = ref.watch(sportsProfileControllerProvider);
  return profileState.isLoading || sportsState.isLoading;
});

// Profile error provider
final profileErrorProvider = Provider<String?>((ref) {
  final profileState = ref.watch(profileControllerProvider);
  final sportsState = ref.watch(sportsProfileControllerProvider);
  return profileState.errorMessage ?? sportsState.errorMessage;
});

advanced_profile.SportProfile _selectPrimarySportProfile(
  List<advanced_profile.SportProfile> profiles,
) {
  if (profiles.length == 1) {
    return profiles.first;
  }

  final flagged = profiles.where(_isPrimaryProfile).toList();
  if (flagged.isNotEmpty) {
    return flagged.first;
  }

  return profiles.reduce((current, next) {
    if (next.overallLevel > current.overallLevel) {
      return next;
    }
    if (next.overallLevel == current.overallLevel &&
        next.xpTotal > current.xpTotal) {
      return next;
    }
    return current;
  });
}

bool _isPrimaryProfile(advanced_profile.SportProfile profile) {
  final attributes = profile.attributes;
  final dynamic candidate =
      attributes['is_primary'] ??
      attributes['isPrimary'] ??
      attributes['primary'];

  if (candidate is bool) {
    return candidate;
  }
  if (candidate is num) {
    return candidate != 0;
  }
  if (candidate is String) {
    final normalized = candidate.toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'primary';
  }
  return false;
}

// =============================================================================
// PROFILE ID LOOKUP PROVIDERS
// =============================================================================

/// Get the current authenticated user's profile ID for the ACTIVE persona.
/// Watches [activeProfileTypeProvider] so that switching persona (player ↔
/// organiser) automatically returns the matching profile ID.
/// Falls back to the oldest active profile when no persona is selected yet.
final myProfileIdProvider = FutureProvider<String?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;

  final activeType = ref.watch(activeProfileTypeProvider);

  var query = Supabase.instance.client
      .from('profiles')
      .select('id')
      .eq('user_id', userId)
      .eq('is_active', true);

  if (activeType != null) {
    query = query.eq('persona_type', activeType);
  }

  final response = await query.order('created_at', ascending: true).limit(1);
  if ((response as List).isEmpty) return null;
  return response.first['id'] as String?;
});

/// Look up a profile ID from an auth user_id.
/// Uses .limit(1) instead of .maybeSingle() because a user can have
/// multiple active profiles (e.g. player + organiser).
final profileIdByUserIdProvider = FutureProvider.family<String?, String>((
  ref,
  userId,
) async {
  final response = await Supabase.instance.client
      .from('profiles')
      .select('id')
      .eq('user_id', userId)
      .eq('is_active', true)
      .order('created_at', ascending: true)
      .limit(1);
  if ((response as List).isEmpty) return null;
  return response.first['id'] as String?;
});

// =============================================================================
// FOLLOW COUNT PROVIDERS (profile_follows table)
// =============================================================================

/// Following count: number of profiles this profile follows
/// Counts rows where follower_profile_id = profileId
final followingCountProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  profileId,
) async {
  try {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('profile_follows')
        .select('following_profile_id')
        .eq('follower_profile_id', profileId);
    return (response as List).length;
  } catch (e) {
    return 0;
  }
});

/// Followers count: number of profiles following this profile
/// Counts rows where following_profile_id = profileId
final followersCountProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  profileId,
) async {
  try {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('profile_follows')
        .select('follower_profile_id')
        .eq('following_profile_id', profileId);
    return (response as List).length;
  } catch (e) {
    return 0;
  }
});

/// Following list: full profile data for profiles this user follows.
/// Excludes hoster profiles and blocked users (via unified user_blocks).
final followingListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, profileId) async {
      final supabase = Supabase.instance.client;

      // Use cached blocked user IDs (user-level, not profile-level)
      final blockedUserIds = await ref.watch(blockedUserIdsProvider.future);

      final response = await supabase
          .from('profile_follows')
          .select(
            'profiles!fk_following_profile(id, user_id, display_name, username, avatar_url, verified, persona_type, is_active)',
          )
          .eq('follower_profile_id', profileId);

      final List<Map<String, dynamic>> profiles = [];
      for (final row in (response as List)) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        if (profile == null) continue;
        if (profile['is_active'] != true) continue;
        if (profile['persona_type'] == 'hoster') continue;
        final userId = profile['user_id'] as String?;
        if (userId != null && blockedUserIds.contains(userId)) continue;
        profiles.add(profile);
      }
      return profiles;
    });

/// Check if currentProfileId is following targetProfileId.
final isFollowingProvider = FutureProvider.autoDispose
    .family<bool, ({String currentProfileId, String targetProfileId})>((
      ref,
      params,
    ) async {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('profile_follows')
          .select('follower_profile_id')
          .eq('follower_profile_id', params.currentProfileId)
          .eq('following_profile_id', params.targetProfileId)
          .maybeSingle();
      return response != null;
    });

/// Check if targetUserId is blocked (bidirectional) using unified user_blocks.
/// Accepts user IDs (auth.users.id), NOT profile IDs.
final isBlockedProvider = FutureProvider.autoDispose
    .family<bool, ({String currentProfileId, String targetProfileId})>((
      ref,
      params,
    ) async {
      // Resolve profile IDs to user IDs if needed — but first try the
      // cached blockedUserIdsProvider which already uses user-level IDs.
      // The params still use "profileId" names for backwards compat with
      // existing callers, but we look up the user_id from the profile.
      final supabase = Supabase.instance.client;

      // Resolve target profile ID to user_id
      final targetProfile = await supabase
          .from('profiles')
          .select('user_id')
          .eq('id', params.targetProfileId)
          .maybeSingle();
      final targetUserId = targetProfile?['user_id'] as String?;
      if (targetUserId == null) return false;

      final blockedIds = await ref.watch(blockedUserIdsProvider.future);
      return blockedIds.contains(targetUserId);
    });

/// Search profiles by display name or username (for People / discover tab).
/// Excludes hosters, blocked users, and current profile.
final searchProfilesProvider = FutureProvider.autoDispose
    .family<
      List<Map<String, dynamic>>,
      ({String query, String currentProfileId})
    >((ref, params) async {
      if (params.query.length < 2) return [];
      final supabase = Supabase.instance.client;

      // Use cached blocked user IDs (user-level)
      final blockedUserIds = await ref.watch(blockedUserIdsProvider.future);

      final response = await supabase
          .from('profiles')
          .select(
            'id, user_id, display_name, username, avatar_url, verified, persona_type, is_active',
          )
          .or(
            'display_name.ilike.%${params.query}%,username.ilike.%${params.query}%',
          )
          .neq('id', params.currentProfileId)
          .eq('is_active', true)
          .limit(30);

      final List<Map<String, dynamic>> results = [];
      for (final row in (response as List)) {
        final profile = Map<String, dynamic>.from(row);
        if (profile['persona_type'] == 'hoster') continue;
        final userId = profile['user_id'] as String?;
        if (userId != null && blockedUserIds.contains(userId)) continue;
        results.add(profile);
      }
      return results;
    });

/// Followers list: full profile data for profiles following this user.
/// Excludes hoster profiles and blocked users (via unified user_blocks).
final followersListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, profileId) async {
      final supabase = Supabase.instance.client;

      // Use cached blocked user IDs (user-level)
      final blockedUserIds = await ref.watch(blockedUserIdsProvider.future);

      final response = await supabase
          .from('profile_follows')
          .select(
            'profiles!fk_follower_profile(id, user_id, display_name, username, avatar_url, verified, persona_type, is_active)',
          )
          .eq('following_profile_id', profileId);

      final List<Map<String, dynamic>> profiles = [];
      for (final row in (response as List)) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        if (profile == null) continue;
        if (profile['is_active'] != true) continue;
        if (profile['persona_type'] == 'hoster') continue;
        final userId = profile['user_id'] as String?;
        if (userId != null && blockedUserIds.contains(userId)) continue;
        profiles.add(profile);
      }
      return profiles;
    });
