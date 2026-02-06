import 'package:freezed_annotation/freezed_annotation.dart';

part 'squad_join_request.freezed.dart';
part 'squad_join_request.g.dart';

@freezed
class SquadJoinRequest with _$SquadJoinRequest {
  const factory SquadJoinRequest({
    required String id,
    @JsonKey(name: 'squad_id') required String squadId,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'profile_id') required String profileId,
    required String status,
    String? message,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'decided_at') DateTime? decidedAt,
  }) = _SquadJoinRequest;

  factory SquadJoinRequest.fromJson(Map<String, dynamic> json) =>
      _$SquadJoinRequestFromJson(json);
}
