/// Domain entity for friend requests
class FriendRequest {
  final String id;
  final String fromUserId;
  final String toUserId;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? message;
  final DateTime? respondedAt;
  final String? responseMessage;

  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.message,
    this.respondedAt,
    this.responseMessage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendRequest &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Enum for friend request status
enum FriendRequestStatus { pending, accepted, declined, cancelled, blocked }
