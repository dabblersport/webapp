import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend_requests_audit.freezed.dart';
part 'friend_requests_audit.g.dart';

@freezed
class FriendRequestAudit with _$FriendRequestAudit {
  const factory FriendRequestAudit({
    required String id,
    @JsonKey(name: 'from_user') required String fromUser,
    @JsonKey(name: 'to_user') required String toUser,
    required String action,
    @JsonKey(name: 'edge_id') String? edgeId,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _FriendRequestAudit;

  factory FriendRequestAudit.fromJson(Map<String, dynamic> json) =>
      _$FriendRequestAuditFromJson(json);
}
