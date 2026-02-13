// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Game _$GameFromJson(Map<String, dynamic> json) {
  return _Game.fromJson(json);
}

/// @nodoc
mixin _$Game {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'game_type')
  String get gameType => throw _privateConstructorUsedError;
  String get sport => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;
  @JsonKey(name: 'host_profile_id')
  String get hostProfileId => throw _privateConstructorUsedError;
  @JsonKey(name: 'host_user_id')
  String get hostUserId => throw _privateConstructorUsedError;
  @JsonKey(name: 'venue_space_id')
  String? get venueSpaceId => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_at')
  DateTime get startAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_at')
  DateTime get endAt => throw _privateConstructorUsedError;
  int get capacity => throw _privateConstructorUsedError;
  @JsonKey(name: 'listing_visibility')
  String get listingVisibility => throw _privateConstructorUsedError;
  @JsonKey(name: 'join_policy')
  String get joinPolicy => throw _privateConstructorUsedError;
  @JsonKey(name: 'allow_spectators')
  bool get allowSpectators => throw _privateConstructorUsedError;
  @JsonKey(name: 'min_skill')
  int? get minSkill => throw _privateConstructorUsedError;
  @JsonKey(name: 'max_skill')
  int? get maxSkill => throw _privateConstructorUsedError;
  @JsonKey(name: 'rules', defaultValue: <String, dynamic>{})
  Map<String, dynamic> get rules => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_cancelled')
  bool get isCancelled => throw _privateConstructorUsedError;
  @JsonKey(name: 'cancelled_at')
  DateTime? get cancelledAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'cancelled_reason')
  String? get cancelledReason => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'squad_id')
  String? get squadId => throw _privateConstructorUsedError;
  @JsonKey(name: 'search_tsv')
  String? get searchTsv => throw _privateConstructorUsedError;

  /// Serializes this Game to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GameCopyWith<Game> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GameCopyWith<$Res> {
  factory $GameCopyWith(Game value, $Res Function(Game) then) =
      _$GameCopyWithImpl<$Res, Game>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'game_type') String gameType,
    String sport,
    String? title,
    @JsonKey(name: 'host_profile_id') String hostProfileId,
    @JsonKey(name: 'host_user_id') String hostUserId,
    @JsonKey(name: 'venue_space_id') String? venueSpaceId,
    @JsonKey(name: 'start_at') DateTime startAt,
    @JsonKey(name: 'end_at') DateTime endAt,
    int capacity,
    @JsonKey(name: 'listing_visibility') String listingVisibility,
    @JsonKey(name: 'join_policy') String joinPolicy,
    @JsonKey(name: 'allow_spectators') bool allowSpectators,
    @JsonKey(name: 'min_skill') int? minSkill,
    @JsonKey(name: 'max_skill') int? maxSkill,
    @JsonKey(name: 'rules', defaultValue: <String, dynamic>{})
    Map<String, dynamic> rules,
    @JsonKey(name: 'is_cancelled') bool isCancelled,
    @JsonKey(name: 'cancelled_at') DateTime? cancelledAt,
    @JsonKey(name: 'cancelled_reason') String? cancelledReason,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    @JsonKey(name: 'squad_id') String? squadId,
    @JsonKey(name: 'search_tsv') String? searchTsv,
  });
}

/// @nodoc
class _$GameCopyWithImpl<$Res, $Val extends Game>
    implements $GameCopyWith<$Res> {
  _$GameCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gameType = null,
    Object? sport = null,
    Object? title = freezed,
    Object? hostProfileId = null,
    Object? hostUserId = null,
    Object? venueSpaceId = freezed,
    Object? startAt = null,
    Object? endAt = null,
    Object? capacity = null,
    Object? listingVisibility = null,
    Object? joinPolicy = null,
    Object? allowSpectators = null,
    Object? minSkill = freezed,
    Object? maxSkill = freezed,
    Object? rules = null,
    Object? isCancelled = null,
    Object? cancelledAt = freezed,
    Object? cancelledReason = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? squadId = freezed,
    Object? searchTsv = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            gameType: null == gameType
                ? _value.gameType
                : gameType // ignore: cast_nullable_to_non_nullable
                      as String,
            sport: null == sport
                ? _value.sport
                : sport // ignore: cast_nullable_to_non_nullable
                      as String,
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            hostProfileId: null == hostProfileId
                ? _value.hostProfileId
                : hostProfileId // ignore: cast_nullable_to_non_nullable
                      as String,
            hostUserId: null == hostUserId
                ? _value.hostUserId
                : hostUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            venueSpaceId: freezed == venueSpaceId
                ? _value.venueSpaceId
                : venueSpaceId // ignore: cast_nullable_to_non_nullable
                      as String?,
            startAt: null == startAt
                ? _value.startAt
                : startAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endAt: null == endAt
                ? _value.endAt
                : endAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            capacity: null == capacity
                ? _value.capacity
                : capacity // ignore: cast_nullable_to_non_nullable
                      as int,
            listingVisibility: null == listingVisibility
                ? _value.listingVisibility
                : listingVisibility // ignore: cast_nullable_to_non_nullable
                      as String,
            joinPolicy: null == joinPolicy
                ? _value.joinPolicy
                : joinPolicy // ignore: cast_nullable_to_non_nullable
                      as String,
            allowSpectators: null == allowSpectators
                ? _value.allowSpectators
                : allowSpectators // ignore: cast_nullable_to_non_nullable
                      as bool,
            minSkill: freezed == minSkill
                ? _value.minSkill
                : minSkill // ignore: cast_nullable_to_non_nullable
                      as int?,
            maxSkill: freezed == maxSkill
                ? _value.maxSkill
                : maxSkill // ignore: cast_nullable_to_non_nullable
                      as int?,
            rules: null == rules
                ? _value.rules
                : rules // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            isCancelled: null == isCancelled
                ? _value.isCancelled
                : isCancelled // ignore: cast_nullable_to_non_nullable
                      as bool,
            cancelledAt: freezed == cancelledAt
                ? _value.cancelledAt
                : cancelledAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            cancelledReason: freezed == cancelledReason
                ? _value.cancelledReason
                : cancelledReason // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            squadId: freezed == squadId
                ? _value.squadId
                : squadId // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$GameImplCopyWith<$Res> implements $GameCopyWith<$Res> {
  factory _$$GameImplCopyWith(
    _$GameImpl value,
    $Res Function(_$GameImpl) then,
  ) = __$$GameImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'game_type') String gameType,
    String sport,
    String? title,
    @JsonKey(name: 'host_profile_id') String hostProfileId,
    @JsonKey(name: 'host_user_id') String hostUserId,
    @JsonKey(name: 'venue_space_id') String? venueSpaceId,
    @JsonKey(name: 'start_at') DateTime startAt,
    @JsonKey(name: 'end_at') DateTime endAt,
    int capacity,
    @JsonKey(name: 'listing_visibility') String listingVisibility,
    @JsonKey(name: 'join_policy') String joinPolicy,
    @JsonKey(name: 'allow_spectators') bool allowSpectators,
    @JsonKey(name: 'min_skill') int? minSkill,
    @JsonKey(name: 'max_skill') int? maxSkill,
    @JsonKey(name: 'rules', defaultValue: <String, dynamic>{})
    Map<String, dynamic> rules,
    @JsonKey(name: 'is_cancelled') bool isCancelled,
    @JsonKey(name: 'cancelled_at') DateTime? cancelledAt,
    @JsonKey(name: 'cancelled_reason') String? cancelledReason,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    @JsonKey(name: 'squad_id') String? squadId,
    @JsonKey(name: 'search_tsv') String? searchTsv,
  });
}

/// @nodoc
class __$$GameImplCopyWithImpl<$Res>
    extends _$GameCopyWithImpl<$Res, _$GameImpl>
    implements _$$GameImplCopyWith<$Res> {
  __$$GameImplCopyWithImpl(_$GameImpl _value, $Res Function(_$GameImpl) _then)
    : super(_value, _then);

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? gameType = null,
    Object? sport = null,
    Object? title = freezed,
    Object? hostProfileId = null,
    Object? hostUserId = null,
    Object? venueSpaceId = freezed,
    Object? startAt = null,
    Object? endAt = null,
    Object? capacity = null,
    Object? listingVisibility = null,
    Object? joinPolicy = null,
    Object? allowSpectators = null,
    Object? minSkill = freezed,
    Object? maxSkill = freezed,
    Object? rules = null,
    Object? isCancelled = null,
    Object? cancelledAt = freezed,
    Object? cancelledReason = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? squadId = freezed,
    Object? searchTsv = freezed,
  }) {
    return _then(
      _$GameImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        gameType: null == gameType
            ? _value.gameType
            : gameType // ignore: cast_nullable_to_non_nullable
                  as String,
        sport: null == sport
            ? _value.sport
            : sport // ignore: cast_nullable_to_non_nullable
                  as String,
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        hostProfileId: null == hostProfileId
            ? _value.hostProfileId
            : hostProfileId // ignore: cast_nullable_to_non_nullable
                  as String,
        hostUserId: null == hostUserId
            ? _value.hostUserId
            : hostUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        venueSpaceId: freezed == venueSpaceId
            ? _value.venueSpaceId
            : venueSpaceId // ignore: cast_nullable_to_non_nullable
                  as String?,
        startAt: null == startAt
            ? _value.startAt
            : startAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endAt: null == endAt
            ? _value.endAt
            : endAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        capacity: null == capacity
            ? _value.capacity
            : capacity // ignore: cast_nullable_to_non_nullable
                  as int,
        listingVisibility: null == listingVisibility
            ? _value.listingVisibility
            : listingVisibility // ignore: cast_nullable_to_non_nullable
                  as String,
        joinPolicy: null == joinPolicy
            ? _value.joinPolicy
            : joinPolicy // ignore: cast_nullable_to_non_nullable
                  as String,
        allowSpectators: null == allowSpectators
            ? _value.allowSpectators
            : allowSpectators // ignore: cast_nullable_to_non_nullable
                  as bool,
        minSkill: freezed == minSkill
            ? _value.minSkill
            : minSkill // ignore: cast_nullable_to_non_nullable
                  as int?,
        maxSkill: freezed == maxSkill
            ? _value.maxSkill
            : maxSkill // ignore: cast_nullable_to_non_nullable
                  as int?,
        rules: null == rules
            ? _value._rules
            : rules // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        isCancelled: null == isCancelled
            ? _value.isCancelled
            : isCancelled // ignore: cast_nullable_to_non_nullable
                  as bool,
        cancelledAt: freezed == cancelledAt
            ? _value.cancelledAt
            : cancelledAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        cancelledReason: freezed == cancelledReason
            ? _value.cancelledReason
            : cancelledReason // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        squadId: freezed == squadId
            ? _value.squadId
            : squadId // ignore: cast_nullable_to_non_nullable
                  as String?,
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
class _$GameImpl implements _Game {
  const _$GameImpl({
    required this.id,
    @JsonKey(name: 'game_type') required this.gameType,
    required this.sport,
    this.title,
    @JsonKey(name: 'host_profile_id') required this.hostProfileId,
    @JsonKey(name: 'host_user_id') required this.hostUserId,
    @JsonKey(name: 'venue_space_id') this.venueSpaceId,
    @JsonKey(name: 'start_at') required this.startAt,
    @JsonKey(name: 'end_at') required this.endAt,
    required this.capacity,
    @JsonKey(name: 'listing_visibility') required this.listingVisibility,
    @JsonKey(name: 'join_policy') required this.joinPolicy,
    @JsonKey(name: 'allow_spectators') required this.allowSpectators,
    @JsonKey(name: 'min_skill') this.minSkill,
    @JsonKey(name: 'max_skill') this.maxSkill,
    @JsonKey(name: 'rules', defaultValue: <String, dynamic>{})
    required final Map<String, dynamic> rules,
    @JsonKey(name: 'is_cancelled') required this.isCancelled,
    @JsonKey(name: 'cancelled_at') this.cancelledAt,
    @JsonKey(name: 'cancelled_reason') this.cancelledReason,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
    @JsonKey(name: 'squad_id') this.squadId,
    @JsonKey(name: 'search_tsv') this.searchTsv,
  }) : _rules = rules;

  factory _$GameImpl.fromJson(Map<String, dynamic> json) =>
      _$$GameImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'game_type')
  final String gameType;
  @override
  final String sport;
  @override
  final String? title;
  @override
  @JsonKey(name: 'host_profile_id')
  final String hostProfileId;
  @override
  @JsonKey(name: 'host_user_id')
  final String hostUserId;
  @override
  @JsonKey(name: 'venue_space_id')
  final String? venueSpaceId;
  @override
  @JsonKey(name: 'start_at')
  final DateTime startAt;
  @override
  @JsonKey(name: 'end_at')
  final DateTime endAt;
  @override
  final int capacity;
  @override
  @JsonKey(name: 'listing_visibility')
  final String listingVisibility;
  @override
  @JsonKey(name: 'join_policy')
  final String joinPolicy;
  @override
  @JsonKey(name: 'allow_spectators')
  final bool allowSpectators;
  @override
  @JsonKey(name: 'min_skill')
  final int? minSkill;
  @override
  @JsonKey(name: 'max_skill')
  final int? maxSkill;
  final Map<String, dynamic> _rules;
  @override
  @JsonKey(name: 'rules', defaultValue: <String, dynamic>{})
  Map<String, dynamic> get rules {
    if (_rules is EqualUnmodifiableMapView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_rules);
  }

  @override
  @JsonKey(name: 'is_cancelled')
  final bool isCancelled;
  @override
  @JsonKey(name: 'cancelled_at')
  final DateTime? cancelledAt;
  @override
  @JsonKey(name: 'cancelled_reason')
  final String? cancelledReason;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @override
  @JsonKey(name: 'squad_id')
  final String? squadId;
  @override
  @JsonKey(name: 'search_tsv')
  final String? searchTsv;

  @override
  String toString() {
    return 'Game(id: $id, gameType: $gameType, sport: $sport, title: $title, hostProfileId: $hostProfileId, hostUserId: $hostUserId, venueSpaceId: $venueSpaceId, startAt: $startAt, endAt: $endAt, capacity: $capacity, listingVisibility: $listingVisibility, joinPolicy: $joinPolicy, allowSpectators: $allowSpectators, minSkill: $minSkill, maxSkill: $maxSkill, rules: $rules, isCancelled: $isCancelled, cancelledAt: $cancelledAt, cancelledReason: $cancelledReason, createdAt: $createdAt, updatedAt: $updatedAt, squadId: $squadId, searchTsv: $searchTsv)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GameImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.gameType, gameType) ||
                other.gameType == gameType) &&
            (identical(other.sport, sport) || other.sport == sport) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.hostProfileId, hostProfileId) ||
                other.hostProfileId == hostProfileId) &&
            (identical(other.hostUserId, hostUserId) ||
                other.hostUserId == hostUserId) &&
            (identical(other.venueSpaceId, venueSpaceId) ||
                other.venueSpaceId == venueSpaceId) &&
            (identical(other.startAt, startAt) || other.startAt == startAt) &&
            (identical(other.endAt, endAt) || other.endAt == endAt) &&
            (identical(other.capacity, capacity) ||
                other.capacity == capacity) &&
            (identical(other.listingVisibility, listingVisibility) ||
                other.listingVisibility == listingVisibility) &&
            (identical(other.joinPolicy, joinPolicy) ||
                other.joinPolicy == joinPolicy) &&
            (identical(other.allowSpectators, allowSpectators) ||
                other.allowSpectators == allowSpectators) &&
            (identical(other.minSkill, minSkill) ||
                other.minSkill == minSkill) &&
            (identical(other.maxSkill, maxSkill) ||
                other.maxSkill == maxSkill) &&
            const DeepCollectionEquality().equals(other._rules, _rules) &&
            (identical(other.isCancelled, isCancelled) ||
                other.isCancelled == isCancelled) &&
            (identical(other.cancelledAt, cancelledAt) ||
                other.cancelledAt == cancelledAt) &&
            (identical(other.cancelledReason, cancelledReason) ||
                other.cancelledReason == cancelledReason) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.squadId, squadId) || other.squadId == squadId) &&
            (identical(other.searchTsv, searchTsv) ||
                other.searchTsv == searchTsv));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    gameType,
    sport,
    title,
    hostProfileId,
    hostUserId,
    venueSpaceId,
    startAt,
    endAt,
    capacity,
    listingVisibility,
    joinPolicy,
    allowSpectators,
    minSkill,
    maxSkill,
    const DeepCollectionEquality().hash(_rules),
    isCancelled,
    cancelledAt,
    cancelledReason,
    createdAt,
    updatedAt,
    squadId,
    searchTsv,
  ]);

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GameImplCopyWith<_$GameImpl> get copyWith =>
      __$$GameImplCopyWithImpl<_$GameImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GameImplToJson(this);
  }
}

abstract class _Game implements Game {
  const factory _Game({
    required final String id,
    @JsonKey(name: 'game_type') required final String gameType,
    required final String sport,
    final String? title,
    @JsonKey(name: 'host_profile_id') required final String hostProfileId,
    @JsonKey(name: 'host_user_id') required final String hostUserId,
    @JsonKey(name: 'venue_space_id') final String? venueSpaceId,
    @JsonKey(name: 'start_at') required final DateTime startAt,
    @JsonKey(name: 'end_at') required final DateTime endAt,
    required final int capacity,
    @JsonKey(name: 'listing_visibility')
    required final String listingVisibility,
    @JsonKey(name: 'join_policy') required final String joinPolicy,
    @JsonKey(name: 'allow_spectators') required final bool allowSpectators,
    @JsonKey(name: 'min_skill') final int? minSkill,
    @JsonKey(name: 'max_skill') final int? maxSkill,
    @JsonKey(name: 'rules', defaultValue: <String, dynamic>{})
    required final Map<String, dynamic> rules,
    @JsonKey(name: 'is_cancelled') required final bool isCancelled,
    @JsonKey(name: 'cancelled_at') final DateTime? cancelledAt,
    @JsonKey(name: 'cancelled_reason') final String? cancelledReason,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
    @JsonKey(name: 'squad_id') final String? squadId,
    @JsonKey(name: 'search_tsv') final String? searchTsv,
  }) = _$GameImpl;

  factory _Game.fromJson(Map<String, dynamic> json) = _$GameImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'game_type')
  String get gameType;
  @override
  String get sport;
  @override
  String? get title;
  @override
  @JsonKey(name: 'host_profile_id')
  String get hostProfileId;
  @override
  @JsonKey(name: 'host_user_id')
  String get hostUserId;
  @override
  @JsonKey(name: 'venue_space_id')
  String? get venueSpaceId;
  @override
  @JsonKey(name: 'start_at')
  DateTime get startAt;
  @override
  @JsonKey(name: 'end_at')
  DateTime get endAt;
  @override
  int get capacity;
  @override
  @JsonKey(name: 'listing_visibility')
  String get listingVisibility;
  @override
  @JsonKey(name: 'join_policy')
  String get joinPolicy;
  @override
  @JsonKey(name: 'allow_spectators')
  bool get allowSpectators;
  @override
  @JsonKey(name: 'min_skill')
  int? get minSkill;
  @override
  @JsonKey(name: 'max_skill')
  int? get maxSkill;
  @override
  @JsonKey(name: 'rules', defaultValue: <String, dynamic>{})
  Map<String, dynamic> get rules;
  @override
  @JsonKey(name: 'is_cancelled')
  bool get isCancelled;
  @override
  @JsonKey(name: 'cancelled_at')
  DateTime? get cancelledAt;
  @override
  @JsonKey(name: 'cancelled_reason')
  String? get cancelledReason;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;
  @override
  @JsonKey(name: 'squad_id')
  String? get squadId;
  @override
  @JsonKey(name: 'search_tsv')
  String? get searchTsv;

  /// Create a copy of Game
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GameImplCopyWith<_$GameImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
