import 'package:freezed_annotation/freezed_annotation.dart';

part 'game.freezed.dart';
part 'game.g.dart';

@freezed
class Game with _$Game {
  const factory Game({
    required String id,
    @JsonKey(name: 'game_type') required String gameType,
    required String sport,
    String? title,
    @JsonKey(name: 'host_profile_id') required String hostProfileId,
    @JsonKey(name: 'host_user_id') required String hostUserId,
    @JsonKey(name: 'venue_space_id') String? venueSpaceId,
    @JsonKey(name: 'start_at') required DateTime startAt,
    @JsonKey(name: 'end_at') required DateTime endAt,
    required int capacity,
    @JsonKey(name: 'listing_visibility') required String listingVisibility,
    @JsonKey(name: 'join_policy') required String joinPolicy,
    @JsonKey(name: 'allow_spectators') required bool allowSpectators,
    @JsonKey(name: 'min_skill') int? minSkill,
    @JsonKey(name: 'max_skill') int? maxSkill,
    @JsonKey(name: 'rules', defaultValue: <String, dynamic>{})
    required Map<String, dynamic> rules,
    @JsonKey(name: 'is_cancelled') required bool isCancelled,
    @JsonKey(name: 'cancelled_at') DateTime? cancelledAt,
    @JsonKey(name: 'cancelled_reason') String? cancelledReason,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'squad_id') String? squadId,
    @JsonKey(name: 'search_tsv') String? searchTsv,
  }) = _Game;

  factory Game.fromJson(Map<String, dynamic> json) => _$GameFromJson(json);
}
