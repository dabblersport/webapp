/// Domain entity for friendships
class Friend {
  final String id;
  final String userId;
  final String friendId;
  final String friendName;
  final String friendUsername;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? friendRequestSentAt;
  final DateTime? friendRequestAcceptedAt;

  const Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendName,
    required this.friendUsername,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.friendRequestSentAt,
    this.friendRequestAcceptedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Friend && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Enum for friendship status
enum FriendshipStatus { pending, accepted, declined, blocked }
