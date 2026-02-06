import 'dart:io';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/profile/profile_statistics.dart';

/// Progress callback for file upload operations
typedef UploadProgressCallback = void Function(double progress);

/// Repository interface for profile-related operations
/// Follows clean architecture principles with Either return types for error handling
abstract class ProfileRepository {
  /// Retrieves a user profile by user ID
  /// [profileType] - Optional filter by profile type ('player' or 'organiser')
  /// Returns [UserProfile] on success or [Failure] on error
  Future<Either<Failure, UserProfile>> getProfile(
    String userId, {
    String? profileType,
  });

  /// Updates user profile information
  /// Supports partial updates - only non-null fields will be updated
  /// Returns updated [UserProfile] on success or [Failure] on error
  Future<Either<Failure, UserProfile>> updateProfile(UserProfile profile);

  /// Creates a new user profile (typically called during onboarding)
  /// Returns created [UserProfile] on success or [Failure] on error
  Future<Either<Failure, UserProfile>> createProfile(UserProfile profile);

  /// Deletes a user profile completely
  /// This is a destructive operation that removes all associated data
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> deleteProfile(String userId);

  /// Uploads a new avatar image for the user
  /// [file] - The image file to upload
  /// [onProgress] - Optional callback to track upload progress (0.0 to 1.0)
  /// Returns the new avatar URL on success or [Failure] on error
  Future<Either<Failure, String>> uploadAvatar(
    String userId,
    File file, {
    UploadProgressCallback? onProgress,
  });

  /// Deletes the user's current avatar
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> deleteAvatar(String userId);

  /// Retrieves all sports profiles for a user
  /// Returns list of [SportProfile] on success or [Failure] on error
  Future<Either<Failure, List<SportProfile>>> getSportsForUser(String userId);

  /// Updates or creates a sport profile for a user
  /// If [sportProfile.id] is null, creates a new profile
  /// Otherwise updates the existing profile
  /// Returns updated [SportProfile] on success or [Failure] on error
  Future<Either<Failure, SportProfile>> updateSportProfile(
    SportProfile sportProfile,
  );

  /// Deletes a sport profile
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> deleteSportProfile(String sportProfileId);

  /// Retrieves comprehensive statistics for a user
  /// This includes aggregated data from games, social interactions, etc.
  /// Returns [ProfileStatistics] on success or [Failure] on error
  Future<Either<Failure, ProfileStatistics>> getProfileStatistics(
    String userId,
  );

  /// Updates profile statistics
  /// Typically called after game completion or social interactions
  /// Returns updated [ProfileStatistics] on success or [Failure] on error
  Future<Either<Failure, ProfileStatistics>> updateProfileStatistics(
    String userId,
    ProfileStatistics statistics,
  );

  /// Searches for user profiles based on various criteria
  /// [query] - Search text (name, bio, location)
  /// [sportIds] - Filter by specific sports
  /// [location] - Filter by location proximity
  /// [maxDistance] - Maximum distance for location-based search (in km)
  /// [skillLevel] - Filter by skill level
  /// [limit] - Maximum number of results to return
  /// [offset] - Number of results to skip (for pagination)
  /// Returns list of [UserProfile] on success or [Failure] on error
  Future<Either<Failure, List<UserProfile>>> searchProfiles({
    String? query,
    List<String>? sportIds,
    String? location,
    double? maxDistance,
    String? skillLevel,
    int limit = 20,
    int offset = 0,
  });

  /// Gets profiles of users that might be good matches for the given user
  /// Uses compatibility algorithm based on sports, location, skill level, etc.
  /// Returns list of [UserProfile] on success or [Failure] on error
  Future<Either<Failure, List<UserProfile>>> getRecommendedProfiles(
    String userId, {
    int limit = 10,
  });

  /// Checks if a profile exists for the given user ID
  /// Returns [bool] on success or [Failure] on error
  Future<Either<Failure, bool>> profileExists(String userId);

  /// Gets the profile completion percentage for a user
  /// Returns [double] (0.0 to 100.0) on success or [Failure] on error
  Future<Either<Failure, double>> getProfileCompletion(String userId);

  /// Verifies a user profile (admin/moderator function)
  /// Returns updated [UserProfile] on success or [Failure] on error
  Future<Either<Failure, UserProfile>> verifyProfile(String userId);

  /// Reports a user profile for inappropriate content
  /// [reason] - Reason for reporting
  /// [details] - Additional details about the report
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> reportProfile(
    String reportedUserId,
    String reporterUserId,
    String reason,
    String? details,
  );

  /// Blocks a user profile
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> blockUser(
    String blockerUserId,
    String blockedUserId,
  );

  /// Unblocks a previously blocked user
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> unblockUser(
    String blockerUserId,
    String blockedUserId,
  );

  /// Gets list of blocked users
  /// Returns list of user IDs on success or [Failure] on error
  Future<Either<Failure, List<String>>> getBlockedUsers(String userId);

  /// Updates the user's last active timestamp
  /// Called periodically to track user activity
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> updateLastActive(String userId);

  /// Gets users who have viewed the profile recently
  /// Returns list of [UserProfile] on success or [Failure] on error
  Future<Either<Failure, List<UserProfile>>> getProfileViewers(
    String userId, {
    int limit = 50,
  });

  /// Records a profile view (when someone views a profile)
  /// Returns [void] on success or [Failure] on error
  Future<Either<Failure, void>> recordProfileView(
    String viewedUserId,
    String viewerUserId,
  );

  /// Bulk updates multiple profile fields atomically
  /// Returns updated [UserProfile] on success or [Failure] on error
  Future<Either<Failure, UserProfile>> bulkUpdateProfile(
    String userId,
    Map<String, dynamic> updates,
  );

  /// Imports profile data from external sources (social media, etc.)
  /// Returns updated [UserProfile] on success or [Failure] on error
  Future<Either<Failure, UserProfile>> importProfileData(
    String userId,
    Map<String, dynamic> externalData,
    String source,
  );

  /// Exports profile data for backup or migration
  /// Returns profile data as JSON on success or [Failure] on error
  Future<Either<Failure, Map<String, dynamic>>> exportProfileData(
    String userId,
  );
}
