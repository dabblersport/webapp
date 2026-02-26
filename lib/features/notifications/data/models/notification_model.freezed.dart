// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) {
  return _AppNotification.fromJson(json);
}

/// @nodoc
mixin _$AppNotification {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'to_user_id')
  String get toUserId => throw _privateConstructorUsedError;
  @JsonKey(name: 'kind_key')
  String get kindKey => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get body => throw _privateConstructorUsedError;
  @JsonKey(name: 'action_route')
  String? get actionRoute => throw _privateConstructorUsedError;

  /// Arbitrary JSONB payload from the DB (e.g. actor info, post id, etc.)
  @JsonKey(name: 'context')
  Map<String, dynamic>? get payload => throw _privateConstructorUsedError;
  NotifyPriority get priority => throw _privateConstructorUsedError;
  @JsonKey(name: 'ai_score')
  double? get aiScore => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_read')
  bool get isRead => throw _privateConstructorUsedError;
  @JsonKey(name: 'read_at')
  DateTime? get readAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'clicked_at')
  DateTime? get clickedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'interaction_count')
  int get interactionCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this AppNotification to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppNotificationCopyWith<AppNotification> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppNotificationCopyWith<$Res> {
  factory $AppNotificationCopyWith(
    AppNotification value,
    $Res Function(AppNotification) then,
  ) = _$AppNotificationCopyWithImpl<$Res, AppNotification>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'to_user_id') String toUserId,
    @JsonKey(name: 'kind_key') String kindKey,
    String title,
    String? body,
    @JsonKey(name: 'action_route') String? actionRoute,
    @JsonKey(name: 'context') Map<String, dynamic>? payload,
    NotifyPriority priority,
    @JsonKey(name: 'ai_score') double? aiScore,
    @JsonKey(name: 'is_read') bool isRead,
    @JsonKey(name: 'read_at') DateTime? readAt,
    @JsonKey(name: 'clicked_at') DateTime? clickedAt,
    @JsonKey(name: 'interaction_count') int interactionCount,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class _$AppNotificationCopyWithImpl<$Res, $Val extends AppNotification>
    implements $AppNotificationCopyWith<$Res> {
  _$AppNotificationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? toUserId = null,
    Object? kindKey = null,
    Object? title = null,
    Object? body = freezed,
    Object? actionRoute = freezed,
    Object? payload = freezed,
    Object? priority = null,
    Object? aiScore = freezed,
    Object? isRead = null,
    Object? readAt = freezed,
    Object? clickedAt = freezed,
    Object? interactionCount = null,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            toUserId: null == toUserId
                ? _value.toUserId
                : toUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            kindKey: null == kindKey
                ? _value.kindKey
                : kindKey // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            body: freezed == body
                ? _value.body
                : body // ignore: cast_nullable_to_non_nullable
                      as String?,
            actionRoute: freezed == actionRoute
                ? _value.actionRoute
                : actionRoute // ignore: cast_nullable_to_non_nullable
                      as String?,
            payload: freezed == payload
                ? _value.payload
                : payload // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            priority: null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                      as NotifyPriority,
            aiScore: freezed == aiScore
                ? _value.aiScore
                : aiScore // ignore: cast_nullable_to_non_nullable
                      as double?,
            isRead: null == isRead
                ? _value.isRead
                : isRead // ignore: cast_nullable_to_non_nullable
                      as bool,
            readAt: freezed == readAt
                ? _value.readAt
                : readAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            clickedAt: freezed == clickedAt
                ? _value.clickedAt
                : clickedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            interactionCount: null == interactionCount
                ? _value.interactionCount
                : interactionCount // ignore: cast_nullable_to_non_nullable
                      as int,
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
abstract class _$$AppNotificationImplCopyWith<$Res>
    implements $AppNotificationCopyWith<$Res> {
  factory _$$AppNotificationImplCopyWith(
    _$AppNotificationImpl value,
    $Res Function(_$AppNotificationImpl) then,
  ) = __$$AppNotificationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'to_user_id') String toUserId,
    @JsonKey(name: 'kind_key') String kindKey,
    String title,
    String? body,
    @JsonKey(name: 'action_route') String? actionRoute,
    @JsonKey(name: 'context') Map<String, dynamic>? payload,
    NotifyPriority priority,
    @JsonKey(name: 'ai_score') double? aiScore,
    @JsonKey(name: 'is_read') bool isRead,
    @JsonKey(name: 'read_at') DateTime? readAt,
    @JsonKey(name: 'clicked_at') DateTime? clickedAt,
    @JsonKey(name: 'interaction_count') int interactionCount,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class __$$AppNotificationImplCopyWithImpl<$Res>
    extends _$AppNotificationCopyWithImpl<$Res, _$AppNotificationImpl>
    implements _$$AppNotificationImplCopyWith<$Res> {
  __$$AppNotificationImplCopyWithImpl(
    _$AppNotificationImpl _value,
    $Res Function(_$AppNotificationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? toUserId = null,
    Object? kindKey = null,
    Object? title = null,
    Object? body = freezed,
    Object? actionRoute = freezed,
    Object? payload = freezed,
    Object? priority = null,
    Object? aiScore = freezed,
    Object? isRead = null,
    Object? readAt = freezed,
    Object? clickedAt = freezed,
    Object? interactionCount = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$AppNotificationImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        toUserId: null == toUserId
            ? _value.toUserId
            : toUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        kindKey: null == kindKey
            ? _value.kindKey
            : kindKey // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        body: freezed == body
            ? _value.body
            : body // ignore: cast_nullable_to_non_nullable
                  as String?,
        actionRoute: freezed == actionRoute
            ? _value.actionRoute
            : actionRoute // ignore: cast_nullable_to_non_nullable
                  as String?,
        payload: freezed == payload
            ? _value._payload
            : payload // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        priority: null == priority
            ? _value.priority
            : priority // ignore: cast_nullable_to_non_nullable
                  as NotifyPriority,
        aiScore: freezed == aiScore
            ? _value.aiScore
            : aiScore // ignore: cast_nullable_to_non_nullable
                  as double?,
        isRead: null == isRead
            ? _value.isRead
            : isRead // ignore: cast_nullable_to_non_nullable
                  as bool,
        readAt: freezed == readAt
            ? _value.readAt
            : readAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        clickedAt: freezed == clickedAt
            ? _value.clickedAt
            : clickedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        interactionCount: null == interactionCount
            ? _value.interactionCount
            : interactionCount // ignore: cast_nullable_to_non_nullable
                  as int,
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
class _$AppNotificationImpl extends _AppNotification {
  const _$AppNotificationImpl({
    required this.id,
    @JsonKey(name: 'to_user_id') required this.toUserId,
    @JsonKey(name: 'kind_key') required this.kindKey,
    required this.title,
    this.body,
    @JsonKey(name: 'action_route') this.actionRoute,
    @JsonKey(name: 'context') final Map<String, dynamic>? payload,
    this.priority = NotifyPriority.normal,
    @JsonKey(name: 'ai_score') this.aiScore,
    @JsonKey(name: 'is_read') this.isRead = false,
    @JsonKey(name: 'read_at') this.readAt,
    @JsonKey(name: 'clicked_at') this.clickedAt,
    @JsonKey(name: 'interaction_count') this.interactionCount = 0,
    @JsonKey(name: 'created_at') required this.createdAt,
  }) : _payload = payload,
       super._();

  factory _$AppNotificationImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppNotificationImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'to_user_id')
  final String toUserId;
  @override
  @JsonKey(name: 'kind_key')
  final String kindKey;
  @override
  final String title;
  @override
  final String? body;
  @override
  @JsonKey(name: 'action_route')
  final String? actionRoute;

  /// Arbitrary JSONB payload from the DB (e.g. actor info, post id, etc.)
  final Map<String, dynamic>? _payload;

  /// Arbitrary JSONB payload from the DB (e.g. actor info, post id, etc.)
  @override
  @JsonKey(name: 'context')
  Map<String, dynamic>? get payload {
    final value = _payload;
    if (value == null) return null;
    if (_payload is EqualUnmodifiableMapView) return _payload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey()
  final NotifyPriority priority;
  @override
  @JsonKey(name: 'ai_score')
  final double? aiScore;
  @override
  @JsonKey(name: 'is_read')
  final bool isRead;
  @override
  @JsonKey(name: 'read_at')
  final DateTime? readAt;
  @override
  @JsonKey(name: 'clicked_at')
  final DateTime? clickedAt;
  @override
  @JsonKey(name: 'interaction_count')
  final int interactionCount;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @override
  String toString() {
    return 'AppNotification(id: $id, toUserId: $toUserId, kindKey: $kindKey, title: $title, body: $body, actionRoute: $actionRoute, payload: $payload, priority: $priority, aiScore: $aiScore, isRead: $isRead, readAt: $readAt, clickedAt: $clickedAt, interactionCount: $interactionCount, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppNotificationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.toUserId, toUserId) ||
                other.toUserId == toUserId) &&
            (identical(other.kindKey, kindKey) || other.kindKey == kindKey) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.actionRoute, actionRoute) ||
                other.actionRoute == actionRoute) &&
            const DeepCollectionEquality().equals(other._payload, _payload) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.aiScore, aiScore) || other.aiScore == aiScore) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            (identical(other.readAt, readAt) || other.readAt == readAt) &&
            (identical(other.clickedAt, clickedAt) ||
                other.clickedAt == clickedAt) &&
            (identical(other.interactionCount, interactionCount) ||
                other.interactionCount == interactionCount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    toUserId,
    kindKey,
    title,
    body,
    actionRoute,
    const DeepCollectionEquality().hash(_payload),
    priority,
    aiScore,
    isRead,
    readAt,
    clickedAt,
    interactionCount,
    createdAt,
  );

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppNotificationImplCopyWith<_$AppNotificationImpl> get copyWith =>
      __$$AppNotificationImplCopyWithImpl<_$AppNotificationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AppNotificationImplToJson(this);
  }
}

abstract class _AppNotification extends AppNotification {
  const factory _AppNotification({
    required final String id,
    @JsonKey(name: 'to_user_id') required final String toUserId,
    @JsonKey(name: 'kind_key') required final String kindKey,
    required final String title,
    final String? body,
    @JsonKey(name: 'action_route') final String? actionRoute,
    @JsonKey(name: 'context') final Map<String, dynamic>? payload,
    final NotifyPriority priority,
    @JsonKey(name: 'ai_score') final double? aiScore,
    @JsonKey(name: 'is_read') final bool isRead,
    @JsonKey(name: 'read_at') final DateTime? readAt,
    @JsonKey(name: 'clicked_at') final DateTime? clickedAt,
    @JsonKey(name: 'interaction_count') final int interactionCount,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
  }) = _$AppNotificationImpl;
  const _AppNotification._() : super._();

  factory _AppNotification.fromJson(Map<String, dynamic> json) =
      _$AppNotificationImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'to_user_id')
  String get toUserId;
  @override
  @JsonKey(name: 'kind_key')
  String get kindKey;
  @override
  String get title;
  @override
  String? get body;
  @override
  @JsonKey(name: 'action_route')
  String? get actionRoute;

  /// Arbitrary JSONB payload from the DB (e.g. actor info, post id, etc.)
  @override
  @JsonKey(name: 'context')
  Map<String, dynamic>? get payload;
  @override
  NotifyPriority get priority;
  @override
  @JsonKey(name: 'ai_score')
  double? get aiScore;
  @override
  @JsonKey(name: 'is_read')
  bool get isRead;
  @override
  @JsonKey(name: 'read_at')
  DateTime? get readAt;
  @override
  @JsonKey(name: 'clicked_at')
  DateTime? get clickedAt;
  @override
  @JsonKey(name: 'interaction_count')
  int get interactionCount;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppNotificationImplCopyWith<_$AppNotificationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
