import 'package:freezed_annotation/freezed_annotation.dart';

part 'squad_invite.freezed.dart';
part 'squad_invite.g.dart';

@freezed
class SquadInvite with _$SquadInvite {
  const factory SquadInvite({
    required String id,
    @JsonKey(name: 'squad_id') required String squadId,
    @JsonKey(name: 'to_profile_id') required String toProfileId,
    @JsonKey(name: 'to_user_id') required String toUserId,
    @JsonKey(name: 'created_by_profile_id') required String createdByProfileId,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    required String status,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
  }) = _SquadInvite;

  factory SquadInvite.fromJson(Map<String, dynamic> json) =>
      _$SquadInviteFromJson(json);
}
