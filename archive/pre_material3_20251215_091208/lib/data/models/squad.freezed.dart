// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'squad.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Squad _$SquadFromJson(Map<String, dynamic> json) {
  return _Squad.fromJson(json);
}

/// @nodoc
mixin _$Squad {
  String get id => throw _privateConstructorUsedError;
  String get sport => throw _privateConstructorUsedError;
  @JsonKey(name: 'owner_profile_id')
  String get ownerProfileId => throw _privateConstructorUsedError;
  @JsonKey(name: 'owner_user_id')
  String get ownerUserId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get bio => throw _privateConstructorUsedError;
  @JsonKey(name: 'logo_url')
  String? get logoUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by_user_id')
  String get createdByUserId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by_profile_id')
  String? get createdByProfileId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by_role')
  String? get createdByRole => throw _privateConstructorUsedError;
  @JsonKey(name: 'listing_visibility')
  String? get listingVisibility => throw _privateConstructorUsedError;
  @JsonKey(name: 'join_policy')
  String? get joinPolicy => throw _privateConstructorUsedError;
  @JsonKey(name: 'max_members')
  int? get maxMembers => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _metaFromJson, toJson: _metaToJson)
  Map<String, dynamic>? get meta => throw _privateConstructorUsedError;
  @JsonKey(name: 'search_tsv')
  String? get searchTsv => throw _privateConstructorUsedError;

  /// Serializes this Squad to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Squad
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SquadCopyWith<Squad> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SquadCopyWith<$Res> {
  factory $SquadCopyWith(Squad value, $Res Function(Squad) then) =
      _$SquadCopyWithImpl<$Res, Squad>;
  @useResult
  $Res call({
    String id,
    String sport,
    @JsonKey(name: 'owner_profile_id') String ownerProfileId,
    @JsonKey(name: 'owner_user_id') String ownerUserId,
    String name,
    String? bio,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    @JsonKey(name: 'created_by_user_id') String createdByUserId,
    @JsonKey(name: 'created_by_profile_id') String? createdByProfileId,
    @JsonKey(name: 'created_by_role') String? createdByRole,
    @JsonKey(name: 'listing_visibility') String? listingVisibility,
    @JsonKey(name: 'join_policy') String? joinPolicy,
    @JsonKey(name: 'max_members') int? maxMembers,
    String? city,
    @JsonKey(fromJson: _metaFromJson, toJson: _metaToJson)
    Map<String, dynamic>? meta,
    @JsonKey(name: 'search_tsv') String? searchTsv,
  });
}

/// @nodoc
class _$SquadCopyWithImpl<$Res, $Val extends Squad>
    implements $SquadCopyWith<$Res> {
  _$SquadCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Squad
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sport = null,
    Object? ownerProfileId = null,
    Object? ownerUserId = null,
    Object? name = null,
    Object? bio = freezed,
    Object? logoUrl = freezed,
    Object? isActive = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? createdByUserId = null,
    Object? createdByProfileId = freezed,
    Object? createdByRole = freezed,
    Object? listingVisibility = freezed,
    Object? joinPolicy = freezed,
    Object? maxMembers = freezed,
    Object? city = freezed,
    Object? meta = freezed,
    Object? searchTsv = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            sport: null == sport
                ? _value.sport
                : sport // ignore: cast_nullable_to_non_nullable
                      as String,
            ownerProfileId: null == ownerProfileId
                ? _value.ownerProfileId
                : ownerProfileId // ignore: cast_nullable_to_non_nullable
                      as String,
            ownerUserId: null == ownerUserId
                ? _value.ownerUserId
                : ownerUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            bio: freezed == bio
                ? _value.bio
                : bio // ignore: cast_nullable_to_non_nullable
                      as String?,
            logoUrl: freezed == logoUrl
                ? _value.logoUrl
                : logoUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            createdByUserId: null == createdByUserId
                ? _value.createdByUserId
                : createdByUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            createdByProfileId: freezed == createdByProfileId
                ? _value.createdByProfileId
                : createdByProfileId // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdByRole: freezed == createdByRole
                ? _value.createdByRole
                : createdByRole // ignore: cast_nullable_to_non_nullable
                      as String?,
            listingVisibility: freezed == listingVisibility
                ? _value.listingVisibility
                : listingVisibility // ignore: cast_nullable_to_non_nullable
                      as String?,
            joinPolicy: freezed == joinPolicy
                ? _value.joinPolicy
                : joinPolicy // ignore: cast_nullable_to_non_nullable
                      as String?,
            maxMembers: freezed == maxMembers
                ? _value.maxMembers
                : maxMembers // ignore: cast_nullable_to_non_nullable
                      as int?,
            city: freezed == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String?,
            meta: freezed == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            searchTsv: freezed == searchTsv
                ? _value.searchTsv
                : searchTsv // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SquadImplCopyWith<$Res> implements $SquadCopyWith<$Res> {
  factory _$$SquadImplCopyWith(
    _$SquadImpl value,
    $Res Function(_$SquadImpl) then,
  ) = __$$SquadImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String sport,
    @JsonKey(name: 'owner_profile_id') String ownerProfileId,
    @JsonKey(name: 'owner_user_id') String ownerUserId,
    String name,
    String? bio,
    @JsonKey(name: 'logo_url') String? logoUrl,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    @JsonKey(name: 'created_by_user_id') String createdByUserId,
    @JsonKey(name: 'created_by_profile_id') String? createdByProfileId,
    @JsonKey(name: 'created_by_role') String? createdByRole,
    @JsonKey(name: 'listing_visibility') String? listingVisibility,
    @JsonKey(name: 'join_policy') String? joinPolicy,
    @JsonKey(name: 'max_members') int? maxMembers,
    String? city,
    @JsonKey(fromJson: _metaFromJson, toJson: _metaToJson)
    Map<String, dynamic>? meta,
    @JsonKey(name: 'search_tsv') String? searchTsv,
  });
}

/// @nodoc
class __$$SquadImplCopyWithImpl<$Res>
    extends _$SquadCopyWithImpl<$Res, _$SquadImpl>
    implements _$$SquadImplCopyWith<$Res> {
  __$$SquadImplCopyWithImpl(
    _$SquadImpl _value,
    $Res Function(_$SquadImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Squad
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sport = null,
    Object? ownerProfileId = null,
    Object? ownerUserId = null,
    Object? name = null,
    Object? bio = freezed,
    Object? logoUrl = freezed,
    Object? isActive = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? createdByUserId = null,
    Object? createdByProfileId = freezed,
    Object? createdByRole = freezed,
    Object? listingVisibility = freezed,
    Object? joinPolicy = freezed,
    Object? maxMembers = freezed,
    Object? city = freezed,
    Object? meta = freezed,
    Object? searchTsv = freezed,
  }) {
    return _then(
      _$SquadImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        sport: null == sport
            ? _value.sport
            : sport // ignore: cast_nullable_to_non_nullable
                  as String,
        ownerProfileId: null == ownerProfileId
            ? _value.ownerProfileId
            : ownerProfileId // ignore: cast_nullable_to_non_nullable
                  as String,
        ownerUserId: null == ownerUserId
            ? _value.ownerUserId
            : ownerUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        bio: freezed == bio
            ? _value.bio
            : bio // ignore: cast_nullable_to_non_nullable
                  as String?,
        logoUrl: freezed == logoUrl
            ? _value.logoUrl
            : logoUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        createdByUserId: null == createdByUserId
            ? _value.createdByUserId
            : createdByUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        createdByProfileId: freezed == createdByProfileId
            ? _value.createdByProfileId
            : createdByProfileId // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdByRole: freezed == createdByRole
            ? _value.createdByRole
            : createdByRole // ignore: cast_nullable_to_non_nullable
                  as String?,
        listingVisibility: freezed == listingVisibility
            ? _value.listingVisibility
            : listingVisibility // ignore: cast_nullable_to_non_nullable
                  as String?,
        joinPolicy: freezed == joinPolicy
            ? _value.joinPolicy
            : joinPolicy // ignore: cast_nullable_to_non_nullable
                  as String?,
        maxMembers: freezed == maxMembers
            ? _value.maxMembers
            : maxMembers // ignore: cast_nullable_to_non_nullable
                  as int?,
        city: freezed == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String?,
        meta: freezed == meta
            ? _value._meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        searchTsv: freezed == searchTsv
            ? _value.searchTsv
            : searchTsv // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SquadImpl implements _Squad {
  const _$SquadImpl({
    required this.id,
    required this.sport,
    @JsonKey(name: 'owner_profile_id') required this.ownerProfileId,
    @JsonKey(name: 'owner_user_id') required this.ownerUserId,
    required this.name,
    this.bio,
    @JsonKey(name: 'logo_url') this.logoUrl,
    @JsonKey(name: 'is_active') required this.isActive,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
    @JsonKey(name: 'created_by_user_id') required this.createdByUserId,
    @JsonKey(name: 'created_by_profile_id') this.createdByProfileId,
    @JsonKey(name: 'created_by_role') this.createdByRole,
    @JsonKey(name: 'listing_visibility') this.listingVisibility,
    @JsonKey(name: 'join_policy') this.joinPolicy,
    @JsonKey(name: 'max_members') this.maxMembers,
    this.city,
    @JsonKey(fromJson: _metaFromJson, toJson: _metaToJson)
    final Map<String, dynamic>? meta,
    @JsonKey(name: 'search_tsv') this.searchTsv,
  }) : _meta = meta;

  factory _$SquadImpl.fromJson(Map<String, dynamic> json) =>
      _$$SquadImplFromJson(json);

  @override
  final String id;
  @override
  final String sport;
  @override
  @JsonKey(name: 'owner_profile_id')
  final String ownerProfileId;
  @override
  @JsonKey(name: 'owner_user_id')
  final String ownerUserId;
  @override
  final String name;
  @override
  final String? bio;
  @override
  @JsonKey(name: 'logo_url')
  final String? logoUrl;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @override
  @JsonKey(name: 'created_by_user_id')
  final String createdByUserId;
  @override
  @JsonKey(name: 'created_by_profile_id')
  final String? createdByProfileId;
  @override
  @JsonKey(name: 'created_by_role')
  final String? createdByRole;
  @override
  @JsonKey(name: 'listing_visibility')
  final String? listingVisibility;
  @override
  @JsonKey(name: 'join_policy')
  final String? joinPolicy;
  @override
  @JsonKey(name: 'max_members')
  final int? maxMembers;
  @override
  final String? city;
  final Map<String, dynamic>? _meta;
  @override
  @JsonKey(fromJson: _metaFromJson, toJson: _metaToJson)
  Map<String, dynamic>? get meta {
    final value = _meta;
    if (value == null) return null;
    if (_meta is EqualUnmodifiableMapView) return _meta;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'search_tsv')
  final String? searchTsv;

  @override
  String toString() {
    return 'Squad(id: $id, sport: $sport, ownerProfileId: $ownerProfileId, ownerUserId: $ownerUserId, name: $name, bio: $bio, logoUrl: $logoUrl, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, createdByUserId: $createdByUserId, createdByProfileId: $createdByProfileId, createdByRole: $createdByRole, listingVisibility: $listingVisibility, joinPolicy: $joinPolicy, maxMembers: $maxMembers, city: $city, meta: $meta, searchTsv: $searchTsv)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SquadImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sport, sport) || other.sport == sport) &&
            (identical(other.ownerProfileId, ownerProfileId) ||
                other.ownerProfileId == ownerProfileId) &&
            (identical(other.ownerUserId, ownerUserId) ||
                other.ownerUserId == ownerUserId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.bio, bio) || other.bio == bio) &&
            (identical(other.logoUrl, logoUrl) || other.logoUrl == logoUrl) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.createdByUserId, createdByUserId) ||
                other.createdByUserId == createdByUserId) &&
            (identical(other.createdByProfileId, createdByProfileId) ||
                other.createdByProfileId == createdByProfileId) &&
            (identical(other.createdByRole, createdByRole) ||
                other.createdByRole == createdByRole) &&
            (identical(other.listingVisibility, listingVisibility) ||
                other.listingVisibility == listingVisibility) &&
            (identical(other.joinPolicy, joinPolicy) ||
                other.joinPolicy == joinPolicy) &&
            (identical(other.maxMembers, maxMembers) ||
                other.maxMembers == maxMembers) &&
            (identical(other.city, city) || other.city == city) &&
            const DeepCollectionEquality().equals(other._meta, _meta) &&
            (identical(other.searchTsv, searchTsv) ||
                other.searchTsv == searchTsv));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    sport,
    ownerProfileId,
    ownerUserId,
    name,
    bio,
    logoUrl,
    isActive,
    createdAt,
    updatedAt,
    createdByUserId,
    createdByProfileId,
    createdByRole,
    listingVisibility,
    joinPolicy,
    maxMembers,
    city,
    const DeepCollectionEquality().hash(_meta),
    searchTsv,
  ]);

  /// Create a copy of Squad
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SquadImplCopyWith<_$SquadImpl> get copyWith =>
      __$$SquadImplCopyWithImpl<_$SquadImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SquadImplToJson(this);
  }
}

abstract class _Squad implements Squad {
  const factory _Squad({
    required final String id,
    required final String sport,
    @JsonKey(name: 'owner_profile_id') required final String ownerProfileId,
    @JsonKey(name: 'owner_user_id') required final String ownerUserId,
    required final String name,
    final String? bio,
    @JsonKey(name: 'logo_url') final String? logoUrl,
    @JsonKey(name: 'is_active') required final bool isActive,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
    @JsonKey(name: 'created_by_user_id') required final String createdByUserId,
    @JsonKey(name: 'created_by_profile_id') final String? createdByProfileId,
    @JsonKey(name: 'created_by_role') final String? createdByRole,
    @JsonKey(name: 'listing_visibility') final String? listingVisibility,
    @JsonKey(name: 'join_policy') final String? joinPolicy,
    @JsonKey(name: 'max_members') final int? maxMembers,
    final String? city,
    @JsonKey(fromJson: _metaFromJson, toJson: _metaToJson)
    final Map<String, dynamic>? meta,
    @JsonKey(name: 'search_tsv') final String? searchTsv,
  }) = _$SquadImpl;

  factory _Squad.fromJson(Map<String, dynamic> json) = _$SquadImpl.fromJson;

  @override
  String get id;
  @override
  String get sport;
  @override
  @JsonKey(name: 'owner_profile_id')
  String get ownerProfileId;
  @override
  @JsonKey(name: 'owner_user_id')
  String get ownerUserId;
  @override
  String get name;
  @override
  String? get bio;
  @override
  @JsonKey(name: 'logo_url')
  String? get logoUrl;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;
  @override
  @JsonKey(name: 'created_by_user_id')
  String get createdByUserId;
  @override
  @JsonKey(name: 'created_by_profile_id')
  String? get createdByProfileId;
  @override
  @JsonKey(name: 'created_by_role')
  String? get createdByRole;
  @override
  @JsonKey(name: 'listing_visibility')
  String? get listingVisibility;
  @override
  @JsonKey(name: 'join_policy')
  String? get joinPolicy;
  @override
  @JsonKey(name: 'max_members')
  int? get maxMembers;
  @override
  String? get city;
  @override
  @JsonKey(fromJson: _metaFromJson, toJson: _metaToJson)
  Map<String, dynamic>? get meta;
  @override
  @JsonKey(name: 'search_tsv')
  String? get searchTsv;

  /// Create a copy of Squad
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SquadImplCopyWith<_$SquadImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
