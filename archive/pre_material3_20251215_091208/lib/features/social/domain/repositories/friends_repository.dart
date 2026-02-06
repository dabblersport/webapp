import 'package:fpdart/fpdart.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/social/friend.dart';
import 'package:dabbler/data/models/social/friend_model.dart';

/// Abstract repository for friend management operations
abstract class FriendsRepository {
  /// Get friends list for a user with optional status filter
  Future<Either<Failure, List<FriendModel>>> getFriends(
    String userId, {
    FriendshipStatus? status,
    int? limit,
    int? offset,
  });

  /// Send a friend request to another user
  Future<Either<Failure, FriendModel>> sendFriendRequest(
    String toUserId, {
    String? message,
  });

  /// Accept a friend request
  Future<Either<Failure, FriendModel>> acceptFriendRequest(String requestId);

  /// Decline a friend request
  Future<Either<Failure, bool>> declineFriendRequest(String requestId);

  /// Block a user
  Future<Either<Failure, bool>> blockUser(String userId);

  /// Unblock a user
  Future<Either<Failure, bool>> unblockUser(String userId);

  /// Get friend suggestions for current user
  Future<Either<Failure, List<FriendModel>>> getFriendSuggestions({
    int? limit,
    int? offset,
  });

  /// Get mutual friends between current user and another user
  Future<Either<Failure, List<FriendModel>>> getMutualFriends(
    String userId, {
    int? limit,
    int? offset,
  });

  /// Search for users to send friend requests
  Future<Either<Failure, List<FriendModel>>> searchUsers(
    String query, {
    int? limit,
    int? offset,
  });

  /// Get pending friend requests (received)
  Future<Either<Failure, List<FriendModel>>> getPendingRequests({
    int? limit,
    int? offset,
  });

  /// Get sent friend requests
  Future<Either<Failure, List<FriendModel>>> getSentRequests({
    int? limit,
    int? offset,
  });

  /// Get blocked users list
  Future<Either<Failure, List<FriendModel>>> getBlockedUsers({
    int? limit,
    int? offset,
  });

  /// Cancel a sent friend request
  Future<Either<Failure, bool>> cancelFriendRequest(String requestId);

  /// Remove a friend (unfriend)
  Future<Either<Failure, bool>> removeFriend(String friendId);

  /// Get friendship status between two users
  Future<Either<Failure, FriendshipStatus?>> getFriendshipStatus(
    String userId,
    String otherUserId,
  );

  /// Get online friends
  Future<Either<Failure, List<FriendModel>>> getOnlineFriends({
    int? limit,
    int? offset,
  });

  /// Update friend request message
  Future<Either<Failure, bool>> updateFriendRequestMessage(
    String requestId,
    String message,
  );

  /// Get friend statistics
  Future<Either<Failure, Map<String, int>>> getFriendStatistics(String userId);
}
