import 'package:fpdart/fpdart.dart';

import 'package:dabbler/core/fp/failure.dart';
import '../../../../utils/enums/social_enums.dart';
import 'package:dabbler/data/models/social/post_model.dart';
import 'package:dabbler/data/models/social/social_feed_model.dart';
import 'package:dabbler/data/models/social/reaction_model.dart';

/// Abstract repository for posts and social feed operations
abstract class PostsRepository {
  /// Get social feed with pagination and filtering
  Future<Either<Failure, SocialFeedModel>> getSocialFeed({
    FeedType feedType = FeedType.home,
    String? gameId,
    String? authorId,
    PostVisibility? visibility,
    int page = 1,
    int limit = 20,
    SortField sortBy = SortField.createdAt,
    SortDirection sortDirection = SortDirection.desc,
    Duration? maxAge,
  });

  /// Create a new post
  Future<Either<Failure, PostModel>> createPost({
    required String content,
    List<String>? mediaUrls,
    PostVisibility visibility = PostVisibility.public,
    String? gameId,
    String? cityName,
    List<String>? tags,
    List<String>? mentionedUsers,
    String? replyToPostId,
    String? shareOriginalId,
  });

  /// Get a specific post by ID
  Future<Either<Failure, PostModel>> getPost(String postId);

  /// Update an existing post
  Future<Either<Failure, PostModel>> updatePost({
    required String postId,
    String? content,
    List<String>? mediaUrls,
    PostVisibility? visibility,
    List<String>? tags,
    List<String>? mentionedUsers,
  });

  /// Delete a post
  Future<Either<Failure, bool>> deletePost(String postId);

  /// Get posts by a specific user
  Future<Either<Failure, List<PostModel>>> getUserPosts(
    String userId, {
    int page = 1,
    int limit = 20,
    PostVisibility? visibility,
  });

  /// Get posts for a specific game
  Future<Either<Failure, List<PostModel>>> getGamePosts(
    String gameId, {
    int page = 1,
    int limit = 20,
  });

  /// Search posts with query
  Future<Either<Failure, List<PostModel>>> searchPosts(
    String query, {
    int page = 1,
    int limit = 20,
    PostVisibility? visibility,
    String? gameId,
    List<String>? tags,
  });

  /// React to a post
  Future<Either<Failure, ReactionModel>> reactToPost({
    required String postId,
    required ReactionType reactionType,
  });

  /// Remove reaction from post
  Future<Either<Failure, bool>> removeReactionFromPost(String postId);

  /// Get reactions for a post
  Future<Either<Failure, List<ReactionModel>>> getPostReactions(
    String postId, {
    ReactionType? reactionType,
    int page = 1,
    int limit = 50,
  });

  /// Get grouped reactions for a post
  Future<Either<Failure, List<GroupedReaction>>> getGroupedPostReactions(
    String postId,
  );

  /// Comment on a post
  Future<Either<Failure, PostModel>> commentOnPost({
    required String postId,
    required String content,
    List<String>? mediaUrls,
    List<String>? mentionedUsers,
  });

  /// Get comments for a post
  Future<Either<Failure, List<PostModel>>> getPostComments(
    String postId, {
    int page = 1,
    int limit = 20,
    SortDirection sortDirection = SortDirection.asc,
  });

  /// React to a comment
  Future<Either<Failure, ReactionModel>> reactToComment({
    required String commentId,
    required ReactionType reactionType,
  });

  /// Remove reaction from comment
  Future<Either<Failure, bool>> removeReactionFromComment(String commentId);

  /// Share a post
  Future<Either<Failure, PostModel>> sharePost({
    required String originalPostId,
    String? content,
    PostVisibility visibility = PostVisibility.public,
  });

  /// Bookmark a post
  Future<Either<Failure, bool>> bookmarkPost(String postId);

  /// Remove bookmark from post
  Future<Either<Failure, bool>> removeBookmark(String postId);

  /// Get bookmarked posts
  Future<Either<Failure, List<PostModel>>> getBookmarkedPosts({
    int page = 1,
    int limit = 20,
  });

  /// Report a post
  Future<Either<Failure, bool>> reportPost({
    required String postId,
    required String reason,
    String? details,
  });

  /// Report a comment
  Future<Either<Failure, bool>> reportComment({
    required String commentId,
    required String reason,
    String? details,
  });

  /// Get trending posts
  Future<Either<Failure, List<PostModel>>> getTrendingPosts({
    Duration timeframe = const Duration(days: 7),
    int page = 1,
    int limit = 20,
    String? gameId,
  });

  /// Get posts by tags
  Future<Either<Failure, List<PostModel>>> getPostsByTags(
    List<String> tags, {
    int page = 1,
    int limit = 20,
    PostVisibility? visibility,
  });

  /// Get posts mentioning a user
  Future<Either<Failure, List<PostModel>>> getPostsMentioningUser(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Get post analytics (for post author)
  Future<Either<Failure, Map<String, dynamic>>> getPostAnalytics(String postId);

  /// Upload media for posts
  Future<Either<Failure, List<String>>> uploadPostMedia(List<String> filePaths);

  /// Delete comment
  Future<Either<Failure, bool>> deleteComment(String commentId);

  /// Update comment
  Future<Either<Failure, PostModel>> updateComment({
    required String commentId,
    required String content,
    List<String>? mediaUrls,
    List<String>? mentionedUsers,
  });
}
