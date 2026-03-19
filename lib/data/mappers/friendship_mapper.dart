import 'package:dabbler/data/models/friendship.dart';
import 'package:dabbler/data/models/friend_edge.dart';
import 'package:dabbler/data/models/social/friend.dart';
import 'package:dabbler/data/models/social/friend_model.dart';
import 'package:dabbler/data/models/social/friend_request.dart';

/// Mapper for converting between database models and domain models
class FriendshipMapper {
  /// Convert database Friendship to domain Friend
  static Friend friendshipToFriend(
    Friendship friendship, {
    required String currentUserId,
    Map<String, dynamic>? profileData,
  }) {
    // Determine which user is the friend (not the current user)
    final friendId = friendship.userId == currentUserId
        ? friendship.peerUserId
        : friendship.userId;

    final friendName =
        profileData?['full_name'] as String? ??
        profileData?['display_name'] as String? ??
        'Unknown User';
    final friendUsername =
        profileData?['username'] as String? ??
        profileData?['handle'] as String? ??
        '';

    return Friend(
      id: '${friendship.userId}_${friendship.peerUserId}',
      userId: currentUserId,
      friendId: friendId,
      friendName: friendName,
      friendUsername: friendUsername,
      status: _mapStatus(friendship.status),
      createdAt: friendship.createdAt,
      updatedAt: friendship.updatedAt,
      friendRequestSentAt: friendship.createdAt,
      friendRequestAcceptedAt: friendship.status == 'accepted'
          ? friendship.updatedAt
          : null,
    );
  }

  /// Convert database Friendship with full profile to domain FriendModel
  static FriendModel friendshipToFriendModel(
    Friendship friendship, {
    required String currentUserId,
    required Map<String, dynamic> profileData,
  }) {
    final friendId = friendship.userId == currentUserId
        ? friendship.peerUserId
        : friendship.userId;

    final friendName =
        profileData['full_name'] as String? ??
        profileData['display_name'] as String? ??
        'Unknown User';
    final friendUsername =
        profileData['username'] as String? ??
        profileData['handle'] as String? ??
        '';

    return FriendModel(
      id: '${friendship.userId}_${friendship.peerUserId}',
      userId: currentUserId,
      friendId: friendId,
      friendName: friendName,
      friendUsername: friendUsername,
      status: _mapStatus(friendship.status),
      createdAt: friendship.createdAt,
      updatedAt: friendship.updatedAt,
      friendRequestSentAt: friendship.createdAt,
      friendRequestAcceptedAt: friendship.status == 'accepted'
          ? friendship.updatedAt
          : null,
      profilePicture: profileData['avatar_url'] as String? ?? '',
      bio: profileData['bio'] as String? ?? '',
      isVerified: profileData['is_verified'] as bool? ?? false,
      isOnline: false, // Will be updated by presence tracking
      lastSeen: profileData['last_seen_at'] != null
          ? DateTime.tryParse(profileData['last_seen_at'] as String)
          : null,
      mutualFriendsCount: profileData['mutual_friends_count'] as int? ?? 0,
      mutualFriendIds:
          (profileData['mutual_friend_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      favorSports:
          (profileData['favorite_sports'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      city: profileData['city'] as String?,
      joinedDate: profileData['created_at'] != null
          ? DateTime.tryParse(profileData['created_at'] as String)
          : null,
      isBlocked: false,
      hasBlockedMe: false,
    );
  }

  /// Convert FriendEdge to Friend
  static Friend friendEdgeToFriend(
    FriendEdge edge, {
    required String currentUserId,
    Map<String, dynamic>? profileDataA,
    Map<String, dynamic>? profileDataB,
  }) {
    // Determine which user is the friend
    final friendId = edge.userA == currentUserId ? edge.userB : edge.userA;
    final profileData = edge.userA == currentUserId
        ? profileDataB
        : profileDataA;

    final friendName =
        profileData?['full_name'] as String? ??
        profileData?['display_name'] as String? ??
        'Unknown User';
    final friendUsername =
        profileData?['username'] as String? ??
        profileData?['handle'] as String? ??
        '';

    return Friend(
      id: edge.id,
      userId: currentUserId,
      friendId: friendId,
      friendName: friendName,
      friendUsername: friendUsername,
      status: _mapStatus(edge.status),
      createdAt: edge.createdAt,
      updatedAt: edge.updatedAt,
      friendRequestSentAt: edge.createdAt,
      friendRequestAcceptedAt: edge.status == 'accepted'
          ? edge.updatedAt
          : null,
    );
  }

  /// Map database status string to FriendshipStatus enum
  static FriendshipStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return FriendshipStatus.pending;
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'declined':
      case 'rejected':
        return FriendshipStatus.declined;
      case 'blocked':
        return FriendshipStatus.blocked;
      default:
        return FriendshipStatus.pending;
    }
  }

  /// Map FriendshipStatus enum to database status string
  static String statusToString(FriendshipStatus status) {
    switch (status) {
      case FriendshipStatus.pending:
        return 'pending';
      case FriendshipStatus.accepted:
        return 'accepted';
      case FriendshipStatus.declined:
        return 'declined';
      case FriendshipStatus.blocked:
        return 'blocked';
    }
  }

  /// Map FriendRequestStatus to database status string
  static String requestStatusToString(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return 'pending';
      case FriendRequestStatus.accepted:
        return 'accepted';
      case FriendRequestStatus.declined:
        return 'declined';
      case FriendRequestStatus.cancelled:
        return 'cancelled';
      case FriendRequestStatus.blocked:
        return 'blocked';
    }
  }
}
