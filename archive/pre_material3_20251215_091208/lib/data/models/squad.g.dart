// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SquadImpl _$$SquadImplFromJson(Map<String, dynamic> json) => _$SquadImpl(
  id: json['id'] as String,
  sport: json['sport'] as String,
  ownerProfileId: json['owner_profile_id'] as String,
  ownerUserId: json['owner_user_id'] as String,
  name: json['name'] as String,
  bio: json['bio'] as String?,
  logoUrl: json['logo_url'] as String?,
  isActive: json['is_active'] as bool,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  createdByUserId: json['created_by_user_id'] as String,
  createdByProfileId: json['created_by_profile_id'] as String?,
  createdByRole: json['created_by_role'] as String?,
  listingVisibility: json['listing_visibility'] as String?,
  joinPolicy: json['join_policy'] as String?,
  maxMembers: (json['max_members'] as num?)?.toInt(),
  city: json['city'] as String?,
  meta: _metaFromJson(json['meta'] as Map<String, dynamic>?),
  searchTsv: json['search_tsv'] as String?,
);

Map<String, dynamic> _$$SquadImplToJson(_$SquadImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sport': instance.sport,
      'owner_profile_id': instance.ownerProfileId,
      'owner_user_id': instance.ownerUserId,
      'name': instance.name,
      'bio': instance.bio,
      'logo_url': instance.logoUrl,
      'is_active': instance.isActive,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'created_by_user_id': instance.createdByUserId,
      'created_by_profile_id': instance.createdByProfileId,
      'created_by_role': instance.createdByRole,
      'listing_visibility': instance.listingVisibility,
      'join_policy': instance.joinPolicy,
      'max_members': instance.maxMembers,
      'city': instance.city,
      'meta': _metaToJson(instance.meta),
      'search_tsv': instance.searchTsv,
    };
