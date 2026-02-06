// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'circle_contact.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CircleContact _$CircleContactFromJson(Map<String, dynamic> json) {
  return _CircleContact.fromJson(json);
}

/// @nodoc
mixin _$CircleContact {
  @JsonKey(name: 'friend_profile_id')
  String get friendProfileId => throw _privateConstructorUsedError;
  @JsonKey(name: 'friend_user_id')
  String get friendUserId => throw _privateConstructorUsedError;

  /// Serializes this CircleContact to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CircleContact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CircleContactCopyWith<CircleContact> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CircleContactCopyWith<$Res> {
  factory $CircleContactCopyWith(
    CircleContact value,
    $Res Function(CircleContact) then,
  ) = _$CircleContactCopyWithImpl<$Res, CircleContact>;
  @useResult
  $Res call({
    @JsonKey(name: 'friend_profile_id') String friendProfileId,
    @JsonKey(name: 'friend_user_id') String friendUserId,
  });
}

/// @nodoc
class _$CircleContactCopyWithImpl<$Res, $Val extends CircleContact>
    implements $CircleContactCopyWith<$Res> {
  _$CircleContactCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CircleContact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? friendProfileId = null, Object? friendUserId = null}) {
    return _then(
      _value.copyWith(
            friendProfileId: null == friendProfileId
                ? _value.friendProfileId
                : friendProfileId // ignore: cast_nullable_to_non_nullable
                      as String,
            friendUserId: null == friendUserId
                ? _value.friendUserId
                : friendUserId // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CircleContactImplCopyWith<$Res>
    implements $CircleContactCopyWith<$Res> {
  factory _$$CircleContactImplCopyWith(
    _$CircleContactImpl value,
    $Res Function(_$CircleContactImpl) then,
  ) = __$$CircleContactImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'friend_profile_id') String friendProfileId,
    @JsonKey(name: 'friend_user_id') String friendUserId,
  });
}

/// @nodoc
class __$$CircleContactImplCopyWithImpl<$Res>
    extends _$CircleContactCopyWithImpl<$Res, _$CircleContactImpl>
    implements _$$CircleContactImplCopyWith<$Res> {
  __$$CircleContactImplCopyWithImpl(
    _$CircleContactImpl _value,
    $Res Function(_$CircleContactImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CircleContact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? friendProfileId = null, Object? friendUserId = null}) {
    return _then(
      _$CircleContactImpl(
        friendProfileId: null == friendProfileId
            ? _value.friendProfileId
            : friendProfileId // ignore: cast_nullable_to_non_nullable
                  as String,
        friendUserId: null == friendUserId
            ? _value.friendUserId
            : friendUserId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CircleContactImpl implements _CircleContact {
  const _$CircleContactImpl({
    @JsonKey(name: 'friend_profile_id') required this.friendProfileId,
    @JsonKey(name: 'friend_user_id') required this.friendUserId,
  });

  factory _$CircleContactImpl.fromJson(Map<String, dynamic> json) =>
      _$$CircleContactImplFromJson(json);

  @override
  @JsonKey(name: 'friend_profile_id')
  final String friendProfileId;
  @override
  @JsonKey(name: 'friend_user_id')
  final String friendUserId;

  @override
  String toString() {
    return 'CircleContact(friendProfileId: $friendProfileId, friendUserId: $friendUserId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CircleContactImpl &&
            (identical(other.friendProfileId, friendProfileId) ||
                other.friendProfileId == friendProfileId) &&
            (identical(other.friendUserId, friendUserId) ||
                other.friendUserId == friendUserId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, friendProfileId, friendUserId);

  /// Create a copy of CircleContact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CircleContactImplCopyWith<_$CircleContactImpl> get copyWith =>
      __$$CircleContactImplCopyWithImpl<_$CircleContactImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CircleContactImplToJson(this);
  }
}

abstract class _CircleContact implements CircleContact {
  const factory _CircleContact({
    @JsonKey(name: 'friend_profile_id') required final String friendProfileId,
    @JsonKey(name: 'friend_user_id') required final String friendUserId,
  }) = _$CircleContactImpl;

  factory _CircleContact.fromJson(Map<String, dynamic> json) =
      _$CircleContactImpl.fromJson;

  @override
  @JsonKey(name: 'friend_profile_id')
  String get friendProfileId;
  @override
  @JsonKey(name: 'friend_user_id')
  String get friendUserId;

  /// Create a copy of CircleContact
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CircleContactImplCopyWith<_$CircleContactImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
