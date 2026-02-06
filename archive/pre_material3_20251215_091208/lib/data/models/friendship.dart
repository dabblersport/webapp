import 'package:freezed_annotation/freezed_annotation.dart';

part 'friendship.freezed.dart';
part 'friendship.g.dart';

@freezed
class Friendship with _$Friendship {
  const factory Friendship({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'peer_user_id') required String peerUserId,
    @JsonKey(name: 'requested_by') String? requestedBy,
    required String status,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _Friendship;

  factory Friendship.fromJson(Map<String, dynamic> json) =>
      _$FriendshipFromJson(json);
}
