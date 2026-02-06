// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friendship_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FriendshipStatus _$FriendshipStatusFromJson(Map<String, dynamic> json) {
  return _FriendshipStatus.fromJson(json);
}

/// @nodoc
mixin _$FriendshipStatus {
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'label_en')
  String get labelEn => throw _privateConstructorUsedError;
  @JsonKey(name: 'label_ar')
  String get labelAr => throw _privateConstructorUsedError;
  String get emoji => throw _privateConstructorUsedError;
  @JsonKey(name: 'color_hex')
  String get colorHex => throw _privateConstructorUsedError;
  @JsonKey(name: 'sort_order')
  int get sortOrder => throw _privateConstructorUsedError;

  /// Serializes this FriendshipStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FriendshipStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FriendshipStatusCopyWith<FriendshipStatus> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendshipStatusCopyWith<$Res> {
  factory $FriendshipStatusCopyWith(
    FriendshipStatus value,
    $Res Function(FriendshipStatus) then,
  ) = _$FriendshipStatusCopyWithImpl<$Res, FriendshipStatus>;
  @useResult
  $Res call({
    String status,
    @JsonKey(name: 'label_en') String labelEn,
    @JsonKey(name: 'label_ar') String labelAr,
    String emoji,
    @JsonKey(name: 'color_hex') String colorHex,
    @JsonKey(name: 'sort_order') int sortOrder,
  });
}

/// @nodoc
class _$FriendshipStatusCopyWithImpl<$Res, $Val extends FriendshipStatus>
    implements $FriendshipStatusCopyWith<$Res> {
  _$FriendshipStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FriendshipStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? labelEn = null,
    Object? labelAr = null,
    Object? emoji = null,
    Object? colorHex = null,
    Object? sortOrder = null,
  }) {
    return _then(
      _value.copyWith(
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            labelEn: null == labelEn
                ? _value.labelEn
                : labelEn // ignore: cast_nullable_to_non_nullable
                      as String,
            labelAr: null == labelAr
                ? _value.labelAr
                : labelAr // ignore: cast_nullable_to_non_nullable
                      as String,
            emoji: null == emoji
                ? _value.emoji
                : emoji // ignore: cast_nullable_to_non_nullable
                      as String,
            colorHex: null == colorHex
                ? _value.colorHex
                : colorHex // ignore: cast_nullable_to_non_nullable
                      as String,
            sortOrder: null == sortOrder
                ? _value.sortOrder
                : sortOrder // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FriendshipStatusImplCopyWith<$Res>
    implements $FriendshipStatusCopyWith<$Res> {
  factory _$$FriendshipStatusImplCopyWith(
    _$FriendshipStatusImpl value,
    $Res Function(_$FriendshipStatusImpl) then,
  ) = __$$FriendshipStatusImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String status,
    @JsonKey(name: 'label_en') String labelEn,
    @JsonKey(name: 'label_ar') String labelAr,
    String emoji,
    @JsonKey(name: 'color_hex') String colorHex,
    @JsonKey(name: 'sort_order') int sortOrder,
  });
}

/// @nodoc
class __$$FriendshipStatusImplCopyWithImpl<$Res>
    extends _$FriendshipStatusCopyWithImpl<$Res, _$FriendshipStatusImpl>
    implements _$$FriendshipStatusImplCopyWith<$Res> {
  __$$FriendshipStatusImplCopyWithImpl(
    _$FriendshipStatusImpl _value,
    $Res Function(_$FriendshipStatusImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendshipStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? labelEn = null,
    Object? labelAr = null,
    Object? emoji = null,
    Object? colorHex = null,
    Object? sortOrder = null,
  }) {
    return _then(
      _$FriendshipStatusImpl(
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        labelEn: null == labelEn
            ? _value.labelEn
            : labelEn // ignore: cast_nullable_to_non_nullable
                  as String,
        labelAr: null == labelAr
            ? _value.labelAr
            : labelAr // ignore: cast_nullable_to_non_nullable
                  as String,
        emoji: null == emoji
            ? _value.emoji
            : emoji // ignore: cast_nullable_to_non_nullable
                  as String,
        colorHex: null == colorHex
            ? _value.colorHex
            : colorHex // ignore: cast_nullable_to_non_nullable
                  as String,
        sortOrder: null == sortOrder
            ? _value.sortOrder
            : sortOrder // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FriendshipStatusImpl implements _FriendshipStatus {
  const _$FriendshipStatusImpl({
    required this.status,
    @JsonKey(name: 'label_en') required this.labelEn,
    @JsonKey(name: 'label_ar') required this.labelAr,
    required this.emoji,
    @JsonKey(name: 'color_hex') required this.colorHex,
    @JsonKey(name: 'sort_order') required this.sortOrder,
  });

  factory _$FriendshipStatusImpl.fromJson(Map<String, dynamic> json) =>
      _$$FriendshipStatusImplFromJson(json);

  @override
  final String status;
  @override
  @JsonKey(name: 'label_en')
  final String labelEn;
  @override
  @JsonKey(name: 'label_ar')
  final String labelAr;
  @override
  final String emoji;
  @override
  @JsonKey(name: 'color_hex')
  final String colorHex;
  @override
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  @override
  String toString() {
    return 'FriendshipStatus(status: $status, labelEn: $labelEn, labelAr: $labelAr, emoji: $emoji, colorHex: $colorHex, sortOrder: $sortOrder)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendshipStatusImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.labelEn, labelEn) || other.labelEn == labelEn) &&
            (identical(other.labelAr, labelAr) || other.labelAr == labelAr) &&
            (identical(other.emoji, emoji) || other.emoji == emoji) &&
            (identical(other.colorHex, colorHex) ||
                other.colorHex == colorHex) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    status,
    labelEn,
    labelAr,
    emoji,
    colorHex,
    sortOrder,
  );

  /// Create a copy of FriendshipStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendshipStatusImplCopyWith<_$FriendshipStatusImpl> get copyWith =>
      __$$FriendshipStatusImplCopyWithImpl<_$FriendshipStatusImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$FriendshipStatusImplToJson(this);
  }
}

abstract class _FriendshipStatus implements FriendshipStatus {
  const factory _FriendshipStatus({
    required final String status,
    @JsonKey(name: 'label_en') required final String labelEn,
    @JsonKey(name: 'label_ar') required final String labelAr,
    required final String emoji,
    @JsonKey(name: 'color_hex') required final String colorHex,
    @JsonKey(name: 'sort_order') required final int sortOrder,
  }) = _$FriendshipStatusImpl;

  factory _FriendshipStatus.fromJson(Map<String, dynamic> json) =
      _$FriendshipStatusImpl.fromJson;

  @override
  String get status;
  @override
  @JsonKey(name: 'label_en')
  String get labelEn;
  @override
  @JsonKey(name: 'label_ar')
  String get labelAr;
  @override
  String get emoji;
  @override
  @JsonKey(name: 'color_hex')
  String get colorHex;
  @override
  @JsonKey(name: 'sort_order')
  int get sortOrder;

  /// Create a copy of FriendshipStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendshipStatusImplCopyWith<_$FriendshipStatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
