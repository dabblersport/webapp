// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend_status_map.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FriendStatusMap _$FriendStatusMapFromJson(Map<String, dynamic> json) {
  return _FriendStatusMap.fromJson(json);
}

/// @nodoc
mixin _$FriendStatusMap {
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'label_en')
  String get labelEn => throw _privateConstructorUsedError;
  @JsonKey(name: 'label_ar')
  String get labelAr => throw _privateConstructorUsedError;
  @JsonKey(name: 'sort_order')
  int get sortOrder => throw _privateConstructorUsedError;

  /// Serializes this FriendStatusMap to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FriendStatusMap
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FriendStatusMapCopyWith<FriendStatusMap> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendStatusMapCopyWith<$Res> {
  factory $FriendStatusMapCopyWith(
    FriendStatusMap value,
    $Res Function(FriendStatusMap) then,
  ) = _$FriendStatusMapCopyWithImpl<$Res, FriendStatusMap>;
  @useResult
  $Res call({
    String status,
    @JsonKey(name: 'label_en') String labelEn,
    @JsonKey(name: 'label_ar') String labelAr,
    @JsonKey(name: 'sort_order') int sortOrder,
  });
}

/// @nodoc
class _$FriendStatusMapCopyWithImpl<$Res, $Val extends FriendStatusMap>
    implements $FriendStatusMapCopyWith<$Res> {
  _$FriendStatusMapCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FriendStatusMap
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? labelEn = null,
    Object? labelAr = null,
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
abstract class _$$FriendStatusMapImplCopyWith<$Res>
    implements $FriendStatusMapCopyWith<$Res> {
  factory _$$FriendStatusMapImplCopyWith(
    _$FriendStatusMapImpl value,
    $Res Function(_$FriendStatusMapImpl) then,
  ) = __$$FriendStatusMapImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String status,
    @JsonKey(name: 'label_en') String labelEn,
    @JsonKey(name: 'label_ar') String labelAr,
    @JsonKey(name: 'sort_order') int sortOrder,
  });
}

/// @nodoc
class __$$FriendStatusMapImplCopyWithImpl<$Res>
    extends _$FriendStatusMapCopyWithImpl<$Res, _$FriendStatusMapImpl>
    implements _$$FriendStatusMapImplCopyWith<$Res> {
  __$$FriendStatusMapImplCopyWithImpl(
    _$FriendStatusMapImpl _value,
    $Res Function(_$FriendStatusMapImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendStatusMap
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? status = null,
    Object? labelEn = null,
    Object? labelAr = null,
    Object? sortOrder = null,
  }) {
    return _then(
      _$FriendStatusMapImpl(
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
class _$FriendStatusMapImpl implements _FriendStatusMap {
  const _$FriendStatusMapImpl({
    required this.status,
    @JsonKey(name: 'label_en') required this.labelEn,
    @JsonKey(name: 'label_ar') required this.labelAr,
    @JsonKey(name: 'sort_order') required this.sortOrder,
  });

  factory _$FriendStatusMapImpl.fromJson(Map<String, dynamic> json) =>
      _$$FriendStatusMapImplFromJson(json);

  @override
  final String status;
  @override
  @JsonKey(name: 'label_en')
  final String labelEn;
  @override
  @JsonKey(name: 'label_ar')
  final String labelAr;
  @override
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  @override
  String toString() {
    return 'FriendStatusMap(status: $status, labelEn: $labelEn, labelAr: $labelAr, sortOrder: $sortOrder)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendStatusMapImpl &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.labelEn, labelEn) || other.labelEn == labelEn) &&
            (identical(other.labelAr, labelAr) || other.labelAr == labelAr) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, status, labelEn, labelAr, sortOrder);

  /// Create a copy of FriendStatusMap
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendStatusMapImplCopyWith<_$FriendStatusMapImpl> get copyWith =>
      __$$FriendStatusMapImplCopyWithImpl<_$FriendStatusMapImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$FriendStatusMapImplToJson(this);
  }
}

abstract class _FriendStatusMap implements FriendStatusMap {
  const factory _FriendStatusMap({
    required final String status,
    @JsonKey(name: 'label_en') required final String labelEn,
    @JsonKey(name: 'label_ar') required final String labelAr,
    @JsonKey(name: 'sort_order') required final int sortOrder,
  }) = _$FriendStatusMapImpl;

  factory _FriendStatusMap.fromJson(Map<String, dynamic> json) =
      _$FriendStatusMapImpl.fromJson;

  @override
  String get status;
  @override
  @JsonKey(name: 'label_en')
  String get labelEn;
  @override
  @JsonKey(name: 'label_ar')
  String get labelAr;
  @override
  @JsonKey(name: 'sort_order')
  int get sortOrder;

  /// Create a copy of FriendStatusMap
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendStatusMapImplCopyWith<_$FriendStatusMapImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
