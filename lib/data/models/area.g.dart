// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'area.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AreaImpl _$$AreaImplFromJson(Map<String, dynamic> json) => _$AreaImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  city: json['city'] as String,
  country: json['country'] as String,
  centerLat: (json['center_lat'] as num).toDouble(),
  centerLng: (json['center_lng'] as num).toDouble(),
  isActive: json['is_active'] as bool? ?? true,
  isVerified: json['is_verified'] as bool? ?? false,
);

Map<String, dynamic> _$$AreaImplToJson(_$AreaImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'city': instance.city,
      'country': instance.country,
      'center_lat': instance.centerLat,
      'center_lng': instance.centerLng,
      'is_active': instance.isActive,
      'is_verified': instance.isVerified,
    };
