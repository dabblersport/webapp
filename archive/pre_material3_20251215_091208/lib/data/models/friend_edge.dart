import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend_edge.freezed.dart';
part 'friend_edge.g.dart';

@freezed
class FriendEdge with _$FriendEdge {
  const factory FriendEdge({
    required String id,
    @JsonKey(name: 'user_a') required String userA,
    @JsonKey(name: 'user_b') required String userB,
    required String status,
    @JsonKey(name: 'requested_by') required String requestedBy,
    @JsonKey(name: 'responded_by') String? respondedBy,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _FriendEdge;

  factory FriendEdge.fromJson(Map<String, dynamic> json) =>
      _$FriendEdgeFromJson(json);
}
