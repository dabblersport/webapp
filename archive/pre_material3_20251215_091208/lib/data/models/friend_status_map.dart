import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend_status_map.freezed.dart';
part 'friend_status_map.g.dart';

@freezed
class FriendStatusMap with _$FriendStatusMap {
  const factory FriendStatusMap({
    required String status,
    @JsonKey(name: 'label_en') required String labelEn,
    @JsonKey(name: 'label_ar') required String labelAr,
    @JsonKey(name: 'sort_order') required int sortOrder,
  }) = _FriendStatusMap;

  factory FriendStatusMap.fromJson(Map<String, dynamic> json) =>
      _$FriendStatusMapFromJson(json);
}
