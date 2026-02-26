// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$GameImpl _$$GameImplFromJson(Map<String, dynamic> json) => _$GameImpl(
  id: json['id'] as String,
  gameType: json['game_type'] as String,
  sport: json['sport'] as String,
  title: json['title'] as String?,
  hostProfileId: json['host_profile_id'] as String,
  hostUserId: json['host_user_id'] as String,
  venueSpaceId: json['venue_space_id'] as String?,
  startAt: DateTime.parse(json['start_at'] as String),
  endAt: DateTime.parse(json['end_at'] as String),
  capacity: (json['capacity'] as num).toInt(),
  listingVisibility: json['listing_visibility'] as String,
  joinPolicy: json['join_policy'] as String,
  allowSpectators: json['allow_spectators'] as bool,
  minSkill: (json['min_skill'] as num?)?.toInt(),
  maxSkill: (json['max_skill'] as num?)?.toInt(),
  rules: json['rules'] as Map<String, dynamic>? ?? {},
  isCancelled: json['is_cancelled'] as bool,
  cancelledAt: json['cancelled_at'] == null
      ? null
      : DateTime.parse(json['cancelled_at'] as String),
  cancelledReason: json['cancelled_reason'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  squadId: json['squad_id'] as String?,
  searchTsv: json['search_tsv'] as String?,
);

Map<String, dynamic> _$$GameImplToJson(_$GameImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'game_type': instance.gameType,
      'sport': instance.sport,
      'title': instance.title,
      'host_profile_id': instance.hostProfileId,
      'host_user_id': instance.hostUserId,
      'venue_space_id': instance.venueSpaceId,
      'start_at': instance.startAt.toIso8601String(),
      'end_at': instance.endAt.toIso8601String(),
      'capacity': instance.capacity,
      'listing_visibility': instance.listingVisibility,
      'join_policy': instance.joinPolicy,
      'allow_spectators': instance.allowSpectators,
      'min_skill': instance.minSkill,
      'max_skill': instance.maxSkill,
      'rules': instance.rules,
      'is_cancelled': instance.isCancelled,
      'cancelled_at': instance.cancelledAt?.toIso8601String(),
      'cancelled_reason': instance.cancelledReason,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'squad_id': instance.squadId,
      'search_tsv': instance.searchTsv,
    };
