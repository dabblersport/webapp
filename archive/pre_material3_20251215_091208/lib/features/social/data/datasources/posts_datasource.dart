import 'dart:io';
import 'package:dabbler/data/models/social/post_model.dart';
import 'package:dabbler/data/models/social/social_feed_model.dart';
import 'package:dabbler/data/models/social/reaction_model.dart';
import '../../../../utils/enums/social_enums.dart';

/// Exception types for posts data source operations
class PostsDataSourceException implements Exception {
  final String message;
  final String code;
  final dynamic details;

  const PostsDataSourceException({
    required this.message,
    required this.code,
    this.details,
  });

  @override
  String toString() => 'PostsDataSourceException: $message (Code: $code)';
}

/// Content validation exception
class ContentValidationException extends PostsDataSourceException {
  final List<String> errors;

  const ContentValidationException({
    required super.message,
    required this.errors,
    super.code = 'CONTENT_VALIDATION_ERROR',
    super.details,
  });
}

/// Media upload exception
class MediaUploadException extends PostsDataSourceException {
  const MediaUploadException({
    required super.message,
    super.code = 'MEDIA_UPLOAD_ERROR',
    super.details,
  });
}

/// Storage quota exceeded exception
class StorageQuotaException extends MediaUploadException {
  const StorageQuotaException({
    required super.message,
    super.code = 'STORAGE_QUOTA_EXCEEDED',
    super.details,
  });
}

/// Post privacy violation exception
class PostPrivacyViolationException extends PostsDataSourceException {
  const PostPrivacyViolationException({
    required super.message,
    super.code = 'POST_PRIVACY_VIOLATION',
    super.details,
  });
}

/// Post not found exception
class PostNotFoundException extends PostsDataSourceException {
  const PostNotFoundException({
    required super.message,
    super.code = 'POST_NOT_FOUND',
    super.details,
  });
}

/// Duplicate reaction exception
class DuplicateReactionException extends PostsDataSourceException {
  const DuplicateReactionException({
    required super.message,
    super.code = 'DUPLICATE_REACTION',
    super.details,
  });
}

/// Content moderation exception
class ContentModerationException extends PostsDataSourceException {
  const ContentModerationException({
    required super.message,
    super.code = 'CONTENT_MODERATED',
    super.details,
  });
}

/// Abstract interface for posts data source operations
abstract class PostsDataSource {
  /// Create a new post with validation
  Future<PostModel> createPost({
    required String authorId,
    required String content,
    List<File>? mediaFiles,
    PostVisibility visibility = PostVisibility.public,
    String? gameId,
    String? locationName,
    List<String>? tags,
    List<String>? mentionedUsers,
    String? replyToPostId,
    String? shareOriginalId,
  });

  /// Upload media files to storage
  Future<List<String>> uploadMedia({
    required List<File> files,
    required String userId,
    String? postId,
    Function(double)? onProgress,
  });

  /// Get social feed with complex filters
  Future<SocialFeedModel> getSocialFeed({
    required String userId,
    FeedType feedType = FeedType.home,
    String? gameId,
    String? authorId,
    PostVisibility? visibility,
    int page = 1,
    int limit = 20,
    SortField sortBy = SortField.createdAt,
    SortDirection sortDirection = SortDirection.desc,
    Duration? maxAge,
    List<String>? excludePostIds,
  });

  /// Get a specific post by ID
  Future<PostModel> getPost({
    required String postId,
    required String viewerId,
    bool incrementViewCount = true,
  });

  /// Update an existing post
  Future<PostModel> updatePost({
    required String postId,
    required String userId,
    String? content,
    List<File>? newMediaFiles,
    List<String>? removeMediaUrls,
    PostVisibility? visibility,
    List<String>? tags,
    List<String>? mentionedUsers,
  });

  /// Delete a post
  Future<bool> deletePost({
    required String postId,
    required String userId,
    bool deleteMedia = true,
  });

  /// Get posts by a specific user
  Future<List<PostModel>> getUserPosts({
    required String userId,
    required String viewerId,
    int page = 1,
    int limit = 20,
    PostVisibility? visibility,
    bool includeReplies = false,
    bool includeShares = true,
  });

  /// Get posts for a specific game
  Future<List<PostModel>> getGamePosts({
    required String gameId,
    required String viewerId,
    int page = 1,
    int limit = 20,
    PostVisibility? maxVisibility,
  });

  /// Search posts with advanced filtering
  Future<List<PostModel>> searchPosts({
    required String query,
    required String viewerId,
    int page = 1,
    int limit = 20,
    PostVisibility? visibility,
    String? gameId,
    List<String>? tags,
    String? authorId,
    DateTime? fromDate,
    DateTime? toDate,
    bool includeComments = false,
  });

  /// React to a post
  Future<ReactionModel> reactToPost({
    required String postId,
    required String userId,
    required ReactionType reactionType,
  });

  /// Remove reaction from post
  Future<bool> removeReactionFromPost({
    required String postId,
    required String userId,
  });

  /// Get reactions for a post
  Future<List<ReactionModel>> getPostReactions({
    required String postId,
    ReactionType? reactionType,
    int page = 1,
    int limit = 50,
  });

  /// Get grouped reactions for a post
  Future<List<GroupedReaction>> getGroupedPostReactions(String postId);

  /// Comment on a post
  Future<PostModel> commentOnPost({
    required String postId,
    required String userId,
    required String content,
    List<File>? mediaFiles,
    List<String>? mentionedUsers,
  });

  /// Get comments for a post
  Future<List<PostModel>> getPostComments({
    required String postId,
    required String viewerId,
    int page = 1,
    int limit = 20,
    SortDirection sortDirection = SortDirection.asc,
    bool includeReplies = true,
  });

  /// React to a comment
  Future<ReactionModel> reactToComment({
    required String commentId,
    required String userId,
    required ReactionType reactionType,
  });

  /// Remove reaction from comment
  Future<bool> removeReactionFromComment({
    required String commentId,
    required String userId,
  });

  /// Share a post
  Future<PostModel> sharePost({
    required String originalPostId,
    required String userId,
    String? content,
    PostVisibility visibility = PostVisibility.public,
  });

  /// Bookmark a post
  Future<bool> bookmarkPost({required String postId, required String userId});

  /// Remove bookmark from post
  Future<bool> removeBookmark({required String postId, required String userId});

  /// Get bookmarked posts
  Future<List<PostModel>> getBookmarkedPosts({
    required String userId,
    int page = 1,
    int limit = 20,
    String? gameId,
  });

  /// Report a post
  Future<bool> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
    String? details,
    List<String>? evidenceUrls,
  });

  /// Report a comment
  Future<bool> reportComment({
    required String commentId,
    required String reporterId,
    required String reason,
    String? details,
  });

  /// Get trending posts
  Future<List<PostModel>> getTrendingPosts({
    required String viewerId,
    Duration timeframe = const Duration(days: 7),
    int page = 1,
    int limit = 20,
    String? gameId,
    PostVisibility? maxVisibility,
  });

  /// Get posts by tags
  Future<List<PostModel>> getPostsByTags({
    required List<String> tags,
    required String viewerId,
    int page = 1,
    int limit = 20,
    PostVisibility? visibility,
    String? gameId,
  });

  /// Get posts mentioning a user
  Future<List<PostModel>> getPostsMentioningUser({
    required String userId,
    required String viewerId,
    int page = 1,
    int limit = 20,
    bool includeComments = true,
  });

  /// Get post analytics (for post author)
  Future<Map<String, dynamic>> getPostAnalytics({
    required String postId,
    required String authorId,
    DateTime? fromDate,
    DateTime? toDate,
  });

  /// Batch operations for performance
  Future<List<PostModel>> getMultiplePosts({
    required List<String> postIds,
    required String viewerId,
  });

  Future<List<bool>> bookmarkMultiplePosts({
    required List<String> postIds,
    required String userId,
  });

  Future<List<bool>> removeMultipleBookmarks({
    required List<String> postIds,
    required String userId,
  });

  /// Delete comment
  Future<bool> deleteComment({
    required String commentId,
    required String userId,
  });

  /// Update comment
  Future<PostModel> updateComment({
    required String commentId,
    required String userId,
    required String content,
    List<File>? newMediaFiles,
    List<String>? removeMediaUrls,
    List<String>? mentionedUsers,
  });

  /// Get post visibility for user
  Future<bool> canUserViewPost({
    required String postId,
    required String viewerId,
  });

  /// Handle post visibility rules
  Future<List<PostModel>> filterPostsByVisibility({
    required List<PostModel> posts,
    required String viewerId,
  });

  /// Get user's feed preferences
  Future<Map<String, dynamic>> getFeedPreferences(String userId);

  /// Update user's feed preferences
  Future<bool> updateFeedPreferences({
    required String userId,
    required Map<String, dynamic> preferences,
  });

  /// Get post engagement metrics
  Future<Map<String, dynamic>> getPostEngagement({
    required String postId,
    Duration? timeframe,
  });

  /// Pin/unpin post (for user's profile)
  Future<bool> pinPost({required String postId, required String userId});

  Future<bool> unpinPost({required String postId, required String userId});

  /// Get pinned posts for user
  Future<List<PostModel>> getPinnedPosts({
    required String userId,
    required String viewerId,
  });

  /// Archive/unarchive post
  Future<bool> archivePost({required String postId, required String userId});

  Future<bool> unarchivePost({required String postId, required String userId});

  /// Get archived posts
  Future<List<PostModel>> getArchivedPosts({
    required String userId,
    int page = 1,
    int limit = 20,
  });

  /// Real-time subscriptions
  Stream<PostModel> subscribeToFeedUpdates(String userId);
  Stream<PostModel> subscribeToPostComments(String postId);
  Stream<ReactionModel> subscribeToPostReactions(String postId);
  Stream<PostModel> subscribeToUserPosts(String userId);
}
