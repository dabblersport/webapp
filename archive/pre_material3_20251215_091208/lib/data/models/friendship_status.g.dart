// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friendship_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FriendshipStatusImpl _$$FriendshipStatusImplFromJson(
  Map<String, dynamic> json,
) => _$FriendshipStatusImpl(
  status: json['status'] as String,
  labelEn: json['label_en'] as String,
  labelAr: json['label_ar'] as String,
  emoji: json['emoji'] as String,
  colorHex: json['color_hex'] as String,
  sortOrder: (json['sort_order'] as num).toInt(),
);

Map<String, dynamic> _$$FriendshipStatusImplToJson(
  _$FriendshipStatusImpl instance,
) => <String, dynamic>{
  'status': instance.status,
  'label_en': instance.labelEn,
  'label_ar': instance.labelAr,
  'emoji': instance.emoji,
  'color_hex': instance.colorHex,
  'sort_order': instance.sortOrder,
};
