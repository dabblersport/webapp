import 'package:fpdart/fpdart.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/chat_message.dart';

/// Main social repository interface that coordinates all social features
abstract class SocialRepository {
  // ============ POST OPERATIONS ============

  /// Create a new post
  Future<Either<Failure, Post>> createPost({
    required String content,
    List<String>? mediaUrls,
    String? gameResultId,
    String? location,
    List<String>? mentions,
    Map<String, dynamic>? metadata,
  });

  /// Get user's feed
  Future<Either<Failure, Map<String, dynamic>>> getFeed({
    String feedType = 'home',
    int? limit,
    String? cursor,
  });

  /// Get a specific post
  Future<Either<Failure, Post>> getPost(String postId);

  /// React to a post
  Future<Either<Failure, dynamic>> reactToPost({
    required String postId,
    required String reactionType,
    Map<String, dynamic>? metadata,
  });

  /// Add comment to a post
  Future<Either<Failure, dynamic>> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
    List<String>? mentions,
  });

  /// Get trending posts
  Future<Either<Failure, List<Post>>> getTrendingPosts({
    Duration? timeframe,
    int? limit,
  });

  /// Delete a post
  Future<Either<Failure, bool>> deletePost(String postId);

  /// Update a post
  Future<Either<Failure, Post>> updatePost({
    required String postId,
    required String content,
    List<String>? mediaUrls,
    Map<String, dynamic>? metadata,
  });

  // ============ FRIEND OPERATIONS ============

  /// Send friend request
  Future<Either<Failure, dynamic>> sendFriendRequest({
    required String targetUserId,
    String? message,
  });

  /// Accept friend request
  Future<Either<Failure, bool>> acceptFriendRequest(String requestId);

  /// Decline friend request
  Future<Either<Failure, bool>> declineFriendRequest(String requestId);

  /// Get friends list
  Future<Either<Failure, List<dynamic>>> getFriends({String? userId});

  /// Get friend requests
  Future<Either<Failure, Map<String, List<dynamic>>>> getFriendRequests();

  /// Get mutual friends
  Future<Either<Failure, List<dynamic>>> getMutualFriends({
    required String userId,
  });

  /// Remove friend
  Future<Either<Failure, bool>> removeFriend(String friendId);

  /// Block user
  Future<Either<Failure, bool>> blockUser(String userId);

  /// Get blocked users
  Future<Either<Failure, List<dynamic>>> getBlockedUsers();

  /// Get potential friends for suggestions
  Future<Either<Failure, List<dynamic>>> getPotentialFriends({int? limit});

  /// Get current user data
  Future<Either<Failure, dynamic>> getCurrentUser();

  // ============ CHAT OPERATIONS ============

  /// Send a message
  Future<Either<Failure, ChatMessage>> sendMessage({
    required String conversationId,
    required String content,
    String type = 'text',
    List<String>? attachments,
    String? replyToId,
    Map<String, dynamic>? metadata,
  });

  /// Get messages for a conversation
  Future<Either<Failure, List<ChatMessage>>> getMessages({
    required String conversationId,
    int? limit,
    String? beforeMessageId,
  });

  /// Mark messages as read
  Future<Either<Failure, bool>> markAsRead({
    required String conversationId,
    required List<String> messageIds,
  });

  /// Update typing status
  Future<Either<Failure, bool>> updateTypingStatus({
    required String conversationId,
    required bool isTyping,
  });

  /// Delete a message
  Future<Either<Failure, bool>> deleteMessage({
    required String messageId,
    bool deleteForEveryone = false,
  });

  /// Get conversations list
  Future<Either<Failure, List<dynamic>>> getConversations({
    int? limit,
    String? cursor,
  });

  /// Create or get conversation
  Future<Either<Failure, dynamic>> getOrCreateConversation({
    required List<String> participantIds,
    String? conversationType,
  });

  // ============ USER DISCOVERY OPERATIONS ============

  /// Search users
  Future<Either<Failure, List<dynamic>>> searchUsers({
    required String query,
    Map<String, dynamic>? filters,
    int? limit,
    int? offset,
  });

  /// Get users near location
  Future<Either<Failure, List<dynamic>>> getUsersNearLocation({
    required double latitude,
    required double longitude,
    required double radiusKm,
    int? limit,
  });

  /// Get users by sports interests
  Future<Either<Failure, List<dynamic>>> getUsersBySportsInterests({
    required List<String> sportsInterests,
    String? skillLevelFilter,
    int? limit,
  });

  /// Get users by skill level
  Future<Either<Failure, List<dynamic>>> getUsersBySkillLevel({
    required String sport,
    required String skillLevel,
    bool includeSimilarLevels = true,
    int? limit,
  });

  /// Get users by activity level
  Future<Either<Failure, List<dynamic>>> getUsersByActivityLevel({
    required String activityLevel,
    int? limit,
  });

  /// Get mutual connections
  Future<Either<Failure, List<dynamic>>> getMutualConnections(
    String userId1,
    String userId2,
  );

  /// Get trending interests
  Future<Either<Failure, List<String>>> getTrendingInterests();

  // ============ ANALYTICS & SYNC OPERATIONS ============

  /// Sync data across features
  Future<Either<Failure, bool>> syncData({List<String>? features});

  /// Get sync status
  Future<Either<Failure, Map<String, dynamic>>> getSyncStatus();

  /// Force sync when back online
  Future<Either<Failure, bool>> forceSyncWhenOnline();

  /// Check if repository is online
  Future<bool> get isOnline;

  /// Subscribe to real-time updates
  Stream<dynamic> subscribeToUpdates(String channel);

  /// Dispose resources
  void dispose();
}
