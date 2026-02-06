import 'package:freezed_annotation/freezed_annotation.dart';

part 'squad_link_token.freezed.dart';
part 'squad_link_token.g.dart';

@freezed
class SquadLinkToken with _$SquadLinkToken {
  const factory SquadLinkToken({
    required String id,
    @JsonKey(name: 'squad_id') required String squadId,
    required String token,
    @JsonKey(name: 'created_by') required String createdBy,
    required bool active,
    @JsonKey(name: 'max_uses') int? maxUses,
    @JsonKey(name: 'used_count') required int usedCount,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _SquadLinkToken;

  factory SquadLinkToken.fromJson(Map<String, dynamic> json) =>
      _$SquadLinkTokenFromJson(json);
}
