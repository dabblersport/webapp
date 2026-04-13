// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'area.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Area _$AreaFromJson(Map<String, dynamic> json) {
  return _Area.fromJson(json);
}

/// @nodoc
mixin _$Area {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get district => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String get country => throw _privateConstructorUsedError;
  @JsonKey(name: 'center_lat')
  double get centerLat => throw _privateConstructorUsedError;
  @JsonKey(name: 'center_lng')
  double get centerLng => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_verified')
  bool get isVerified => throw _privateConstructorUsedError;

  /// Only populated in nearby-query results (from resolve_nearest_area RPC).
  @JsonKey(name: 'distance_m')
  double? get distanceM => throw _privateConstructorUsedError;

  /// Serializes this Area to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Area
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AreaCopyWith<Area> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AreaCopyWith<$Res> {
  factory $AreaCopyWith(Area value, $Res Function(Area) then) =
      _$AreaCopyWithImpl<$Res, Area>;
  @useResult
  $Res call({
    String id,
    String name,
    String district,
    String city,
    String country,
    @JsonKey(name: 'center_lat') double centerLat,
    @JsonKey(name: 'center_lng') double centerLng,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'is_verified') bool isVerified,
    @JsonKey(name: 'distance_m') double? distanceM,
  });
}

/// @nodoc
class _$AreaCopyWithImpl<$Res, $Val extends Area>
    implements $AreaCopyWith<$Res> {
  _$AreaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Area
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? district = null,
    Object? city = null,
    Object? country = null,
    Object? centerLat = null,
    Object? centerLng = null,
    Object? isActive = null,
    Object? isVerified = null,
    Object? distanceM = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            district: null == district
                ? _value.district
                : district // ignore: cast_nullable_to_non_nullable
                      as String,
            city: null == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String,
            country: null == country
                ? _value.country
                : country // ignore: cast_nullable_to_non_nullable
                      as String,
            centerLat: null == centerLat
                ? _value.centerLat
                : centerLat // ignore: cast_nullable_to_non_nullable
                      as double,
            centerLng: null == centerLng
                ? _value.centerLng
                : centerLng // ignore: cast_nullable_to_non_nullable
                      as double,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            isVerified: null == isVerified
                ? _value.isVerified
                : isVerified // ignore: cast_nullable_to_non_nullable
                      as bool,
            distanceM: freezed == distanceM
                ? _value.distanceM
                : distanceM // ignore: cast_nullable_to_non_nullable
                      as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AreaImplCopyWith<$Res> implements $AreaCopyWith<$Res> {
  factory _$$AreaImplCopyWith(
    _$AreaImpl value,
    $Res Function(_$AreaImpl) then,
  ) = __$$AreaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String district,
    String city,
    String country,
    @JsonKey(name: 'center_lat') double centerLat,
    @JsonKey(name: 'center_lng') double centerLng,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'is_verified') bool isVerified,
    @JsonKey(name: 'distance_m') double? distanceM,
  });
}

/// @nodoc
class __$$AreaImplCopyWithImpl<$Res>
    extends _$AreaCopyWithImpl<$Res, _$AreaImpl>
    implements _$$AreaImplCopyWith<$Res> {
  __$$AreaImplCopyWithImpl(_$AreaImpl _value, $Res Function(_$AreaImpl) _then)
    : super(_value, _then);

  /// Create a copy of Area
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? district = null,
    Object? city = null,
    Object? country = null,
    Object? centerLat = null,
    Object? centerLng = null,
    Object? isActive = null,
    Object? isVerified = null,
    Object? distanceM = freezed,
  }) {
    return _then(
      _$AreaImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        district: null == district
            ? _value.district
            : district // ignore: cast_nullable_to_non_nullable
                  as String,
        city: null == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String,
        country: null == country
            ? _value.country
            : country // ignore: cast_nullable_to_non_nullable
                  as String,
        centerLat: null == centerLat
            ? _value.centerLat
            : centerLat // ignore: cast_nullable_to_non_nullable
                  as double,
        centerLng: null == centerLng
            ? _value.centerLng
            : centerLng // ignore: cast_nullable_to_non_nullable
                  as double,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        isVerified: null == isVerified
            ? _value.isVerified
            : isVerified // ignore: cast_nullable_to_non_nullable
                  as bool,
        distanceM: freezed == distanceM
            ? _value.distanceM
            : distanceM // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AreaImpl implements _Area {
  const _$AreaImpl({
    required this.id,
    required this.name,
    required this.district,
    required this.city,
    required this.country,
    @JsonKey(name: 'center_lat') required this.centerLat,
    @JsonKey(name: 'center_lng') required this.centerLng,
    @JsonKey(name: 'is_active') this.isActive = true,
    @JsonKey(name: 'is_verified') this.isVerified = false,
    @JsonKey(name: 'distance_m') this.distanceM,
  });

  factory _$AreaImpl.fromJson(Map<String, dynamic> json) =>
      _$$AreaImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String district;
  @override
  final String city;
  @override
  final String country;
  @override
  @JsonKey(name: 'center_lat')
  final double centerLat;
  @override
  @JsonKey(name: 'center_lng')
  final double centerLng;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'is_verified')
  final bool isVerified;

  /// Only populated in nearby-query results (from resolve_nearest_area RPC).
  @override
  @JsonKey(name: 'distance_m')
  final double? distanceM;

  @override
  String toString() {
    return 'Area(id: $id, name: $name, district: $district, city: $city, country: $country, centerLat: $centerLat, centerLng: $centerLng, isActive: $isActive, isVerified: $isVerified, distanceM: $distanceM)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AreaImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.district, district) ||
                other.district == district) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.centerLat, centerLat) ||
                other.centerLat == centerLat) &&
            (identical(other.centerLng, centerLng) ||
                other.centerLng == centerLng) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.distanceM, distanceM) ||
                other.distanceM == distanceM));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    district,
    city,
    country,
    centerLat,
    centerLng,
    isActive,
    isVerified,
    distanceM,
  );

  /// Create a copy of Area
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AreaImplCopyWith<_$AreaImpl> get copyWith =>
      __$$AreaImplCopyWithImpl<_$AreaImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AreaImplToJson(this);
  }
}

abstract class _Area implements Area {
  const factory _Area({
    required final String id,
    required final String name,
    required final String district,
    required final String city,
    required final String country,
    @JsonKey(name: 'center_lat') required final double centerLat,
    @JsonKey(name: 'center_lng') required final double centerLng,
    @JsonKey(name: 'is_active') final bool isActive,
    @JsonKey(name: 'is_verified') final bool isVerified,
    @JsonKey(name: 'distance_m') final double? distanceM,
  }) = _$AreaImpl;

  factory _Area.fromJson(Map<String, dynamic> json) = _$AreaImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get district;
  @override
  String get city;
  @override
  String get country;
  @override
  @JsonKey(name: 'center_lat')
  double get centerLat;
  @override
  @JsonKey(name: 'center_lng')
  double get centerLng;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'is_verified')
  bool get isVerified;

  /// Only populated in nearby-query results (from resolve_nearest_area RPC).
  @override
  @JsonKey(name: 'distance_m')
  double? get distanceM;

  /// Create a copy of Area
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AreaImplCopyWith<_$AreaImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
