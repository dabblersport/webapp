import 'package:freezed_annotation/freezed_annotation.dart';

part 'squad_member.freezed.dart';
part 'squad_member.g.dart';

@freezed
class SquadMember with _$SquadMember {
  const factory SquadMember({
    @JsonKey(name: 'squad_id') required String squadId,
    @JsonKey(name: 'profile_id') required String profileId,
    @JsonKey(name: 'user_id') required String userId,
    required String role,
    @JsonKey(name: 'joined_at') required DateTime joinedAt,
    @JsonKey(name: 'left_at') DateTime? leftAt,
    required String status,
  }) = _SquadMember;

  factory SquadMember.fromJson(Map<String, dynamic> json) =>
      _$SquadMemberFromJson(json);
}
