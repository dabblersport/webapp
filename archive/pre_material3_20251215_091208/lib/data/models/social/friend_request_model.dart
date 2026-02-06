import 'package:dabbler/data/models/social/friend_request.dart';

/// Data model for friend requests with additional functionality
class FriendRequestModel extends FriendRequest {
  final Map<String, dynamic> metadata;

  const FriendRequestModel({
    required super.id,
    required super.fromUserId,
    required super.toUserId,
    required super.status,
    required super.createdAt,
    super.updatedAt,
    super.message,
    super.respondedAt,
    super.responseMessage,
    this.metadata = const {},
  });

  /// Create a copy of this model with updated fields
  FriendRequestModel copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    FriendRequestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? message,
    DateTime? respondedAt,
    String? responseMessage,
    Map<String, dynamic>? metadata,
  }) {
    return FriendRequestModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      message: message ?? this.message,
      respondedAt: respondedAt ?? this.respondedAt,
      responseMessage: responseMessage ?? this.responseMessage,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Create from JSON map
  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] as String,
      fromUserId: json['from_user_id'] as String,
      toUserId: json['to_user_id'] as String,
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      message: json['message'] as String?,
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      responseMessage: json['response_message'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'message': message,
      'responded_at': respondedAt?.toIso8601String(),
      'response_message': responseMessage,
      'metadata': metadata,
    };
  }

  /// Check if request is pending
  bool get isPending => status == FriendRequestStatus.pending;

  /// Check if request is accepted
  bool get isAccepted => status == FriendRequestStatus.accepted;

  /// Check if request is declined
  bool get isDeclined => status == FriendRequestStatus.declined;

  /// Check if request is cancelled
  bool get isCancelled => status == FriendRequestStatus.cancelled;

  /// Check if request is blocked
  bool get isBlocked => status == FriendRequestStatus.blocked;

  /// Check if request can be responded to
  bool get canRespond => isPending;

  /// Check if request can be cancelled
  bool get canCancel => isPending;

  /// Get request age in days
  int get ageInDays => DateTime.now().difference(createdAt).inDays;

  /// Get request age in hours
  int get ageInHours => DateTime.now().difference(createdAt).inHours;

  /// Check if request is recent (less than 24 hours)
  bool get isRecent => ageInHours < 24;

  /// Check if request is old (more than 7 days)
  bool get isOld => ageInDays > 7;

  /// Convenience getters for notification service compatibility
  String get senderId => fromUserId;
  String get targetUserId => toUserId;
  String? get senderName => metadata['senderName'] as String?;
  String? get targetUserName => metadata['targetUserName'] as String?;
  String? get senderAvatarUrl => metadata['senderAvatarUrl'] as String?;

  @override
  String toString() {
    return 'FriendRequestModel(id: $id, fromUserId: $fromUserId, toUserId: $toUserId, status: $status, createdAt: $createdAt)';
  }
}
