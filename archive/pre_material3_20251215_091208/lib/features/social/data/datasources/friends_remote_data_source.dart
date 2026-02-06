import 'package:dabbler/data/models/social/friend_model.dart';
import 'package:dabbler/data/models/social/friend.dart';

/// Abstract interface for friends remote data source
abstract class FriendsRemoteDataSource {
  /// Get friends list for a user with optional status filter
  Future<List<FriendModel>> getFriends(
    String userId, {
    FriendshipStatus? status,
    int? limit,
    int? offset,
  });

  /// Send a friend request to another user
  Future<FriendModel> sendFriendRequest(String toUserId, {String? message});

  /// Accept a friend request
  Future<FriendModel> acceptFriendRequest(String requestId);

  /// Decline a friend request
  Future<bool> declineFriendRequest(String requestId);

  /// Block a user
  Future<bool> blockUser(String userId);

  /// Unblock a user
  Future<bool> unblockUser(String userId);

  /// Get friend suggestions for current user
  Future<List<FriendModel>> getFriendSuggestions({int? limit, int? offset});

  /// Get mutual friends between current user and another user
  Future<List<FriendModel>> getMutualFriends(
    String userId, {
    int? limit,
    int? offset,
  });

  /// Search for users to send friend requests
  Future<List<FriendModel>> searchUsers(
    String query, {
    int? limit,
    int? offset,
  });

  /// Get pending friend requests (received)
  Future<List<FriendModel>> getPendingRequests({int? limit, int? offset});

  /// Get sent friend requests
  Future<List<FriendModel>> getSentRequests({int? limit, int? offset});

  /// Get blocked users list
  Future<List<FriendModel>> getBlockedUsers({int? limit, int? offset});

  /// Cancel a sent friend request
  Future<bool> cancelFriendRequest(String requestId);

  /// Remove a friend (unfriend)
  Future<bool> removeFriend(String friendId);

  /// Get friendship status between two users
  Future<FriendshipStatus?> getFriendshipStatus(
    String userId,
    String otherUserId,
  );

  /// Get online friends
  Future<List<FriendModel>> getOnlineFriends({int? limit, int? offset});

  /// Update friend request message
  Future<bool> updateFriendRequestMessage(String requestId, String message);

  /// Get friend statistics
  Future<Map<String, int>> getFriendStatistics(String userId);
}
