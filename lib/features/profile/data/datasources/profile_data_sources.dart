import 'dart:io';

import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/data/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Progress callback for file upload operations
typedef UploadProgressCallback = void Function(double progress);

/// Abstract interface for remote profile data operations
/// Typically implemented with Supabase, Firebase, or REST API
abstract class ProfileRemoteDataSource {
  /// Fetches user profile from remote server
  Future<UserProfile> getProfile(String userId);

  /// Creates new user profile on remote server
  Future<UserProfile> createProfile(UserProfile profile);

  /// Updates user profile on remote server
  Future<UserProfile> updateProfile(UserProfile profile);

  /// Deletes user profile from remote server
  Future<void> deleteProfile(String userId);

  /// Uploads avatar image to remote storage
  Future<String> uploadAvatar(
    String userId,
    File file, {
    UploadProgressCallback? onProgress,
  });

  /// Deletes avatar image from remote storage
  Future<void> deleteAvatar(String userId);

  /// Fetches sports profiles for user
  Future<List<SportProfileModel>> getSportsProfiles(String userId);

  /// Updates or creates sports profile
  Future<SportProfileModel> updateSportProfile(SportProfileModel profile);

  /// Deletes sports profile
  Future<void> deleteSportProfile(String sportProfileId);

  /// Fetches aggregated profile statistics
  Future<ProfileStatisticsModel> getProfileStatistics(String userId);

  /// Updates profile statistics
  Future<ProfileStatisticsModel> updateProfileStatistics(
    String userId,
    ProfileStatisticsModel statistics,
  );

  /// Searches profiles with filters
  Future<List<UserProfile>> searchProfiles({
    String? query,
    List<String>? sportIds,
    String? location,
    double? maxDistance,
    String? skillLevel,
    int limit = 20,
    int offset = 0,
  });

  /// Gets recommended profiles for user
  Future<List<UserProfile>> getRecommendedProfiles(
    String userId, {
    int limit = 10,
  });

  /// Checks if profile exists
  Future<bool> profileExists(String userId);

  /// Verifies user profile
  Future<UserProfile> verifyProfile(String userId);

  /// Reports user profile
  Future<void> reportProfile(
    String reportedUserId,
    String reporterUserId,
    String reason,
    String? details,
  );

  /// Blocks user
  Future<void> blockUser(String blockerUserId, String blockedUserId);

  /// Unblocks user
  Future<void> unblockUser(String blockerUserId, String blockedUserId);

  /// Gets blocked users list
  Future<List<String>> getBlockedUsers(String userId);

  /// Updates last active timestamp
  Future<void> updateLastActive(String userId);

  /// Gets profile viewers
  Future<List<UserProfile>> getProfileViewers(String userId, {int limit = 50});

  /// Records profile view
  Future<void> recordProfileView(String viewedUserId, String viewerUserId);

  /// Bulk updates profile fields
  Future<UserProfile> bulkUpdateProfile(
    String userId,
    Map<String, dynamic> updates,
  );

  /// Imports profile data from external source
  Future<UserProfile> importProfileData(
    String userId,
    Map<String, dynamic> externalData,
    String source,
  );

  /// Exports profile data
  Future<Map<String, dynamic>> exportProfileData(String userId);
}

/// Abstract interface for local profile data caching
/// Typically implemented with Hive, SQLite, or SharedPreferences
abstract class ProfileLocalDataSource {
  /// Gets cached profile data
  Future<UserProfile?> getCachedProfile(String userId);

  /// Caches profile data locally
  Future<void> cacheProfile(UserProfile profile);

  /// Removes profile from cache
  Future<void> removeCachedProfile(String userId);

  /// Gets cached sports profiles
  Future<List<SportProfileModel>?> getCachedSportsProfiles(String userId);

  /// Caches sports profiles locally
  Future<void> cacheSportsProfiles(
    String userId,
    List<SportProfileModel> profiles,
  );

  /// Gets cached statistics
  Future<ProfileStatisticsModel?> getCachedStatistics(String userId);

  /// Caches statistics locally
  Future<void> cacheStatistics(
    String userId,
    ProfileStatisticsModel statistics,
  );

  /// Checks if cache is valid (not expired)
  Future<bool> isCacheValid(String userId);

  /// Gets cache timestamp
  Future<DateTime?> getCacheTimestamp(String userId);

  /// Clears all cached profile data
  Future<void> clearCache();

  /// Clears cache for specific user
  Future<void> clearUserCache(String userId);

  /// Gets cache size in bytes
  Future<int> getCacheSize();

  /// Optimizes cache by removing old entries
  Future<void> optimizeCache();
}

/// Simple in-memory implementation for development/testing.
///
/// Singleton (matches [UserService]/[ProfileCacheService]/[LocationService])
/// so `AuthService.signOut()` can reach the same instance the Riverpod
/// provider hands out and clear it on logout — this cache is keyed by
/// userId but held in-memory for the life of the app process, so without an
/// explicit clear it survives an in-app account switch (logout, then a
/// different login, no app restart) and leaks the previous account's
/// profile/sports/stats data (T-004).
class ProfileLocalDataSourceImpl implements ProfileLocalDataSource {
  static final ProfileLocalDataSourceImpl _instance =
      ProfileLocalDataSourceImpl._internal();
  factory ProfileLocalDataSourceImpl() => _instance;
  ProfileLocalDataSourceImpl._internal();

  final Map<String, UserProfile> _profileCache = {};
  final Map<String, List<SportProfileModel>> _sportsCache = {};
  final Map<String, ProfileStatisticsModel> _statsCache = {};
  final Map<String, DateTime> _timestamps = {};

  /// Profiles are also kept on disk (KAN-607) in the per-account
  /// [OfflineCache], so a profile seen online opens after a restart with no
  /// network. Keys are the profile's `userId`, so the signed-in user's own and
  /// every other user viewed earlier are cached the same way. The disk copy
  /// holds the profile row only (what the server returned to this account):
  /// no email, phone, tokens or secrets.
  OfflineCache _disk = OfflineCache.instance;
  String? Function() _accountId = _signedInAccountId;

  /// Tests: a fake disk cache and a fixed account.
  void useDiskForTest(OfflineCache disk, String? Function() accountId) {
    _disk = disk;
    _accountId = accountId;
  }

  /// Tests: a restart, in memory only.
  void clearMemoryForTest() {
    _profileCache.clear();
    _sportsCache.clear();
    _statsCache.clear();
    _timestamps.clear();
  }

  static String? _signedInAccountId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static String _diskKey(String userId) => 'profile.$userId';

  @override
  Future<UserProfile?> getCachedProfile(String userId) async {
    final memory = _profileCache[userId];
    if (memory != null) return memory;
    final account = _accountId();
    if (account == null) return null;
    final hit = await _disk.read(account, _diskKey(userId));
    if (hit == null) return null;
    try {
      final profile = UserProfile.fromJson(
        Map<String, dynamic>.from(hit.payload as Map),
      );
      _profileCache[userId] = profile;
      _timestamps[userId] = hit.fetchedAt;
      return profile;
    } catch (_) {
      return null; // a shape that no longer parses: treat as no cache
    }
  }

  @override
  Future<void> cacheProfile(UserProfile profile) async {
    // Use userId (auth UUID) as cache key to match getCachedProfile(userId) lookups
    _profileCache[profile.userId] = profile;
    final now = DateTime.now();
    _timestamps[profile.userId] = now;
    final account = _accountId();
    if (account == null) return;
    await _disk.write(
      account,
      _diskKey(profile.userId),
      profile.toJson(),
      fetchedAt: now,
    );
  }

  @override
  Future<void> removeCachedProfile(String userId) async {
    _profileCache.remove(userId);
    _sportsCache.remove(userId);
    _statsCache.remove(userId);
    _timestamps.remove(userId);
    await _removeDisk(userId);
  }

  Future<void> _removeDisk(String userId) async {
    final account = _accountId();
    if (account != null) await _disk.remove(account, _diskKey(userId));
  }

  @override
  Future<List<SportProfileModel>?> getCachedSportsProfiles(
    String userId,
  ) async => _sportsCache[userId];

  @override
  Future<void> cacheSportsProfiles(
    String userId,
    List<SportProfileModel> profiles,
  ) async {
    _sportsCache[userId] = profiles;
    _timestamps[userId] = DateTime.now();
  }

  @override
  Future<ProfileStatisticsModel?> getCachedStatistics(String userId) async =>
      _statsCache[userId];

  @override
  Future<void> cacheStatistics(
    String userId,
    ProfileStatisticsModel statistics,
  ) async {
    _statsCache[userId] = statistics;
    _timestamps[userId] = DateTime.now();
  }

  @override
  Future<bool> isCacheValid(String userId) async {
    await getCachedProfile(userId); // loads the disk timestamp into memory
    final ts = _timestamps[userId];
    if (ts == null) return false;
    return DateTime.now().difference(ts) < const Duration(hours: 12);
  }

  @override
  Future<DateTime?> getCacheTimestamp(String userId) async =>
      _timestamps[userId];

  @override
  Future<void> clearCache() async {
    _profileCache.clear();
    _sportsCache.clear();
    _statsCache.clear();
    _timestamps.clear();
    // Sign-out path: every account's disk entries go (CacheAccountNotifier
    // also wipes them; this covers a sign-out that bypasses it).
    await OfflineCache.wipeAll();
  }

  @override
  Future<void> clearUserCache(String userId) async {
    _profileCache.remove(userId);
    _sportsCache.remove(userId);
    _statsCache.remove(userId);
    _timestamps.remove(userId);
    await _removeDisk(userId);
  }

  @override
  Future<int> getCacheSize() async =>
      _profileCache.length + _sportsCache.length + _statsCache.length;

  @override
  Future<void> optimizeCache() async {
    // No-op for in-memory
  }
}
