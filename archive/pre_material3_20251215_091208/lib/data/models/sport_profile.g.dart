// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sport_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SportProfileImpl _$$SportProfileImplFromJson(Map<String, dynamic> json) =>
    _$SportProfileImpl(
      userId: json['user_id'] as String,
      sportKey: json['sport_key'] as String,
      skillLevel: (json['skill_level'] as num).toInt(),
    );

Map<String, dynamic> _$$SportProfileImplToJson(_$SportProfileImpl instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'sport_key': instance.sportKey,
      'skill_level': instance.skillLevel,
    };
