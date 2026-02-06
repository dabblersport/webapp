import 'package:freezed_annotation/freezed_annotation.dart';

part 'squad.freezed.dart';
part 'squad.g.dart';

Map<String, dynamic>? _metaFromJson(Map<String, dynamic>? json) => json;
Map<String, dynamic>? _metaToJson(Map<String, dynamic>? meta) => meta;

@freezed
class Squad with _$Squad {
  const factory Squad({
    required String id,
    required String sport,
    @JsonKey(name: 'owner_profile_id') required String ownerProfileId,
    @JsonKey(name: 'owner_user_id') required String ownerUserId,
    required String name,
    String? bio,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'created_by_user_id') required String createdByUserId,
    @JsonKey(name: 'created_by_profile_id') String? createdByProfileId,
    @JsonKey(name: 'created_by_role') String? createdByRole,
    @JsonKey(name: 'listing_visibility') String? listingVisibility,
    @JsonKey(name: 'join_policy') String? joinPolicy,
    @JsonKey(name: 'max_members') int? maxMembers,
    String? city,
    @JsonKey(fromJson: _metaFromJson, toJson: _metaToJson)
    Map<String, dynamic>? meta,
    @JsonKey(name: 'search_tsv') String? searchTsv,
  }) = _Squad;

  factory Squad.fromJson(Map<String, dynamic> json) => _$SquadFromJson(json);
}
