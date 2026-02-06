import 'dart:io';
import 'package:dabbler/data/models/models.dart';

/// Exception types for remote data source operations
class ProfileRemoteDataSourceException implements Exception {
  final String message;
  final String code;
  final dynamic details;

  const ProfileRemoteDataSourceException({
    required this.message,
    required this.code,
    this.details,
  });

  @override
  String toString() =>
      'ProfileRemoteDataSourceException: $message (Code: $code)';
}

/// Network-related exceptions
class NetworkException extends ProfileRemoteDataSourceException {
  const NetworkException({
    required super.message,
    super.code = 'NETWORK_ERROR',
    super.details,
  });
}

/// Authentication/authorization exceptions
class AuthenticationException extends ProfileRemoteDataSourceException {
  const AuthenticationException({
    required super.message,
    super.code = 'AUTH_ERROR',
    super.details,
  });
}

/// Permission-related exceptions
class PermissionException extends ProfileRemoteDataSourceException {
  const PermissionException({
    required super.message,
    super.code = 'PERMISSION_DENIED',
    super.details,
  });
}

/// Data validation exceptions
class ValidationException extends ProfileRemoteDataSourceException {
  final List<String> errors;

  const ValidationException({
    required super.message,
    required this.errors,
    super.code = 'VALIDATION_ERROR',
    super.details,
  });
}

/// Storage-related exceptions
class StorageException extends ProfileRemoteDataSourceException {
  const StorageException({
    required super.message,
    super.code = 'STORAGE_ERROR',
    super.details,
  });
}

/// Storage quota exceeded exception
class StorageQuotaException extends StorageException {
  const StorageQuotaException({
    required super.message,
    super.code = 'STORAGE_QUOTA_EXCEEDED',
    super.details,
  });
}

/// Rate limiting exception
class RateLimitException extends ProfileRemoteDataSourceException {
  final int retryAfterSeconds;

  const RateLimitException({
    required super.message,
    required this.retryAfterSeconds,
    super.code = 'RATE_LIMIT_EXCEEDED',
    super.details,
  });
}

/// Data not found exception
class DataNotFoundException extends ProfileRemoteDataSourceException {
  const DataNotFoundException({
    required super.message,
    super.code = 'DATA_NOT_FOUND',
    super.details,
  });
}

/// Conflict exception (e.g., duplicate data)
class ConflictException extends ProfileRemoteDataSourceException {
  const ConflictException({
    required super.message,
    super.code = 'DATA_CONFLICT',
    super.details,
  });
}

/// Server error exception
class ServerException extends ProfileRemoteDataSourceException {
  const ServerException({
    required super.message,
    super.code = 'SERVER_ERROR',
    super.details,
  });
}

/// Abstract interface for profile remote data operations
abstract class ProfileRemoteDataSource {
  // Basic CRUD Operations

  /// Fetch user profile with optional sport profile joins
  /// [profileType] - Optional filter by profile type ('player' or 'organiser')
  /// Throws [NetworkException] for network errors
  /// Throws [DataNotFoundException] if profile doesn't exist
  /// Throws [AuthenticationException] for auth issues
  Future<UserProfile> getProfile(
    String userId, {
    bool includeSports = true,
    String? profileType,
  });

  /// Create a new profile
  /// Throws [ValidationException] for invalid data
  /// Throws [ConflictException] if profile already exists
  /// Throws [AuthenticationException] for auth issues
  Future<UserProfile> createProfile(UserProfile profile);

  /// Update profile with partial data
  /// Throws [ValidationException] for invalid data
  /// Throws [DataNotFoundException] if profile doesn't exist
  /// Throws [PermissionException] for access issues
  Future<UserProfile> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  );

  /// Delete profile and associated data
  /// Throws [DataNotFoundException] if profile doesn't exist
  /// Throws [PermissionException] for access issues
  Future<void> deleteProfile(String userId);

  /// Check if profile exists
  /// Throws [NetworkException] for network errors
  Future<bool> profileExists(String userId);

  // Avatar Operations

  /// Upload avatar image to storage
  /// Returns the public URL of the uploaded image
  /// Throws [StorageException] for upload failures
  /// Throws [StorageQuotaException] if quota exceeded
  /// Throws [ValidationException] for invalid file format/size
  Future<String> uploadAvatar(
    String userId,
    File imageFile, {
    String? fileName,
    Map<String, String>? metadata,
    Function(double)? onProgress,
  });

  /// Update avatar URL in profile
  /// Throws [ValidationException] for invalid URL
  /// Throws [DataNotFoundException] if profile doesn't exist
  Future<UserProfile> updateAvatarUrl(String userId, String avatarUrl);

  /// Delete avatar from storage and remove from profile
  /// Throws [StorageException] for deletion failures
  /// Throws [DataNotFoundException] if avatar doesn't exist
  Future<void> deleteAvatar(String userId);

  /// Get avatar upload URL for direct upload
  /// Returns signed URL for client-side upload
  Future<Map<String, dynamic>> getAvatarUploadUrl(
    String userId,
    String fileName,
  );

  // Sport Profile Operations

  /// Get sport profiles for user
  /// Throws [DataNotFoundException] if no sports found
  Future<List<SportProfileModel>> getSportProfiles(String userId);

  /// Add sport profile to user
  /// Throws [ValidationException] for invalid data
  /// Throws [ConflictException] if sport already exists
  Future<SportProfileModel> addSportProfile(
    String userId,
    SportProfileModel sportProfile,
  );

  /// Update specific sport profile
  /// Throws [ValidationException] for invalid data
  /// Throws [DataNotFoundException] if sport profile doesn't exist
  Future<SportProfileModel> updateSportProfile(
    String userId,
    String sportId,
    Map<String, dynamic> updates,
  );

  /// Remove sport profile from user
  /// Throws [DataNotFoundException] if sport profile doesn't exist
  Future<void> removeSportProfile(String userId, String sportId);

  /// Bulk update multiple sport profiles
  /// Returns list of updated sport profiles
  /// Throws [ValidationException] for invalid data
  Future<List<SportProfileModel>> bulkUpdateSportProfiles(
    String userId,
    List<Map<String, dynamic>> updates,
  );

  // Statistics Operations

  /// Get aggregated profile statistics
  /// Throws [DataNotFoundException] if no statistics found
  Future<ProfileStatisticsModel> getProfileStatistics(String userId);

  /// Update specific statistics
  /// Throws [ValidationException] for invalid data
  Future<ProfileStatisticsModel> updateStatistics(
    String userId,
    Map<String, dynamic> stats,
  );

  /// Increment specific statistic counters
  /// Throws [ValidationException] for invalid counters
  Future<ProfileStatisticsModel> incrementStats(
    String userId,
    Map<String, int> counters,
  );

  /// Reset specific statistics
  Future<ProfileStatisticsModel> resetStatistics(
    String userId,
    List<String> statKeys,
  );

  // Search and Discovery

  /// Search profiles by criteria
  /// Returns paginated results
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
  });

  /// Get profile recommendations for user
  /// Returns list of recommended profiles with similarity scores
  Future<List<Map<String, dynamic>>> getRecommendations(
    String userId, {
    int limit = 10,
    List<String>? sportTypes,
    String? location,
    double? maxDistance,
  });

  /// Get profiles in proximity to location
  Future<List<UserProfile>> getProfilesNearLocation(
    double latitude,
    double longitude,
    double radiusKm, {
    int limit = 20,
    List<String>? sportTypes,
  });

  // Social Features

  /// Block another user's profile
  /// Throws [ConflictException] if already blocked
  Future<void> blockProfile(String userId, String blockedUserId);

  /// Unblock a user's profile
  /// Throws [DataNotFoundException] if not blocked
  Future<void> unblockProfile(String userId, String blockedUserId);

  /// Get list of blocked profiles
  Future<List<String>> getBlockedProfiles(String userId);

  /// Check if user is blocked by another user
  Future<bool> isBlockedBy(String userId, String otherUserId);

  /// Report a profile for violations
  Future<void> reportProfile(
    String reporterId,
    String reportedUserId, {
    required String reason,
    String? description,
    List<String>? evidence,
  });

  // Profile Visibility and Privacy

  /// Update profile visibility settings
  Future<UserProfile> updateVisibility(
    String userId,
    Map<String, bool> visibilitySettings,
  );

  /// Check if profile is visible to another user
  Future<bool> isVisibleTo(String profileUserId, String viewerUserId);

  /// Get profile view permissions for user
  Future<Map<String, bool>> getViewPermissions(
    String profileUserId,
    String viewerUserId,
  );

  // Batch Operations

  /// Batch get multiple profiles
  /// Returns map of userId -> UserProfile
  Future<Map<String, UserProfile>> batchGetProfiles(
    List<String> userIds, {
    bool includeSports = true,
  });

  /// Batch update multiple profiles
  /// Returns map of userId -> updated UserProfile
  Future<Map<String, UserProfile>> batchUpdateProfiles(
    Map<String, Map<String, dynamic>> updates,
  );

  // Cache Management

  /// Preload profiles for better performance
  Future<void> preloadProfiles(List<String> userIds);

  /// Invalidate profile cache
  Future<void> invalidateCache(String userId);

  /// Warm up cache with frequently accessed data
  Future<void> warmUpCache(String userId);

  // Analytics and Monitoring

  /// Track profile view
  Future<void> trackProfileView(String viewerId, String profileUserId);

  /// Track profile interaction
  Future<void> trackProfileInteraction(
    String userId,
    String interactionType,
    Map<String, dynamic> data,
  );

  /// Get profile engagement metrics
  Future<Map<String, dynamic>> getEngagementMetrics(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  // Health Check and Diagnostics

  /// Check data source health
  Future<Map<String, dynamic>> healthCheck();

  /// Get connection status
  Future<bool> isConnected();

  /// Get data source metrics
  Future<Map<String, dynamic>> getMetrics();
}
