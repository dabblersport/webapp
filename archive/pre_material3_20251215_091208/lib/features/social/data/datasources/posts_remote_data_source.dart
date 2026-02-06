import 'package:dabbler/data/models/social/post_model.dart';
import 'package:dabbler/data/models/social/social_feed_model.dart';
import 'package:dabbler/data/models/social/reaction_model.dart';
import '../../../../utils/enums/social_enums.dart';

/// Abstract interface for posts remote data source
abstract class PostsRemoteDataSource {
  /// Get social feed with pagination and filtering
  Future<SocialFeedModel> getSocialFeed({
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
  Future<PostModel> createPost({
    required String content,
    List<String>? mediaUrls,
    PostVisibility visibility = PostVisibility.public,
    String? gameId,
    String? locationName,
    List<String>? tags,
    List<String>? mentionedUsers,
    String? replyToPostId,
    String? shareOriginalId,
  });

  /// Get a specific post by ID
  Future<PostModel> getPost(String postId);

  /// Update an existing post
  Future<PostModel> updatePost({
    required String postId,
    String? content,
    List<String>? mediaUrls,
    PostVisibility? visibility,
    List<String>? tags,
    List<String>? mentionedUsers,
  });

  /// Delete a post
  Future<bool> deletePost(String postId);

  /// Get posts by a specific user
  Future<List<PostModel>> getUserPosts(
    String userId, {
    int page = 1,
    int limit = 20,
    PostVisibility? visibility,
  });

  /// Get posts for a specific game
  Future<List<PostModel>> getGamePosts(
    String gameId, {
    int page = 1,
    int limit = 20,
  });

  /// Search posts with query
  Future<List<PostModel>> searchPosts(
    String query, {
    int page = 1,
    int limit = 20,
    PostVisibility? visibility,
    String? gameId,
    List<String>? tags,
  });

  /// React to a post
  Future<ReactionModel> reactToPost({
    required String postId,
    required ReactionType reactionType,
  });

  /// Remove reaction from post
  Future<bool> removeReactionFromPost(String postId);

  /// Get reactions for a post
  Future<List<ReactionModel>> getPostReactions(
    String postId, {
    ReactionType? reactionType,
    int page = 1,
    int limit = 50,
  });

  /// Get grouped reactions for a post
  Future<List<GroupedReaction>> getGroupedPostReactions(String postId);

  /// Comment on a post
  Future<PostModel> commentOnPost({
    required String postId,
    required String content,
    List<String>? mediaUrls,
    List<String>? mentionedUsers,
  });

  /// Get comments for a post
  Future<List<PostModel>> getPostComments(
    String postId, {
    int page = 1,
    int limit = 20,
    SortDirection sortDirection = SortDirection.asc,
  });

  /// React to a comment
  Future<ReactionModel> reactToComment({
    required String commentId,
    required ReactionType reactionType,
  });

  /// Remove reaction from comment
  Future<bool> removeReactionFromComment(String commentId);

  /// Share a post
  Future<PostModel> sharePost({
    required String originalPostId,
    String? content,
    PostVisibility visibility = PostVisibility.public,
  });

  /// Bookmark a post
  Future<bool> bookmarkPost(String postId);

  /// Remove bookmark from post
  Future<bool> removeBookmark(String postId);

  /// Get bookmarked posts
  Future<List<PostModel>> getBookmarkedPosts({int page = 1, int limit = 20});

  /// Report a post
  Future<bool> reportPost({
    required String postId,
    required String reason,
    String? details,
  });

  /// Report a comment
  Future<bool> reportComment({
    required String commentId,
    required String reason,
    String? details,
  });

  /// Get trending posts
  Future<List<PostModel>> getTrendingPosts({
    Duration timeframe = const Duration(days: 7),
    int page = 1,
    int limit = 20,
    String? gameId,
  });

  /// Get posts by tags
  Future<List<PostModel>> getPostsByTags(
    List<String> tags, {
    int page = 1,
    int limit = 20,
    PostVisibility? visibility,
  });

  /// Get posts mentioning a user
  Future<List<PostModel>> getPostsMentioningUser(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Get post analytics (for post author)
  Future<Map<String, dynamic>> getPostAnalytics(String postId);

  /// Upload media for posts
  Future<List<String>> uploadPostMedia(List<String> filePaths);

  /// Delete comment
  Future<bool> deleteComment(String commentId);

  /// Update comment
  Future<PostModel> updateComment({
    required String commentId,
    required String content,
    List<String>? mediaUrls,
    List<String>? mentionedUsers,
  });
}
