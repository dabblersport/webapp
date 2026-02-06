// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organiser_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrganiserProfileImpl _$$OrganiserProfileImplFromJson(
  Map<String, dynamic> json,
) => _$OrganiserProfileImpl(
  id: json['id'] as String,
  profileId: json['profile_id'] as String,
  sport: json['sport'] as String,
  organiserLevel: (json['organiser_level'] as num?)?.toInt() ?? 1,
  commissionType: json['commission_type'] as String? ?? 'percent',
  commissionValue: (json['commission_value'] as num?)?.toDouble() ?? 0.0,
  isVerified: json['is_verified'] as bool? ?? false,
  isActive: json['is_active'] as bool? ?? true,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$$OrganiserProfileImplToJson(
  _$OrganiserProfileImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'profile_id': instance.profileId,
  'sport': instance.sport,
  'organiser_level': instance.organiserLevel,
  'commission_type': instance.commissionType,
  'commission_value': instance.commissionValue,
  'is_verified': instance.isVerified,
  'is_active': instance.isActive,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
};
