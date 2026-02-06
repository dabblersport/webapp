import 'package:dabbler/data/models/social/friend_model.dart';
import 'package:dabbler/data/models/social/friend.dart';

/// Exception types for friends data source operations
class FriendsDataSourceException implements Exception {
  final String message;
  final String code;
  final dynamic details;

  const FriendsDataSourceException({
    required this.message,
    required this.code,
    this.details,
  });

  @override
  String toString() => 'FriendsDataSourceException: $message (Code: $code)';
}

/// Duplicate friend request exception
class DuplicateFriendRequestException extends FriendsDataSourceException {
  const DuplicateFriendRequestException({
    required super.message,
    super.code = 'DUPLICATE_FRIEND_REQUEST',
    super.details,
  });
}

/// User blocked exception
class UserBlockedException extends FriendsDataSourceException {
  const UserBlockedException({
    required super.message,
    super.code = 'USER_BLOCKED',
    super.details,
  });
}

/// Privacy violation exception
class PrivacyViolationException extends FriendsDataSourceException {
  const PrivacyViolationException({
    required super.message,
    super.code = 'PRIVACY_VIOLATION',
    super.details,
  });
}

/// Friend not found exception
class FriendNotFoundException extends FriendsDataSourceException {
  const FriendNotFoundException({
    required super.message,
    super.code = 'FRIEND_NOT_FOUND',
    super.details,
  });
}

/// Self friend request exception
class SelfFriendRequestException extends FriendsDataSourceException {
  const SelfFriendRequestException({
    required super.message,
    super.code = 'SELF_FRIEND_REQUEST',
    super.details,
  });
}

/// Abstract interface for friends data source operations
abstract class FriendsDataSource {
  /// Get friends list with pagination and filtering
  Future<List<FriendModel>> getFriends({
    required String userId,
    FriendshipStatus? status,
    int page = 1,
    int limit = 20,
    String? searchQuery,
    List<String>? gameIds,
    bool includeProfile = true,
  });

  /// Get friend requests (sent and received)
  Future<List<FriendModel>> getFriendRequests({
    required String userId,
    bool sentRequests = false,
    int page = 1,
    int limit = 20,
  });

  /// Send friend request
  Future<FriendModel> sendFriendRequest({
    required String fromUserId,
    required String toUserId,
    String? message,
  });

  /// Accept friend request
  Future<FriendModel> acceptFriendRequest({
    required String requestId,
    required String userId,
  });

  /// Decline friend request
  Future<bool> declineFriendRequest({
    required String requestId,
    required String userId,
  });

  /// Cancel sent friend request
  Future<bool> cancelFriendRequest({
    required String requestId,
    required String userId,
  });

  /// Remove friend (unfriend)
  Future<bool> removeFriend({required String userId, required String friendId});

  /// Block user
  Future<bool> blockUser({
    required String userId,
    required String targetUserId,
    String? reason,
  });

  /// Unblock user
  Future<bool> unblockUser({
    required String userId,
    required String targetUserId,
  });

  /// Get blocked users list
  Future<List<String>> getBlockedUsers({
    required String userId,
    int page = 1,
    int limit = 20,
  });

  /// Check if user is blocked
  Future<bool> isUserBlocked({
    required String userId,
    required String targetUserId,
  });

  /// Get friend suggestions
  Future<List<FriendModel>> getFriendSuggestions({
    required String userId,
    int limit = 10,
    List<String>? excludeUserIds,
    Map<String, dynamic>? filters,
  });

  /// Get mutual friends
  Future<List<FriendModel>> getMutualFriends({
    required String userId,
    required String otherUserId,
    int page = 1,
    int limit = 20,
  });

  /// Search users for friend requests
  Future<List<FriendModel>> searchUsers({
    required String query,
    required String currentUserId,
    int page = 1,
    int limit = 20,
    Map<String, dynamic>? filters,
  });

  /// Get friendship status between two users
  Future<FriendshipStatus> getFriendshipStatus({
    required String userId,
    required String otherUserId,
  });

  /// Get friends count
  Future<int> getFriendsCount({
    required String userId,
    FriendshipStatus? status,
  });

  /// Get recent friends activity
  Future<List<Map<String, dynamic>>> getRecentFriendsActivity({
    required String userId,
    int limit = 10,
    Duration? timeRange,
  });

  /// Bulk operations
  Future<List<bool>> blockMultipleUsers({
    required String userId,
    required List<String> targetUserIds,
    String? reason,
  });

  Future<List<bool>> unblockMultipleUsers({
    required String userId,
    required List<String> targetUserIds,
  });

  /// Export friends data
  Future<Map<String, dynamic>> exportFriendsData({required String userId});

  /// Get friend recommendations based on mutual connections
  Future<List<FriendModel>> getFriendRecommendations({
    required String userId,
    int limit = 10,
    String? gameContext,
  });

  /// Update friend preferences (notifications, visibility, etc.)
  Future<bool> updateFriendPreferences({
    required String userId,
    required String friendId,
    required Map<String, dynamic> preferences,
  });

  /// Get friend preferences
  Future<Map<String, dynamic>> getFriendPreferences({
    required String userId,
    required String friendId,
  });

  /// Check friend request limits
  Future<bool> canSendFriendRequest({
    required String userId,
    required String targetUserId,
  });

  /// Get friend request history
  Future<List<Map<String, dynamic>>> getFriendRequestHistory({
    required String userId,
    int page = 1,
    int limit = 20,
  });

  /// Real-time subscriptions
  Stream<FriendModel> subscribeFriendRequests(String userId);
  Stream<FriendModel> subscribeFriendsUpdates(String userId);
  Stream<List<String>> subscribeBlockedUsersUpdates(String userId);
}
