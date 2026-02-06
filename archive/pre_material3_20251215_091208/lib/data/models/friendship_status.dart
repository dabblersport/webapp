import 'package:freezed_annotation/freezed_annotation.dart';

part 'friendship_status.freezed.dart';
part 'friendship_status.g.dart';

@freezed
class FriendshipStatus with _$FriendshipStatus {
  const factory FriendshipStatus({
    required String status,
    @JsonKey(name: 'label_en') required String labelEn,
    @JsonKey(name: 'label_ar') required String labelAr,
    required String emoji,
    @JsonKey(name: 'color_hex') required String colorHex,
    @JsonKey(name: 'sort_order') required int sortOrder,
  }) = _FriendshipStatus;

  factory FriendshipStatus.fromJson(Map<String, dynamic> json) =>
      _$FriendshipStatusFromJson(json);
}
