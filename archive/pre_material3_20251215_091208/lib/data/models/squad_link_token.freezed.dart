// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'squad_link_token.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SquadLinkToken _$SquadLinkTokenFromJson(Map<String, dynamic> json) {
  return _SquadLinkToken.fromJson(json);
}

/// @nodoc
mixin _$SquadLinkToken {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'squad_id')
  String get squadId => throw _privateConstructorUsedError;
  String get token => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by')
  String get createdBy => throw _privateConstructorUsedError;
  bool get active => throw _privateConstructorUsedError;
  @JsonKey(name: 'max_uses')
  int? get maxUses => throw _privateConstructorUsedError;
  @JsonKey(name: 'used_count')
  int get usedCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this SquadLinkToken to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SquadLinkToken
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SquadLinkTokenCopyWith<SquadLinkToken> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SquadLinkTokenCopyWith<$Res> {
  factory $SquadLinkTokenCopyWith(
    SquadLinkToken value,
    $Res Function(SquadLinkToken) then,
  ) = _$SquadLinkTokenCopyWithImpl<$Res, SquadLinkToken>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'squad_id') String squadId,
    String token,
    @JsonKey(name: 'created_by') String createdBy,
    bool active,
    @JsonKey(name: 'max_uses') int? maxUses,
    @JsonKey(name: 'used_count') int usedCount,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class _$SquadLinkTokenCopyWithImpl<$Res, $Val extends SquadLinkToken>
    implements $SquadLinkTokenCopyWith<$Res> {
  _$SquadLinkTokenCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SquadLinkToken
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? squadId = null,
    Object? token = null,
    Object? createdBy = null,
    Object? active = null,
    Object? maxUses = freezed,
    Object? usedCount = null,
    Object? expiresAt = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            squadId: null == squadId
                ? _value.squadId
                : squadId // ignore: cast_nullable_to_non_nullable
                      as String,
            token: null == token
                ? _value.token
                : token // ignore: cast_nullable_to_non_nullable
                      as String,
            createdBy: null == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String,
            active: null == active
                ? _value.active
                : active // ignore: cast_nullable_to_non_nullable
                      as bool,
            maxUses: freezed == maxUses
                ? _value.maxUses
                : maxUses // ignore: cast_nullable_to_non_nullable
                      as int?,
            usedCount: null == usedCount
                ? _value.usedCount
                : usedCount // ignore: cast_nullable_to_non_nullable
                      as int,
            expiresAt: freezed == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SquadLinkTokenImplCopyWith<$Res>
    implements $SquadLinkTokenCopyWith<$Res> {
  factory _$$SquadLinkTokenImplCopyWith(
    _$SquadLinkTokenImpl value,
    $Res Function(_$SquadLinkTokenImpl) then,
  ) = __$$SquadLinkTokenImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'squad_id') String squadId,
    String token,
    @JsonKey(name: 'created_by') String createdBy,
    bool active,
    @JsonKey(name: 'max_uses') int? maxUses,
    @JsonKey(name: 'used_count') int usedCount,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class __$$SquadLinkTokenImplCopyWithImpl<$Res>
    extends _$SquadLinkTokenCopyWithImpl<$Res, _$SquadLinkTokenImpl>
    implements _$$SquadLinkTokenImplCopyWith<$Res> {
  __$$SquadLinkTokenImplCopyWithImpl(
    _$SquadLinkTokenImpl _value,
    $Res Function(_$SquadLinkTokenImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SquadLinkToken
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? squadId = null,
    Object? token = null,
    Object? createdBy = null,
    Object? active = null,
    Object? maxUses = freezed,
    Object? usedCount = null,
    Object? expiresAt = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _$SquadLinkTokenImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        squadId: null == squadId
            ? _value.squadId
            : squadId // ignore: cast_nullable_to_non_nullable
                  as String,
        token: null == token
            ? _value.token
            : token // ignore: cast_nullable_to_non_nullable
                  as String,
        createdBy: null == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String,
        active: null == active
            ? _value.active
            : active // ignore: cast_nullable_to_non_nullable
                  as bool,
        maxUses: freezed == maxUses
            ? _value.maxUses
            : maxUses // ignore: cast_nullable_to_non_nullable
                  as int?,
        usedCount: null == usedCount
            ? _value.usedCount
            : usedCount // ignore: cast_nullable_to_non_nullable
                  as int,
        expiresAt: freezed == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SquadLinkTokenImpl implements _SquadLinkToken {
  const _$SquadLinkTokenImpl({
    required this.id,
    @JsonKey(name: 'squad_id') required this.squadId,
    required this.token,
    @JsonKey(name: 'created_by') required this.createdBy,
    required this.active,
    @JsonKey(name: 'max_uses') this.maxUses,
    @JsonKey(name: 'used_count') required this.usedCount,
    @JsonKey(name: 'expires_at') this.expiresAt,
    @JsonKey(name: 'created_at') required this.createdAt,
  });

  factory _$SquadLinkTokenImpl.fromJson(Map<String, dynamic> json) =>
      _$$SquadLinkTokenImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'squad_id')
  final String squadId;
  @override
  final String token;
  @override
  @JsonKey(name: 'created_by')
  final String createdBy;
  @override
  final bool active;
  @override
  @JsonKey(name: 'max_uses')
  final int? maxUses;
  @override
  @JsonKey(name: 'used_count')
  final int usedCount;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @override
  String toString() {
    return 'SquadLinkToken(id: $id, squadId: $squadId, token: $token, createdBy: $createdBy, active: $active, maxUses: $maxUses, usedCount: $usedCount, expiresAt: $expiresAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SquadLinkTokenImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.squadId, squadId) || other.squadId == squadId) &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.active, active) || other.active == active) &&
            (identical(other.maxUses, maxUses) || other.maxUses == maxUses) &&
            (identical(other.usedCount, usedCount) ||
                other.usedCount == usedCount) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    squadId,
    token,
    createdBy,
    active,
    maxUses,
    usedCount,
    expiresAt,
    createdAt,
  );

  /// Create a copy of SquadLinkToken
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SquadLinkTokenImplCopyWith<_$SquadLinkTokenImpl> get copyWith =>
      __$$SquadLinkTokenImplCopyWithImpl<_$SquadLinkTokenImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SquadLinkTokenImplToJson(this);
  }
}

abstract class _SquadLinkToken implements SquadLinkToken {
  const factory _SquadLinkToken({
    required final String id,
    @JsonKey(name: 'squad_id') required final String squadId,
    required final String token,
    @JsonKey(name: 'created_by') required final String createdBy,
    required final bool active,
    @JsonKey(name: 'max_uses') final int? maxUses,
    @JsonKey(name: 'used_count') required final int usedCount,
    @JsonKey(name: 'expires_at') final DateTime? expiresAt,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
  }) = _$SquadLinkTokenImpl;

  factory _SquadLinkToken.fromJson(Map<String, dynamic> json) =
      _$SquadLinkTokenImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'squad_id')
  String get squadId;
  @override
  String get token;
  @override
  @JsonKey(name: 'created_by')
  String get createdBy;
  @override
  bool get active;
  @override
  @JsonKey(name: 'max_uses')
  int? get maxUses;
  @override
  @JsonKey(name: 'used_count')
  int get usedCount;
  @override
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of SquadLinkToken
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SquadLinkTokenImplCopyWith<_$SquadLinkTokenImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
