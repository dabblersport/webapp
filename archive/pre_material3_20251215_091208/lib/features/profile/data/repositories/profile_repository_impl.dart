import 'dart:io';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import '../../domain/repositories/profile_repository.dart' as domain;
import '../datasources/profile_data_sources.dart' show ProfileLocalDataSource;
import '../datasources/profile_remote_datasource.dart';
import '../datasources/supabase_profile_datasource.dart';
import 'package:dabbler/data/models/models.dart';

/// Implementation of ProfileRepository with caching and error handling
class ProfileRepositoryImpl implements domain.ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final ProfileLocalDataSource localDataSource;

  // Cache configuration
  static const int _maxCacheSize = 50 * 1024 * 1024; // 50MB

  ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, UserProfile>> getProfile(
    String userId, {
    String? profileType,
  }) async {
    try {
      // Try to get from cache first (cache key should include profile type if specified)
      final cachedProfile = await localDataSource.getCachedProfile(userId);
      final cacheValid = await localDataSource.isCacheValid(userId);

      // If cached profile matches requested type, use it
      if (cachedProfile != null &&
          cacheValid &&
          (profileType == null ||
              cachedProfile.profileType?.toLowerCase() ==
                  profileType.toLowerCase())) {
        return Right(cachedProfile);
      }

      // Fetch from remote if cache miss or expired
      final remoteProfile = await remoteDataSource.getProfile(
        userId,
        profileType: profileType,
      );

      // Cache the result
      await localDataSource.cacheProfile(remoteProfile);

      return Right(remoteProfile);
    } on ServerFailure catch (e) {
      // Try to return stale cache on server error
      final cachedProfile = await localDataSource.getCachedProfile(userId);
      if (cachedProfile != null &&
          (profileType == null ||
              cachedProfile.profileType?.toLowerCase() ==
                  profileType.toLowerCase())) {
        return Right(cachedProfile);
      }
      return Left(
        ServerFailure(message: 'Failed to fetch profile: ${e.message}'),
      );
    } on NetworkFailure catch (e) {
      // Return cached data on network issues
      final cachedProfile = await localDataSource.getCachedProfile(userId);
      if (cachedProfile != null &&
          (profileType == null ||
              cachedProfile.profileType?.toLowerCase() ==
                  profileType.toLowerCase())) {
        return Right(cachedProfile);
      }
      return Left(
        NetworkFailure(message: 'No network connection: ${e.message}'),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to get profile: $e'));
    }
  }

  /// Get all profiles for a user (player and organiser)
  Future<Either<Failure, List<UserProfile>>> getAllProfiles(
    String userId,
  ) async {
    try {
      if (remoteDataSource is SupabaseProfileDataSource) {
        final profiles = await (remoteDataSource as SupabaseProfileDataSource)
            .getAllProfiles(userId);
        return Right(profiles);
      }
      // Fallback: try to get player and organiser separately
      final playerResult = await getProfile(userId, profileType: 'player');
      final organiserResult = await getProfile(
        userId,
        profileType: 'organiser',
      );

      final profiles = <UserProfile>[];
      playerResult.fold((_) => null, (profile) => profiles.add(profile));
      organiserResult.fold((_) => null, (profile) => profiles.add(profile));

      return Right(profiles);
    } catch (e) {
      return Left(DataFailure(message: 'Failed to get all profiles: $e'));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> updateProfile(
    UserProfile profile,
  ) async {
    try {
      // Optimistic update - update cache immediately
      await localDataSource.cacheProfile(profile);

      try {
        // Update remote
        final updatedProfile = await remoteDataSource.updateProfile(
          profile.id,
          profile.toJson(),
        );

        // Update cache with server response
        await localDataSource.cacheProfile(updatedProfile);

        return Right(updatedProfile);
      } catch (e) {
        // Rollback cache on remote failure
        await localDataSource.removeCachedProfile(profile.id);
        rethrow;
      }
    } on ValidationFailure catch (e) {
      return Left(
        ValidationFailure(message: 'Invalid profile data: ${e.message}'),
      );
    } on ConflictFailure catch (e) {
      return Left(ConflictFailure(message: 'Profile conflict: ${e.message}'));
    } on NetworkFailure catch (e) {
      return Left(
        NetworkFailure(message: 'Network error during update: ${e.message}'),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to update profile: $e'));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> createProfile(
    UserProfile profile,
  ) async {
    try {
      final profileModel = profile;
      final createdProfile = await remoteDataSource.createProfile(profileModel);

      // Cache the created profile
      await localDataSource.cacheProfile(createdProfile);

      return Right(createdProfile);
    } on ValidationFailure catch (e) {
      return Left(
        ValidationFailure(message: 'Invalid profile data: ${e.message}'),
      );
    } on ConflictFailure catch (e) {
      return Left(
        ConflictFailure(message: 'Profile already exists: ${e.message}'),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to create profile: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteProfile(String userId) async {
    try {
      await remoteDataSource.deleteProfile(userId);
      await localDataSource.removeCachedProfile(userId);
      return const Right(null);
    } on ForbiddenFailure catch (e) {
      return Left(
        ForbiddenFailure(
          message: 'Not authorized to delete profile: ${e.message}',
        ),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to delete profile: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> uploadAvatar(
    String userId,
    File file, {
    domain.UploadProgressCallback? onProgress,
  }) async {
    try {
      // Validate file
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        // 5MB limit
        return const Left(
          ValidationFailure(message: 'File too large (max 5MB)'),
        );
      }

      final fileName = file.path.split('/').last.toLowerCase();
      if (!fileName.endsWith('.jpg') &&
          !fileName.endsWith('.jpeg') &&
          !fileName.endsWith('.png')) {
        return const Left(
          ValidationFailure(message: 'Invalid file type. Use JPG or PNG.'),
        );
      }

      final avatarUrl = await remoteDataSource.uploadAvatar(
        userId,
        file,
        onProgress: onProgress,
      );

      // Invalidate cached profile to force refresh
      await localDataSource.removeCachedProfile(userId);

      return Right(avatarUrl);
    } on FileUploadFailure catch (e) {
      return Left(FileUploadFailure(message: 'Upload failed: ${e.message}'));
    } on NetworkFailure catch (e) {
      return Left(
        NetworkFailure(message: 'Network error during upload: ${e.message}'),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to upload avatar: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAvatar(String userId) async {
    try {
      await remoteDataSource.deleteAvatar(userId);
      // Invalidate cached profile
      await localDataSource.removeCachedProfile(userId);
      return const Right(null);
    } catch (e) {
      return Left(DataFailure(message: 'Failed to delete avatar: $e'));
    }
  }

  @override
  Future<Either<Failure, List<SportProfile>>> getSportsForUser(
    String userId,
  ) async {
    try {
      // Try cache first
      final cachedSports = await localDataSource.getCachedSportsProfiles(
        userId,
      );
      final cacheValid = await localDataSource.isCacheValid(userId);

      if (cachedSports != null && cacheValid) {
        return Right(cachedSports.map((e) => e.toEntity()).toList());
      }

      // Fetch from remote
      final remoteSports = await remoteDataSource.getSportProfiles(userId);

      // Cache the result
      await localDataSource.cacheSportsProfiles(userId, remoteSports);

      return Right(remoteSports.map((e) => e.toEntity()).toList());
    } catch (e) {
      return Left(DataFailure(message: 'Failed to get sports profiles: $e'));
    }
  }

  @override
  Future<Either<Failure, SportProfile>> updateSportProfile(
    SportProfile sportProfile,
  ) async {
    try {
      // Since SportProfile entity doesn't contain metadata like id, userId, etc.,
      // we need to get the existing sport profile from the database first
      // or create a new one if it doesn't exist

      // For now, we'll need to modify the approach since the current interface
      // doesn't provide enough context. This method should probably take additional
      // parameters or we need to restructure the data flow.

      // For now, return an error indicating the method needs to be updated
      return Left(
        ValidationFailure(
          message:
              'updateSportProfile method needs additional context (userId, sportProfileId). '
              'Please update the interface to include required parameters.',
        ),
      );
    } on ValidationFailure catch (e) {
      return Left(
        ValidationFailure(message: 'Invalid sport profile data: ${e.message}'),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to update sport profile: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSportProfile(
    String sportProfileId,
  ) async {
    try {
      // Remote API requires both userId and sportId. This method lacks userId context.
      return Left(
        ValidationFailure(
          message:
              'deleteSportProfile requires userId and sportId; repository method needs updating.',
        ),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to delete sport profile: $e'));
    }
  }

  @override
  Future<Either<Failure, ProfileStatistics>> getProfileStatistics(
    String userId,
  ) async {
    try {
      // Try cache first for statistics
      final cachedStats = await localDataSource.getCachedStatistics(userId);
      final cacheValid = await localDataSource.isCacheValid(userId);

      if (cachedStats != null && cacheValid) {
        return Right(cachedStats);
      }

      // Fetch from remote
      final remoteStats = await remoteDataSource.getProfileStatistics(userId);

      // Cache the result
      await localDataSource.cacheStatistics(userId, remoteStats);

      return Right(remoteStats);
    } catch (e) {
      return Left(DataFailure(message: 'Failed to get profile statistics: $e'));
    }
  }

  @override
  Future<Either<Failure, ProfileStatistics>> updateProfileStatistics(
    String userId,
    ProfileStatistics statistics,
  ) async {
    try {
      final statsModel = ProfileStatisticsModel.fromEntity(statistics);
      final updatedStats = await remoteDataSource.updateStatistics(
        userId,
        statsModel.toJson(),
      );

      // Update cache
      await localDataSource.cacheStatistics(userId, updatedStats);

      return Right(updatedStats);
    } catch (e) {
      return Left(
        DataFailure(message: 'Failed to update profile statistics: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<UserProfile>>> searchProfiles({
    String? query,
    List<String>? sportIds,
    String? location,
    double? maxDistance,
    String? skillLevel,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final skillLevelNum = skillLevel != null
          ? int.tryParse(skillLevel)
          : null;
      final data = await remoteDataSource.searchProfiles(
        query: query,
        sportTypes: sportIds,
        location: location,
        maxDistance: maxDistance,
        skillLevel: skillLevelNum,
        limit: limit,
        offset: offset,
      );
      final profilesJson = (data['profiles'] as List)
          .cast<Map<String, dynamic>>();
      final profiles = profilesJson
          .map((j) => UserProfile.fromJson(j))
          .toList();
      return Right(profiles);
    } catch (e) {
      return Left(DataFailure(message: 'Failed to search profiles: $e'));
    }
  }

  @override
  Future<Either<Failure, List<UserProfile>>> getRecommendedProfiles(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final recs = await remoteDataSource.getRecommendations(
        userId,
        limit: limit,
      );
      final profiles = recs
          .map(
            (m) => UserProfile.fromJson((m['profile'] as Map<String, dynamic>)),
          )
          .toList();
      return Right(profiles);
    } catch (e) {
      return Left(
        DataFailure(message: 'Failed to get recommended profiles: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> profileExists(String userId) async {
    try {
      final exists = await remoteDataSource.profileExists(userId);
      return Right(exists);
    } catch (e) {
      return Left(
        DataFailure(message: 'Failed to check profile existence: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, double>> getProfileCompletion(String userId) async {
    try {
      final profileResult = await getProfile(userId);
      return profileResult.fold(
        (failure) => Left(failure),
        (profile) => Right(profile.calculateProfileCompletion()),
      );
    } catch (e) {
      return Left(
        DataFailure(message: 'Failed to calculate profile completion: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, UserProfile>> verifyProfile(String userId) async {
    try {
      final verifiedProfile = await remoteDataSource.updateProfile(userId, {
        'verified': true,
      });

      // Update cache
      await localDataSource.cacheProfile(verifiedProfile);

      return Right(verifiedProfile);
    } on ForbiddenFailure catch (e) {
      return Left(
        ForbiddenFailure(
          message: 'Not authorized to verify profile: ${e.message}',
        ),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to verify profile: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> reportProfile(
    String reportedUserId,
    String reporterUserId,
    String reason,
    String? details,
  ) async {
    try {
      await remoteDataSource.reportProfile(
        reporterUserId,
        reportedUserId,
        reason: reason,
        description: details,
      );
      return const Right(null);
    } catch (e) {
      return Left(DataFailure(message: 'Failed to report profile: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> blockUser(
    String blockerUserId,
    String blockedUserId,
  ) async {
    try {
      await remoteDataSource.blockProfile(blockerUserId, blockedUserId);
      return const Right(null);
    } catch (e) {
      return Left(DataFailure(message: 'Failed to block user: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> unblockUser(
    String blockerUserId,
    String blockedUserId,
  ) async {
    try {
      await remoteDataSource.unblockProfile(blockerUserId, blockedUserId);
      return const Right(null);
    } catch (e) {
      return Left(DataFailure(message: 'Failed to unblock user: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getBlockedUsers(String userId) async {
    try {
      final blockedUsers = await remoteDataSource.getBlockedProfiles(userId);
      return Right(blockedUsers);
    } catch (e) {
      return Left(DataFailure(message: 'Failed to get blocked users: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateLastActive(String userId) async {
    try {
      await remoteDataSource.updateProfile(userId, {
        'last_active_at': DateTime.now().toIso8601String(),
      });
      // Invalidate cache to reflect updated timestamp
      await localDataSource.removeCachedProfile(userId);
      return const Right(null);
    } catch (e) {
      return Left(DataFailure(message: 'Failed to update last active: $e'));
    }
  }

  @override
  Future<Either<Failure, List<UserProfile>>> getProfileViewers(
    String userId, {
    int limit = 50,
  }) async {
    try {
      return Left(
        DataFailure(
          message: 'getProfileViewers not supported by remote data source',
        ),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to get profile viewers: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> recordProfileView(
    String viewedUserId,
    String viewerUserId,
  ) async {
    try {
      await remoteDataSource.trackProfileView(viewerUserId, viewedUserId);
      return const Right(null);
    } catch (e) {
      return Left(DataFailure(message: 'Failed to record profile view: $e'));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> bulkUpdateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final updatedProfile = await remoteDataSource.updateProfile(
        userId,
        updates,
      );

      // Update cache
      await localDataSource.cacheProfile(updatedProfile);

      return Right(updatedProfile);
    } on ValidationFailure catch (e) {
      return Left(
        ValidationFailure(message: 'Invalid update data: ${e.message}'),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to bulk update profile: $e'));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> importProfileData(
    String userId,
    Map<String, dynamic> externalData,
    String source,
  ) async {
    try {
      return Left(
        DataFailure(
          message: 'importProfileData not supported by remote data source',
        ),
      );
    } on ValidationFailure catch (e) {
      return Left(
        ValidationFailure(message: 'Invalid import data: ${e.message}'),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to import profile data: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> exportProfileData(
    String userId,
  ) async {
    try {
      return Left(
        DataFailure(
          message: 'exportProfileData not supported by remote data source',
        ),
      );
    } catch (e) {
      return Left(DataFailure(message: 'Failed to export profile data: $e'));
    }
  }

  /// Manages cache size and cleanup
  // ignore: unused_element
  Future<void> _manageCacheSize() async {
    try {
      final currentSize = await localDataSource.getCacheSize();
      if (currentSize > _maxCacheSize) {
        await localDataSource.optimizeCache();
      }
    } catch (e) {
      // Cache management errors are non-critical
      // print('Cache management error: $e');
    }
  }

  /// Preloads frequently accessed data
  Future<void> preloadData(String userId) async {
    try {
      // Preload profile, sports, and statistics in parallel
      await Future.wait([
        getProfile(userId),
        getSportsForUser(userId),
        getProfileStatistics(userId),
      ]);
    } catch (e) {
      // Preloading errors are non-critical
      // print('Preload error: $e');
    }
  }

  /// Clears all cached data
  Future<Either<Failure, void>> clearAllCache() async {
    try {
      await localDataSource.clearCache();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to clear cache: $e'));
    }
  }
}
