// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_status_map.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FriendStatusMapImpl _$$FriendStatusMapImplFromJson(
  Map<String, dynamic> json,
) => _$FriendStatusMapImpl(
  status: json['status'] as String,
  labelEn: json['label_en'] as String,
  labelAr: json['label_ar'] as String,
  sortOrder: (json['sort_order'] as num).toInt(),
);

Map<String, dynamic> _$$FriendStatusMapImplToJson(
  _$FriendStatusMapImpl instance,
) => <String, dynamic>{
  'status': instance.status,
  'label_en': instance.labelEn,
  'label_ar': instance.labelAr,
  'sort_order': instance.sortOrder,
};
