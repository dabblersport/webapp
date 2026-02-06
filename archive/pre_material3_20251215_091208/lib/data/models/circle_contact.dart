import 'package:freezed_annotation/freezed_annotation.dart';

part 'circle_contact.freezed.dart';
part 'circle_contact.g.dart';

@freezed
class CircleContact with _$CircleContact {
  const factory CircleContact({
    @JsonKey(name: 'friend_profile_id') required String friendProfileId,
    @JsonKey(name: 'friend_user_id') required String friendUserId,
  }) = _CircleContact;

  factory CircleContact.fromJson(Map<String, dynamic> json) =>
      _$CircleContactFromJson(json);
}
