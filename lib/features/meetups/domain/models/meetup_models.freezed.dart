// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meetup_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MeetupListItem _$MeetupListItemFromJson(Map<String, dynamic> json) {
  return _MeetupListItem.fromJson(json);
}

/// @nodoc
mixin _$MeetupListItem {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_at')
  DateTime get startAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_at')
  DateTime? get endAt => throw _privateConstructorUsedError;
  int? get capacity => throw _privateConstructorUsedError;
  @JsonKey(name: 'members_only')
  bool get membersOnly => throw _privateConstructorUsedError;
  @JsonKey(name: 'listing_visibility')
  String get listingVisibility => throw _privateConstructorUsedError;
  @JsonKey(name: 'rsvp_policy', unknownEnumValue: RsvpPolicy.closed)
  RsvpPolicy get rsvpPolicy => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_cancelled')
  bool get isCancelled => throw _privateConstructorUsedError;
  @JsonKey(name: 'vibe_key')
  String? get vibeKey => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'creator_profile_id')
  String? get creatorProfileId => throw _privateConstructorUsedError;
  @JsonKey(name: 'creator_display_name')
  String? get creatorDisplayName => throw _privateConstructorUsedError;
  @JsonKey(name: 'creator_username')
  String? get creatorUsername => throw _privateConstructorUsedError;
  @JsonKey(name: 'creator_avatar_url')
  String? get creatorAvatarUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'sport_id')
  String? get sportId => throw _privateConstructorUsedError;
  @JsonKey(name: 'sport_key')
  String? get sportKey => throw _privateConstructorUsedError;
  @JsonKey(name: 'sport_name_en')
  String? get sportNameEn => throw _privateConstructorUsedError;
  @JsonKey(name: 'sport_name_ar')
  String? get sportNameAr => throw _privateConstructorUsedError;
  @JsonKey(name: 'sport_emoji')
  String? get sportEmoji => throw _privateConstructorUsedError;
  @JsonKey(name: 'area_id')
  String? get areaId => throw _privateConstructorUsedError;
  @JsonKey(name: 'area_name')
  String? get areaName => throw _privateConstructorUsedError;
  @JsonKey(name: 'venue_id')
  String? get venueId => throw _privateConstructorUsedError;
  @JsonKey(name: 'venue_name')
  String? get venueName => throw _privateConstructorUsedError;
  @JsonKey(name: 'location_name')
  String? get locationName => throw _privateConstructorUsedError;
  @JsonKey(name: 'geo_location_id')
  String? get geoLocationId => throw _privateConstructorUsedError;
  @JsonKey(name: 'min_skill')
  int? get minSkill => throw _privateConstructorUsedError;
  @JsonKey(name: 'max_skill')
  int? get maxSkill => throw _privateConstructorUsedError;
  @JsonKey(name: 'joining_rule')
  String get joiningRule => throw _privateConstructorUsedError;
  @JsonKey(name: 'cost_cover')
  String get costCover => throw _privateConstructorUsedError;
  @JsonKey(name: 'going_count')
  int get goingCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'interested_count')
  int get interestedCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'declined_count')
  int get declinedCount => throw _privateConstructorUsedError; // Legacy meetup_attendees status (going/interested/declined) for the
  // caller's player actor; null when no RSVP.
  @JsonKey(name: 'my_rsvp_status')
  String? get myRsvpStatus => throw _privateConstructorUsedError;

  /// Serializes this MeetupListItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MeetupListItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MeetupListItemCopyWith<MeetupListItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MeetupListItemCopyWith<$Res> {
  factory $MeetupListItemCopyWith(
    MeetupListItem value,
    $Res Function(MeetupListItem) then,
  ) = _$MeetupListItemCopyWithImpl<$Res, MeetupListItem>;
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    @JsonKey(name: 'start_at') DateTime startAt,
    @JsonKey(name: 'end_at') DateTime? endAt,
    int? capacity,
    @JsonKey(name: 'members_only') bool membersOnly,
    @JsonKey(name: 'listing_visibility') String listingVisibility,
    @JsonKey(name: 'rsvp_policy', unknownEnumValue: RsvpPolicy.closed)
    RsvpPolicy rsvpPolicy,
    @JsonKey(name: 'is_cancelled') bool isCancelled,
    @JsonKey(name: 'vibe_key') String? vibeKey,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'creator_profile_id') String? creatorProfileId,
    @JsonKey(name: 'creator_display_name') String? creatorDisplayName,
    @JsonKey(name: 'creator_username') String? creatorUsername,
    @JsonKey(name: 'creator_avatar_url') String? creatorAvatarUrl,
    @JsonKey(name: 'sport_id') String? sportId,
    @JsonKey(name: 'sport_key') String? sportKey,
    @JsonKey(name: 'sport_name_en') String? sportNameEn,
    @JsonKey(name: 'sport_name_ar') String? sportNameAr,
    @JsonKey(name: 'sport_emoji') String? sportEmoji,
    @JsonKey(name: 'area_id') String? areaId,
    @JsonKey(name: 'area_name') String? areaName,
    @JsonKey(name: 'venue_id') String? venueId,
    @JsonKey(name: 'venue_name') String? venueName,
    @JsonKey(name: 'location_name') String? locationName,
    @JsonKey(name: 'geo_location_id') String? geoLocationId,
    @JsonKey(name: 'min_skill') int? minSkill,
    @JsonKey(name: 'max_skill') int? maxSkill,
    @JsonKey(name: 'joining_rule') String joiningRule,
    @JsonKey(name: 'cost_cover') String costCover,
    @JsonKey(name: 'going_count') int goingCount,
    @JsonKey(name: 'interested_count') int interestedCount,
    @JsonKey(name: 'declined_count') int declinedCount,
    @JsonKey(name: 'my_rsvp_status') String? myRsvpStatus,
  });
}

/// @nodoc
class _$MeetupListItemCopyWithImpl<$Res, $Val extends MeetupListItem>
    implements $MeetupListItemCopyWith<$Res> {
  _$MeetupListItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MeetupListItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? startAt = null,
    Object? endAt = freezed,
    Object? capacity = freezed,
    Object? membersOnly = null,
    Object? listingVisibility = null,
    Object? rsvpPolicy = null,
    Object? isCancelled = null,
    Object? vibeKey = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? creatorProfileId = freezed,
    Object? creatorDisplayName = freezed,
    Object? creatorUsername = freezed,
    Object? creatorAvatarUrl = freezed,
    Object? sportId = freezed,
    Object? sportKey = freezed,
    Object? sportNameEn = freezed,
    Object? sportNameAr = freezed,
    Object? sportEmoji = freezed,
    Object? areaId = freezed,
    Object? areaName = freezed,
    Object? venueId = freezed,
    Object? venueName = freezed,
    Object? locationName = freezed,
    Object? geoLocationId = freezed,
    Object? minSkill = freezed,
    Object? maxSkill = freezed,
    Object? joiningRule = null,
    Object? costCover = null,
    Object? goingCount = null,
    Object? interestedCount = null,
    Object? declinedCount = null,
    Object? myRsvpStatus = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            startAt: null == startAt
                ? _value.startAt
                : startAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endAt: freezed == endAt
                ? _value.endAt
                : endAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            capacity: freezed == capacity
                ? _value.capacity
                : capacity // ignore: cast_nullable_to_non_nullable
                      as int?,
            membersOnly: null == membersOnly
                ? _value.membersOnly
                : membersOnly // ignore: cast_nullable_to_non_nullable
                      as bool,
            listingVisibility: null == listingVisibility
                ? _value.listingVisibility
                : listingVisibility // ignore: cast_nullable_to_non_nullable
                      as String,
            rsvpPolicy: null == rsvpPolicy
                ? _value.rsvpPolicy
                : rsvpPolicy // ignore: cast_nullable_to_non_nullable
                      as RsvpPolicy,
            isCancelled: null == isCancelled
                ? _value.isCancelled
                : isCancelled // ignore: cast_nullable_to_non_nullable
                      as bool,
            vibeKey: freezed == vibeKey
                ? _value.vibeKey
                : vibeKey // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: freezed == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            updatedAt: freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            creatorProfileId: freezed == creatorProfileId
                ? _value.creatorProfileId
                : creatorProfileId // ignore: cast_nullable_to_non_nullable
                      as String?,
            creatorDisplayName: freezed == creatorDisplayName
                ? _value.creatorDisplayName
                : creatorDisplayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            creatorUsername: freezed == creatorUsername
                ? _value.creatorUsername
                : creatorUsername // ignore: cast_nullable_to_non_nullable
                      as String?,
            creatorAvatarUrl: freezed == creatorAvatarUrl
                ? _value.creatorAvatarUrl
                : creatorAvatarUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            sportId: freezed == sportId
                ? _value.sportId
                : sportId // ignore: cast_nullable_to_non_nullable
                      as String?,
            sportKey: freezed == sportKey
                ? _value.sportKey
                : sportKey // ignore: cast_nullable_to_non_nullable
                      as String?,
            sportNameEn: freezed == sportNameEn
                ? _value.sportNameEn
                : sportNameEn // ignore: cast_nullable_to_non_nullable
                      as String?,
            sportNameAr: freezed == sportNameAr
                ? _value.sportNameAr
                : sportNameAr // ignore: cast_nullable_to_non_nullable
                      as String?,
            sportEmoji: freezed == sportEmoji
                ? _value.sportEmoji
                : sportEmoji // ignore: cast_nullable_to_non_nullable
                      as String?,
            areaId: freezed == areaId
                ? _value.areaId
                : areaId // ignore: cast_nullable_to_non_nullable
                      as String?,
            areaName: freezed == areaName
                ? _value.areaName
                : areaName // ignore: cast_nullable_to_non_nullable
                      as String?,
            venueId: freezed == venueId
                ? _value.venueId
                : venueId // ignore: cast_nullable_to_non_nullable
                      as String?,
            venueName: freezed == venueName
                ? _value.venueName
                : venueName // ignore: cast_nullable_to_non_nullable
                      as String?,
            locationName: freezed == locationName
                ? _value.locationName
                : locationName // ignore: cast_nullable_to_non_nullable
                      as String?,
            geoLocationId: freezed == geoLocationId
                ? _value.geoLocationId
                : geoLocationId // ignore: cast_nullable_to_non_nullable
                      as String?,
            minSkill: freezed == minSkill
                ? _value.minSkill
                : minSkill // ignore: cast_nullable_to_non_nullable
                      as int?,
            maxSkill: freezed == maxSkill
                ? _value.maxSkill
                : maxSkill // ignore: cast_nullable_to_non_nullable
                      as int?,
            joiningRule: null == joiningRule
                ? _value.joiningRule
                : joiningRule // ignore: cast_nullable_to_non_nullable
                      as String,
            costCover: null == costCover
                ? _value.costCover
                : costCover // ignore: cast_nullable_to_non_nullable
                      as String,
            goingCount: null == goingCount
                ? _value.goingCount
                : goingCount // ignore: cast_nullable_to_non_nullable
                      as int,
            interestedCount: null == interestedCount
                ? _value.interestedCount
                : interestedCount // ignore: cast_nullable_to_non_nullable
                      as int,
            declinedCount: null == declinedCount
                ? _value.declinedCount
                : declinedCount // ignore: cast_nullable_to_non_nullable
                      as int,
            myRsvpStatus: freezed == myRsvpStatus
                ? _value.myRsvpStatus
                : myRsvpStatus // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MeetupListItemImplCopyWith<$Res>
    implements $MeetupListItemCopyWith<$Res> {
  factory _$$MeetupListItemImplCopyWith(
    _$MeetupListItemImpl value,
    $Res Function(_$MeetupListItemImpl) then,
  ) = __$$MeetupListItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    @JsonKey(name: 'start_at') DateTime startAt,
    @JsonKey(name: 'end_at') DateTime? endAt,
    int? capacity,
    @JsonKey(name: 'members_only') bool membersOnly,
    @JsonKey(name: 'listing_visibility') String listingVisibility,
    @JsonKey(name: 'rsvp_policy', unknownEnumValue: RsvpPolicy.closed)
    RsvpPolicy rsvpPolicy,
    @JsonKey(name: 'is_cancelled') bool isCancelled,
    @JsonKey(name: 'vibe_key') String? vibeKey,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'creator_profile_id') String? creatorProfileId,
    @JsonKey(name: 'creator_display_name') String? creatorDisplayName,
    @JsonKey(name: 'creator_username') String? creatorUsername,
    @JsonKey(name: 'creator_avatar_url') String? creatorAvatarUrl,
    @JsonKey(name: 'sport_id') String? sportId,
    @JsonKey(name: 'sport_key') String? sportKey,
    @JsonKey(name: 'sport_name_en') String? sportNameEn,
    @JsonKey(name: 'sport_name_ar') String? sportNameAr,
    @JsonKey(name: 'sport_emoji') String? sportEmoji,
    @JsonKey(name: 'area_id') String? areaId,
    @JsonKey(name: 'area_name') String? areaName,
    @JsonKey(name: 'venue_id') String? venueId,
    @JsonKey(name: 'venue_name') String? venueName,
    @JsonKey(name: 'location_name') String? locationName,
    @JsonKey(name: 'geo_location_id') String? geoLocationId,
    @JsonKey(name: 'min_skill') int? minSkill,
    @JsonKey(name: 'max_skill') int? maxSkill,
    @JsonKey(name: 'joining_rule') String joiningRule,
    @JsonKey(name: 'cost_cover') String costCover,
    @JsonKey(name: 'going_count') int goingCount,
    @JsonKey(name: 'interested_count') int interestedCount,
    @JsonKey(name: 'declined_count') int declinedCount,
    @JsonKey(name: 'my_rsvp_status') String? myRsvpStatus,
  });
}

/// @nodoc
class __$$MeetupListItemImplCopyWithImpl<$Res>
    extends _$MeetupListItemCopyWithImpl<$Res, _$MeetupListItemImpl>
    implements _$$MeetupListItemImplCopyWith<$Res> {
  __$$MeetupListItemImplCopyWithImpl(
    _$MeetupListItemImpl _value,
    $Res Function(_$MeetupListItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MeetupListItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? startAt = null,
    Object? endAt = freezed,
    Object? capacity = freezed,
    Object? membersOnly = null,
    Object? listingVisibility = null,
    Object? rsvpPolicy = null,
    Object? isCancelled = null,
    Object? vibeKey = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? creatorProfileId = freezed,
    Object? creatorDisplayName = freezed,
    Object? creatorUsername = freezed,
    Object? creatorAvatarUrl = freezed,
    Object? sportId = freezed,
    Object? sportKey = freezed,
    Object? sportNameEn = freezed,
    Object? sportNameAr = freezed,
    Object? sportEmoji = freezed,
    Object? areaId = freezed,
    Object? areaName = freezed,
    Object? venueId = freezed,
    Object? venueName = freezed,
    Object? locationName = freezed,
    Object? geoLocationId = freezed,
    Object? minSkill = freezed,
    Object? maxSkill = freezed,
    Object? joiningRule = null,
    Object? costCover = null,
    Object? goingCount = null,
    Object? interestedCount = null,
    Object? declinedCount = null,
    Object? myRsvpStatus = freezed,
  }) {
    return _then(
      _$MeetupListItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        startAt: null == startAt
            ? _value.startAt
            : startAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endAt: freezed == endAt
            ? _value.endAt
            : endAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        capacity: freezed == capacity
            ? _value.capacity
            : capacity // ignore: cast_nullable_to_non_nullable
                  as int?,
        membersOnly: null == membersOnly
            ? _value.membersOnly
            : membersOnly // ignore: cast_nullable_to_non_nullable
                  as bool,
        listingVisibility: null == listingVisibility
            ? _value.listingVisibility
            : listingVisibility // ignore: cast_nullable_to_non_nullable
                  as String,
        rsvpPolicy: null == rsvpPolicy
            ? _value.rsvpPolicy
            : rsvpPolicy // ignore: cast_nullable_to_non_nullable
                  as RsvpPolicy,
        isCancelled: null == isCancelled
            ? _value.isCancelled
            : isCancelled // ignore: cast_nullable_to_non_nullable
                  as bool,
        vibeKey: freezed == vibeKey
            ? _value.vibeKey
            : vibeKey // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: freezed == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        updatedAt: freezed == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        creatorProfileId: freezed == creatorProfileId
            ? _value.creatorProfileId
            : creatorProfileId // ignore: cast_nullable_to_non_nullable
                  as String?,
        creatorDisplayName: freezed == creatorDisplayName
            ? _value.creatorDisplayName
            : creatorDisplayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        creatorUsername: freezed == creatorUsername
            ? _value.creatorUsername
            : creatorUsername // ignore: cast_nullable_to_non_nullable
                  as String?,
        creatorAvatarUrl: freezed == creatorAvatarUrl
            ? _value.creatorAvatarUrl
            : creatorAvatarUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        sportId: freezed == sportId
            ? _value.sportId
            : sportId // ignore: cast_nullable_to_non_nullable
                  as String?,
        sportKey: freezed == sportKey
            ? _value.sportKey
            : sportKey // ignore: cast_nullable_to_non_nullable
                  as String?,
        sportNameEn: freezed == sportNameEn
            ? _value.sportNameEn
            : sportNameEn // ignore: cast_nullable_to_non_nullable
                  as String?,
        sportNameAr: freezed == sportNameAr
            ? _value.sportNameAr
            : sportNameAr // ignore: cast_nullable_to_non_nullable
                  as String?,
        sportEmoji: freezed == sportEmoji
            ? _value.sportEmoji
            : sportEmoji // ignore: cast_nullable_to_non_nullable
                  as String?,
        areaId: freezed == areaId
            ? _value.areaId
            : areaId // ignore: cast_nullable_to_non_nullable
                  as String?,
        areaName: freezed == areaName
            ? _value.areaName
            : areaName // ignore: cast_nullable_to_non_nullable
                  as String?,
        venueId: freezed == venueId
            ? _value.venueId
            : venueId // ignore: cast_nullable_to_non_nullable
                  as String?,
        venueName: freezed == venueName
            ? _value.venueName
            : venueName // ignore: cast_nullable_to_non_nullable
                  as String?,
        locationName: freezed == locationName
            ? _value.locationName
            : locationName // ignore: cast_nullable_to_non_nullable
                  as String?,
        geoLocationId: freezed == geoLocationId
            ? _value.geoLocationId
            : geoLocationId // ignore: cast_nullable_to_non_nullable
                  as String?,
        minSkill: freezed == minSkill
            ? _value.minSkill
            : minSkill // ignore: cast_nullable_to_non_nullable
                  as int?,
        maxSkill: freezed == maxSkill
            ? _value.maxSkill
            : maxSkill // ignore: cast_nullable_to_non_nullable
                  as int?,
        joiningRule: null == joiningRule
            ? _value.joiningRule
            : joiningRule // ignore: cast_nullable_to_non_nullable
                  as String,
        costCover: null == costCover
            ? _value.costCover
            : costCover // ignore: cast_nullable_to_non_nullable
                  as String,
        goingCount: null == goingCount
            ? _value.goingCount
            : goingCount // ignore: cast_nullable_to_non_nullable
                  as int,
        interestedCount: null == interestedCount
            ? _value.interestedCount
            : interestedCount // ignore: cast_nullable_to_non_nullable
                  as int,
        declinedCount: null == declinedCount
            ? _value.declinedCount
            : declinedCount // ignore: cast_nullable_to_non_nullable
                  as int,
        myRsvpStatus: freezed == myRsvpStatus
            ? _value.myRsvpStatus
            : myRsvpStatus // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MeetupListItemImpl extends _MeetupListItem {
  const _$MeetupListItemImpl({
    required this.id,
    required this.title,
    this.description,
    @JsonKey(name: 'start_at') required this.startAt,
    @JsonKey(name: 'end_at') this.endAt,
    this.capacity,
    @JsonKey(name: 'members_only') this.membersOnly = false,
    @JsonKey(name: 'listing_visibility') this.listingVisibility = 'public',
    @JsonKey(name: 'rsvp_policy', unknownEnumValue: RsvpPolicy.closed)
    this.rsvpPolicy = RsvpPolicy.closed,
    @JsonKey(name: 'is_cancelled') this.isCancelled = false,
    @JsonKey(name: 'vibe_key') this.vibeKey,
    @JsonKey(name: 'created_at') this.createdAt,
    @JsonKey(name: 'updated_at') this.updatedAt,
    @JsonKey(name: 'creator_profile_id') this.creatorProfileId,
    @JsonKey(name: 'creator_display_name') this.creatorDisplayName,
    @JsonKey(name: 'creator_username') this.creatorUsername,
    @JsonKey(name: 'creator_avatar_url') this.creatorAvatarUrl,
    @JsonKey(name: 'sport_id') this.sportId,
    @JsonKey(name: 'sport_key') this.sportKey,
    @JsonKey(name: 'sport_name_en') this.sportNameEn,
    @JsonKey(name: 'sport_name_ar') this.sportNameAr,
    @JsonKey(name: 'sport_emoji') this.sportEmoji,
    @JsonKey(name: 'area_id') this.areaId,
    @JsonKey(name: 'area_name') this.areaName,
    @JsonKey(name: 'venue_id') this.venueId,
    @JsonKey(name: 'venue_name') this.venueName,
    @JsonKey(name: 'location_name') this.locationName,
    @JsonKey(name: 'geo_location_id') this.geoLocationId,
    @JsonKey(name: 'min_skill') this.minSkill,
    @JsonKey(name: 'max_skill') this.maxSkill,
    @JsonKey(name: 'joining_rule') this.joiningRule = 'free',
    @JsonKey(name: 'cost_cover') this.costCover = 'free',
    @JsonKey(name: 'going_count') this.goingCount = 0,
    @JsonKey(name: 'interested_count') this.interestedCount = 0,
    @JsonKey(name: 'declined_count') this.declinedCount = 0,
    @JsonKey(name: 'my_rsvp_status') this.myRsvpStatus,
  }) : super._();

  factory _$MeetupListItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$MeetupListItemImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String? description;
  @override
  @JsonKey(name: 'start_at')
  final DateTime startAt;
  @override
  @JsonKey(name: 'end_at')
  final DateTime? endAt;
  @override
  final int? capacity;
  @override
  @JsonKey(name: 'members_only')
  final bool membersOnly;
  @override
  @JsonKey(name: 'listing_visibility')
  final String listingVisibility;
  @override
  @JsonKey(name: 'rsvp_policy', unknownEnumValue: RsvpPolicy.closed)
  final RsvpPolicy rsvpPolicy;
  @override
  @JsonKey(name: 'is_cancelled')
  final bool isCancelled;
  @override
  @JsonKey(name: 'vibe_key')
  final String? vibeKey;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  @override
  @JsonKey(name: 'creator_profile_id')
  final String? creatorProfileId;
  @override
  @JsonKey(name: 'creator_display_name')
  final String? creatorDisplayName;
  @override
  @JsonKey(name: 'creator_username')
  final String? creatorUsername;
  @override
  @JsonKey(name: 'creator_avatar_url')
  final String? creatorAvatarUrl;
  @override
  @JsonKey(name: 'sport_id')
  final String? sportId;
  @override
  @JsonKey(name: 'sport_key')
  final String? sportKey;
  @override
  @JsonKey(name: 'sport_name_en')
  final String? sportNameEn;
  @override
  @JsonKey(name: 'sport_name_ar')
  final String? sportNameAr;
  @override
  @JsonKey(name: 'sport_emoji')
  final String? sportEmoji;
  @override
  @JsonKey(name: 'area_id')
  final String? areaId;
  @override
  @JsonKey(name: 'area_name')
  final String? areaName;
  @override
  @JsonKey(name: 'venue_id')
  final String? venueId;
  @override
  @JsonKey(name: 'venue_name')
  final String? venueName;
  @override
  @JsonKey(name: 'location_name')
  final String? locationName;
  @override
  @JsonKey(name: 'geo_location_id')
  final String? geoLocationId;
  @override
  @JsonKey(name: 'min_skill')
  final int? minSkill;
  @override
  @JsonKey(name: 'max_skill')
  final int? maxSkill;
  @override
  @JsonKey(name: 'joining_rule')
  final String joiningRule;
  @override
  @JsonKey(name: 'cost_cover')
  final String costCover;
  @override
  @JsonKey(name: 'going_count')
  final int goingCount;
  @override
  @JsonKey(name: 'interested_count')
  final int interestedCount;
  @override
  @JsonKey(name: 'declined_count')
  final int declinedCount;
  // Legacy meetup_attendees status (going/interested/declined) for the
  // caller's player actor; null when no RSVP.
  @override
  @JsonKey(name: 'my_rsvp_status')
  final String? myRsvpStatus;

  @override
  String toString() {
    return 'MeetupListItem(id: $id, title: $title, description: $description, startAt: $startAt, endAt: $endAt, capacity: $capacity, membersOnly: $membersOnly, listingVisibility: $listingVisibility, rsvpPolicy: $rsvpPolicy, isCancelled: $isCancelled, vibeKey: $vibeKey, createdAt: $createdAt, updatedAt: $updatedAt, creatorProfileId: $creatorProfileId, creatorDisplayName: $creatorDisplayName, creatorUsername: $creatorUsername, creatorAvatarUrl: $creatorAvatarUrl, sportId: $sportId, sportKey: $sportKey, sportNameEn: $sportNameEn, sportNameAr: $sportNameAr, sportEmoji: $sportEmoji, areaId: $areaId, areaName: $areaName, venueId: $venueId, venueName: $venueName, locationName: $locationName, geoLocationId: $geoLocationId, minSkill: $minSkill, maxSkill: $maxSkill, joiningRule: $joiningRule, costCover: $costCover, goingCount: $goingCount, interestedCount: $interestedCount, declinedCount: $declinedCount, myRsvpStatus: $myRsvpStatus)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeetupListItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.startAt, startAt) || other.startAt == startAt) &&
            (identical(other.endAt, endAt) || other.endAt == endAt) &&
            (identical(other.capacity, capacity) ||
                other.capacity == capacity) &&
            (identical(other.membersOnly, membersOnly) ||
                other.membersOnly == membersOnly) &&
            (identical(other.listingVisibility, listingVisibility) ||
                other.listingVisibility == listingVisibility) &&
            (identical(other.rsvpPolicy, rsvpPolicy) ||
                other.rsvpPolicy == rsvpPolicy) &&
            (identical(other.isCancelled, isCancelled) ||
                other.isCancelled == isCancelled) &&
            (identical(other.vibeKey, vibeKey) || other.vibeKey == vibeKey) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.creatorProfileId, creatorProfileId) ||
                other.creatorProfileId == creatorProfileId) &&
            (identical(other.creatorDisplayName, creatorDisplayName) ||
                other.creatorDisplayName == creatorDisplayName) &&
            (identical(other.creatorUsername, creatorUsername) ||
                other.creatorUsername == creatorUsername) &&
            (identical(other.creatorAvatarUrl, creatorAvatarUrl) ||
                other.creatorAvatarUrl == creatorAvatarUrl) &&
            (identical(other.sportId, sportId) || other.sportId == sportId) &&
            (identical(other.sportKey, sportKey) ||
                other.sportKey == sportKey) &&
            (identical(other.sportNameEn, sportNameEn) ||
                other.sportNameEn == sportNameEn) &&
            (identical(other.sportNameAr, sportNameAr) ||
                other.sportNameAr == sportNameAr) &&
            (identical(other.sportEmoji, sportEmoji) ||
                other.sportEmoji == sportEmoji) &&
            (identical(other.areaId, areaId) || other.areaId == areaId) &&
            (identical(other.areaName, areaName) ||
                other.areaName == areaName) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.venueName, venueName) ||
                other.venueName == venueName) &&
            (identical(other.locationName, locationName) ||
                other.locationName == locationName) &&
            (identical(other.geoLocationId, geoLocationId) ||
                other.geoLocationId == geoLocationId) &&
            (identical(other.minSkill, minSkill) ||
                other.minSkill == minSkill) &&
            (identical(other.maxSkill, maxSkill) ||
                other.maxSkill == maxSkill) &&
            (identical(other.joiningRule, joiningRule) ||
                other.joiningRule == joiningRule) &&
            (identical(other.costCover, costCover) ||
                other.costCover == costCover) &&
            (identical(other.goingCount, goingCount) ||
                other.goingCount == goingCount) &&
            (identical(other.interestedCount, interestedCount) ||
                other.interestedCount == interestedCount) &&
            (identical(other.declinedCount, declinedCount) ||
                other.declinedCount == declinedCount) &&
            (identical(other.myRsvpStatus, myRsvpStatus) ||
                other.myRsvpStatus == myRsvpStatus));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    title,
    description,
    startAt,
    endAt,
    capacity,
    membersOnly,
    listingVisibility,
    rsvpPolicy,
    isCancelled,
    vibeKey,
    createdAt,
    updatedAt,
    creatorProfileId,
    creatorDisplayName,
    creatorUsername,
    creatorAvatarUrl,
    sportId,
    sportKey,
    sportNameEn,
    sportNameAr,
    sportEmoji,
    areaId,
    areaName,
    venueId,
    venueName,
    locationName,
    geoLocationId,
    minSkill,
    maxSkill,
    joiningRule,
    costCover,
    goingCount,
    interestedCount,
    declinedCount,
    myRsvpStatus,
  ]);

  /// Create a copy of MeetupListItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MeetupListItemImplCopyWith<_$MeetupListItemImpl> get copyWith =>
      __$$MeetupListItemImplCopyWithImpl<_$MeetupListItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MeetupListItemImplToJson(this);
  }
}

abstract class _MeetupListItem extends MeetupListItem {
  const factory _MeetupListItem({
    required final String id,
    required final String title,
    final String? description,
    @JsonKey(name: 'start_at') required final DateTime startAt,
    @JsonKey(name: 'end_at') final DateTime? endAt,
    final int? capacity,
    @JsonKey(name: 'members_only') final bool membersOnly,
    @JsonKey(name: 'listing_visibility') final String listingVisibility,
    @JsonKey(name: 'rsvp_policy', unknownEnumValue: RsvpPolicy.closed)
    final RsvpPolicy rsvpPolicy,
    @JsonKey(name: 'is_cancelled') final bool isCancelled,
    @JsonKey(name: 'vibe_key') final String? vibeKey,
    @JsonKey(name: 'created_at') final DateTime? createdAt,
    @JsonKey(name: 'updated_at') final DateTime? updatedAt,
    @JsonKey(name: 'creator_profile_id') final String? creatorProfileId,
    @JsonKey(name: 'creator_display_name') final String? creatorDisplayName,
    @JsonKey(name: 'creator_username') final String? creatorUsername,
    @JsonKey(name: 'creator_avatar_url') final String? creatorAvatarUrl,
    @JsonKey(name: 'sport_id') final String? sportId,
    @JsonKey(name: 'sport_key') final String? sportKey,
    @JsonKey(name: 'sport_name_en') final String? sportNameEn,
    @JsonKey(name: 'sport_name_ar') final String? sportNameAr,
    @JsonKey(name: 'sport_emoji') final String? sportEmoji,
    @JsonKey(name: 'area_id') final String? areaId,
    @JsonKey(name: 'area_name') final String? areaName,
    @JsonKey(name: 'venue_id') final String? venueId,
    @JsonKey(name: 'venue_name') final String? venueName,
    @JsonKey(name: 'location_name') final String? locationName,
    @JsonKey(name: 'geo_location_id') final String? geoLocationId,
    @JsonKey(name: 'min_skill') final int? minSkill,
    @JsonKey(name: 'max_skill') final int? maxSkill,
    @JsonKey(name: 'joining_rule') final String joiningRule,
    @JsonKey(name: 'cost_cover') final String costCover,
    @JsonKey(name: 'going_count') final int goingCount,
    @JsonKey(name: 'interested_count') final int interestedCount,
    @JsonKey(name: 'declined_count') final int declinedCount,
    @JsonKey(name: 'my_rsvp_status') final String? myRsvpStatus,
  }) = _$MeetupListItemImpl;
  const _MeetupListItem._() : super._();

  factory _MeetupListItem.fromJson(Map<String, dynamic> json) =
      _$MeetupListItemImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String? get description;
  @override
  @JsonKey(name: 'start_at')
  DateTime get startAt;
  @override
  @JsonKey(name: 'end_at')
  DateTime? get endAt;
  @override
  int? get capacity;
  @override
  @JsonKey(name: 'members_only')
  bool get membersOnly;
  @override
  @JsonKey(name: 'listing_visibility')
  String get listingVisibility;
  @override
  @JsonKey(name: 'rsvp_policy', unknownEnumValue: RsvpPolicy.closed)
  RsvpPolicy get rsvpPolicy;
  @override
  @JsonKey(name: 'is_cancelled')
  bool get isCancelled;
  @override
  @JsonKey(name: 'vibe_key')
  String? get vibeKey;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;
  @override
  @JsonKey(name: 'creator_profile_id')
  String? get creatorProfileId;
  @override
  @JsonKey(name: 'creator_display_name')
  String? get creatorDisplayName;
  @override
  @JsonKey(name: 'creator_username')
  String? get creatorUsername;
  @override
  @JsonKey(name: 'creator_avatar_url')
  String? get creatorAvatarUrl;
  @override
  @JsonKey(name: 'sport_id')
  String? get sportId;
  @override
  @JsonKey(name: 'sport_key')
  String? get sportKey;
  @override
  @JsonKey(name: 'sport_name_en')
  String? get sportNameEn;
  @override
  @JsonKey(name: 'sport_name_ar')
  String? get sportNameAr;
  @override
  @JsonKey(name: 'sport_emoji')
  String? get sportEmoji;
  @override
  @JsonKey(name: 'area_id')
  String? get areaId;
  @override
  @JsonKey(name: 'area_name')
  String? get areaName;
  @override
  @JsonKey(name: 'venue_id')
  String? get venueId;
  @override
  @JsonKey(name: 'venue_name')
  String? get venueName;
  @override
  @JsonKey(name: 'location_name')
  String? get locationName;
  @override
  @JsonKey(name: 'geo_location_id')
  String? get geoLocationId;
  @override
  @JsonKey(name: 'min_skill')
  int? get minSkill;
  @override
  @JsonKey(name: 'max_skill')
  int? get maxSkill;
  @override
  @JsonKey(name: 'joining_rule')
  String get joiningRule;
  @override
  @JsonKey(name: 'cost_cover')
  String get costCover;
  @override
  @JsonKey(name: 'going_count')
  int get goingCount;
  @override
  @JsonKey(name: 'interested_count')
  int get interestedCount;
  @override
  @JsonKey(name: 'declined_count')
  int get declinedCount; // Legacy meetup_attendees status (going/interested/declined) for the
  // caller's player actor; null when no RSVP.
  @override
  @JsonKey(name: 'my_rsvp_status')
  String? get myRsvpStatus;

  /// Create a copy of MeetupListItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MeetupListItemImplCopyWith<_$MeetupListItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NearbyMeetup _$NearbyMeetupFromJson(Map<String, dynamic> json) {
  return _NearbyMeetup.fromJson(json);
}

/// @nodoc
mixin _$NearbyMeetup {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  @JsonKey(name: 'starts_at')
  DateTime? get startsAt => throw _privateConstructorUsedError;
  double? get lat => throw _privateConstructorUsedError;
  double? get lng => throw _privateConstructorUsedError;
  @JsonKey(name: 'areaid')
  String? get areaId => throw _privateConstructorUsedError;
  @JsonKey(name: 'distance_m')
  double? get distanceM => throw _privateConstructorUsedError;

  /// Serializes this NearbyMeetup to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NearbyMeetup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NearbyMeetupCopyWith<NearbyMeetup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NearbyMeetupCopyWith<$Res> {
  factory $NearbyMeetupCopyWith(
    NearbyMeetup value,
    $Res Function(NearbyMeetup) then,
  ) = _$NearbyMeetupCopyWithImpl<$Res, NearbyMeetup>;
  @useResult
  $Res call({
    String id,
    String title,
    @JsonKey(name: 'starts_at') DateTime? startsAt,
    double? lat,
    double? lng,
    @JsonKey(name: 'areaid') String? areaId,
    @JsonKey(name: 'distance_m') double? distanceM,
  });
}

/// @nodoc
class _$NearbyMeetupCopyWithImpl<$Res, $Val extends NearbyMeetup>
    implements $NearbyMeetupCopyWith<$Res> {
  _$NearbyMeetupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NearbyMeetup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? startsAt = freezed,
    Object? lat = freezed,
    Object? lng = freezed,
    Object? areaId = freezed,
    Object? distanceM = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            startsAt: freezed == startsAt
                ? _value.startsAt
                : startsAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            lat: freezed == lat
                ? _value.lat
                : lat // ignore: cast_nullable_to_non_nullable
                      as double?,
            lng: freezed == lng
                ? _value.lng
                : lng // ignore: cast_nullable_to_non_nullable
                      as double?,
            areaId: freezed == areaId
                ? _value.areaId
                : areaId // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$NearbyMeetupImplCopyWith<$Res>
    implements $NearbyMeetupCopyWith<$Res> {
  factory _$$NearbyMeetupImplCopyWith(
    _$NearbyMeetupImpl value,
    $Res Function(_$NearbyMeetupImpl) then,
  ) = __$$NearbyMeetupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    @JsonKey(name: 'starts_at') DateTime? startsAt,
    double? lat,
    double? lng,
    @JsonKey(name: 'areaid') String? areaId,
    @JsonKey(name: 'distance_m') double? distanceM,
  });
}

/// @nodoc
class __$$NearbyMeetupImplCopyWithImpl<$Res>
    extends _$NearbyMeetupCopyWithImpl<$Res, _$NearbyMeetupImpl>
    implements _$$NearbyMeetupImplCopyWith<$Res> {
  __$$NearbyMeetupImplCopyWithImpl(
    _$NearbyMeetupImpl _value,
    $Res Function(_$NearbyMeetupImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NearbyMeetup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? startsAt = freezed,
    Object? lat = freezed,
    Object? lng = freezed,
    Object? areaId = freezed,
    Object? distanceM = freezed,
  }) {
    return _then(
      _$NearbyMeetupImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        startsAt: freezed == startsAt
            ? _value.startsAt
            : startsAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        lat: freezed == lat
            ? _value.lat
            : lat // ignore: cast_nullable_to_non_nullable
                  as double?,
        lng: freezed == lng
            ? _value.lng
            : lng // ignore: cast_nullable_to_non_nullable
                  as double?,
        areaId: freezed == areaId
            ? _value.areaId
            : areaId // ignore: cast_nullable_to_non_nullable
                  as String?,
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
class _$NearbyMeetupImpl implements _NearbyMeetup {
  const _$NearbyMeetupImpl({
    required this.id,
    required this.title,
    @JsonKey(name: 'starts_at') this.startsAt,
    this.lat,
    this.lng,
    @JsonKey(name: 'areaid') this.areaId,
    @JsonKey(name: 'distance_m') this.distanceM,
  });

  factory _$NearbyMeetupImpl.fromJson(Map<String, dynamic> json) =>
      _$$NearbyMeetupImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  @JsonKey(name: 'starts_at')
  final DateTime? startsAt;
  @override
  final double? lat;
  @override
  final double? lng;
  @override
  @JsonKey(name: 'areaid')
  final String? areaId;
  @override
  @JsonKey(name: 'distance_m')
  final double? distanceM;

  @override
  String toString() {
    return 'NearbyMeetup(id: $id, title: $title, startsAt: $startsAt, lat: $lat, lng: $lng, areaId: $areaId, distanceM: $distanceM)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NearbyMeetupImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.startsAt, startsAt) ||
                other.startsAt == startsAt) &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.areaId, areaId) || other.areaId == areaId) &&
            (identical(other.distanceM, distanceM) ||
                other.distanceM == distanceM));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    startsAt,
    lat,
    lng,
    areaId,
    distanceM,
  );

  /// Create a copy of NearbyMeetup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NearbyMeetupImplCopyWith<_$NearbyMeetupImpl> get copyWith =>
      __$$NearbyMeetupImplCopyWithImpl<_$NearbyMeetupImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NearbyMeetupImplToJson(this);
  }
}

abstract class _NearbyMeetup implements NearbyMeetup {
  const factory _NearbyMeetup({
    required final String id,
    required final String title,
    @JsonKey(name: 'starts_at') final DateTime? startsAt,
    final double? lat,
    final double? lng,
    @JsonKey(name: 'areaid') final String? areaId,
    @JsonKey(name: 'distance_m') final double? distanceM,
  }) = _$NearbyMeetupImpl;

  factory _NearbyMeetup.fromJson(Map<String, dynamic> json) =
      _$NearbyMeetupImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  @JsonKey(name: 'starts_at')
  DateTime? get startsAt;
  @override
  double? get lat;
  @override
  double? get lng;
  @override
  @JsonKey(name: 'areaid')
  String? get areaId;
  @override
  @JsonKey(name: 'distance_m')
  double? get distanceM;

  /// Create a copy of NearbyMeetup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NearbyMeetupImplCopyWith<_$NearbyMeetupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MeetupHost _$MeetupHostFromJson(Map<String, dynamic> json) {
  return _MeetupHost.fromJson(json);
}

/// @nodoc
mixin _$MeetupHost {
  @JsonKey(name: 'actor_profile_id')
  String? get actorProfileId => throw _privateConstructorUsedError;
  @JsonKey(name: 'display_name')
  String? get displayName => throw _privateConstructorUsedError;
  String? get username => throw _privateConstructorUsedError;

  /// Serializes this MeetupHost to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MeetupHost
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MeetupHostCopyWith<MeetupHost> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MeetupHostCopyWith<$Res> {
  factory $MeetupHostCopyWith(
    MeetupHost value,
    $Res Function(MeetupHost) then,
  ) = _$MeetupHostCopyWithImpl<$Res, MeetupHost>;
  @useResult
  $Res call({
    @JsonKey(name: 'actor_profile_id') String? actorProfileId,
    @JsonKey(name: 'display_name') String? displayName,
    String? username,
  });
}

/// @nodoc
class _$MeetupHostCopyWithImpl<$Res, $Val extends MeetupHost>
    implements $MeetupHostCopyWith<$Res> {
  _$MeetupHostCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MeetupHost
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? actorProfileId = freezed,
    Object? displayName = freezed,
    Object? username = freezed,
  }) {
    return _then(
      _value.copyWith(
            actorProfileId: freezed == actorProfileId
                ? _value.actorProfileId
                : actorProfileId // ignore: cast_nullable_to_non_nullable
                      as String?,
            displayName: freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            username: freezed == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MeetupHostImplCopyWith<$Res>
    implements $MeetupHostCopyWith<$Res> {
  factory _$$MeetupHostImplCopyWith(
    _$MeetupHostImpl value,
    $Res Function(_$MeetupHostImpl) then,
  ) = __$$MeetupHostImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'actor_profile_id') String? actorProfileId,
    @JsonKey(name: 'display_name') String? displayName,
    String? username,
  });
}

/// @nodoc
class __$$MeetupHostImplCopyWithImpl<$Res>
    extends _$MeetupHostCopyWithImpl<$Res, _$MeetupHostImpl>
    implements _$$MeetupHostImplCopyWith<$Res> {
  __$$MeetupHostImplCopyWithImpl(
    _$MeetupHostImpl _value,
    $Res Function(_$MeetupHostImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MeetupHost
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? actorProfileId = freezed,
    Object? displayName = freezed,
    Object? username = freezed,
  }) {
    return _then(
      _$MeetupHostImpl(
        actorProfileId: freezed == actorProfileId
            ? _value.actorProfileId
            : actorProfileId // ignore: cast_nullable_to_non_nullable
                  as String?,
        displayName: freezed == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        username: freezed == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MeetupHostImpl implements _MeetupHost {
  const _$MeetupHostImpl({
    @JsonKey(name: 'actor_profile_id') this.actorProfileId,
    @JsonKey(name: 'display_name') this.displayName,
    this.username,
  });

  factory _$MeetupHostImpl.fromJson(Map<String, dynamic> json) =>
      _$$MeetupHostImplFromJson(json);

  @override
  @JsonKey(name: 'actor_profile_id')
  final String? actorProfileId;
  @override
  @JsonKey(name: 'display_name')
  final String? displayName;
  @override
  final String? username;

  @override
  String toString() {
    return 'MeetupHost(actorProfileId: $actorProfileId, displayName: $displayName, username: $username)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeetupHostImpl &&
            (identical(other.actorProfileId, actorProfileId) ||
                other.actorProfileId == actorProfileId) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.username, username) ||
                other.username == username));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, actorProfileId, displayName, username);

  /// Create a copy of MeetupHost
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MeetupHostImplCopyWith<_$MeetupHostImpl> get copyWith =>
      __$$MeetupHostImplCopyWithImpl<_$MeetupHostImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MeetupHostImplToJson(this);
  }
}

abstract class _MeetupHost implements MeetupHost {
  const factory _MeetupHost({
    @JsonKey(name: 'actor_profile_id') final String? actorProfileId,
    @JsonKey(name: 'display_name') final String? displayName,
    final String? username,
  }) = _$MeetupHostImpl;

  factory _MeetupHost.fromJson(Map<String, dynamic> json) =
      _$MeetupHostImpl.fromJson;

  @override
  @JsonKey(name: 'actor_profile_id')
  String? get actorProfileId;
  @override
  @JsonKey(name: 'display_name')
  String? get displayName;
  @override
  String? get username;

  /// Create a copy of MeetupHost
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MeetupHostImplCopyWith<_$MeetupHostImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MeetupCounts _$MeetupCountsFromJson(Map<String, dynamic> json) {
  return _MeetupCounts.fromJson(json);
}

/// @nodoc
mixin _$MeetupCounts {
  int get going => throw _privateConstructorUsedError;
  int get interested => throw _privateConstructorUsedError;
  int get declined =>
      throw _privateConstructorUsedError; // Host-only: the RPC omits `pending` for everyone else.
  int? get pending => throw _privateConstructorUsedError;

  /// Serializes this MeetupCounts to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MeetupCounts
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MeetupCountsCopyWith<MeetupCounts> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MeetupCountsCopyWith<$Res> {
  factory $MeetupCountsCopyWith(
    MeetupCounts value,
    $Res Function(MeetupCounts) then,
  ) = _$MeetupCountsCopyWithImpl<$Res, MeetupCounts>;
  @useResult
  $Res call({int going, int interested, int declined, int? pending});
}

/// @nodoc
class _$MeetupCountsCopyWithImpl<$Res, $Val extends MeetupCounts>
    implements $MeetupCountsCopyWith<$Res> {
  _$MeetupCountsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MeetupCounts
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? going = null,
    Object? interested = null,
    Object? declined = null,
    Object? pending = freezed,
  }) {
    return _then(
      _value.copyWith(
            going: null == going
                ? _value.going
                : going // ignore: cast_nullable_to_non_nullable
                      as int,
            interested: null == interested
                ? _value.interested
                : interested // ignore: cast_nullable_to_non_nullable
                      as int,
            declined: null == declined
                ? _value.declined
                : declined // ignore: cast_nullable_to_non_nullable
                      as int,
            pending: freezed == pending
                ? _value.pending
                : pending // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MeetupCountsImplCopyWith<$Res>
    implements $MeetupCountsCopyWith<$Res> {
  factory _$$MeetupCountsImplCopyWith(
    _$MeetupCountsImpl value,
    $Res Function(_$MeetupCountsImpl) then,
  ) = __$$MeetupCountsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int going, int interested, int declined, int? pending});
}

/// @nodoc
class __$$MeetupCountsImplCopyWithImpl<$Res>
    extends _$MeetupCountsCopyWithImpl<$Res, _$MeetupCountsImpl>
    implements _$$MeetupCountsImplCopyWith<$Res> {
  __$$MeetupCountsImplCopyWithImpl(
    _$MeetupCountsImpl _value,
    $Res Function(_$MeetupCountsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MeetupCounts
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? going = null,
    Object? interested = null,
    Object? declined = null,
    Object? pending = freezed,
  }) {
    return _then(
      _$MeetupCountsImpl(
        going: null == going
            ? _value.going
            : going // ignore: cast_nullable_to_non_nullable
                  as int,
        interested: null == interested
            ? _value.interested
            : interested // ignore: cast_nullable_to_non_nullable
                  as int,
        declined: null == declined
            ? _value.declined
            : declined // ignore: cast_nullable_to_non_nullable
                  as int,
        pending: freezed == pending
            ? _value.pending
            : pending // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MeetupCountsImpl implements _MeetupCounts {
  const _$MeetupCountsImpl({
    this.going = 0,
    this.interested = 0,
    this.declined = 0,
    this.pending,
  });

  factory _$MeetupCountsImpl.fromJson(Map<String, dynamic> json) =>
      _$$MeetupCountsImplFromJson(json);

  @override
  @JsonKey()
  final int going;
  @override
  @JsonKey()
  final int interested;
  @override
  @JsonKey()
  final int declined;
  // Host-only: the RPC omits `pending` for everyone else.
  @override
  final int? pending;

  @override
  String toString() {
    return 'MeetupCounts(going: $going, interested: $interested, declined: $declined, pending: $pending)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeetupCountsImpl &&
            (identical(other.going, going) || other.going == going) &&
            (identical(other.interested, interested) ||
                other.interested == interested) &&
            (identical(other.declined, declined) ||
                other.declined == declined) &&
            (identical(other.pending, pending) || other.pending == pending));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, going, interested, declined, pending);

  /// Create a copy of MeetupCounts
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MeetupCountsImplCopyWith<_$MeetupCountsImpl> get copyWith =>
      __$$MeetupCountsImplCopyWithImpl<_$MeetupCountsImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MeetupCountsImplToJson(this);
  }
}

abstract class _MeetupCounts implements MeetupCounts {
  const factory _MeetupCounts({
    final int going,
    final int interested,
    final int declined,
    final int? pending,
  }) = _$MeetupCountsImpl;

  factory _MeetupCounts.fromJson(Map<String, dynamic> json) =
      _$MeetupCountsImpl.fromJson;

  @override
  int get going;
  @override
  int get interested;
  @override
  int get declined; // Host-only: the RPC omits `pending` for everyone else.
  @override
  int? get pending;

  /// Create a copy of MeetupCounts
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MeetupCountsImplCopyWith<_$MeetupCountsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MeetupCard _$MeetupCardFromJson(Map<String, dynamic> json) {
  return _MeetupCard.fromJson(json);
}

/// @nodoc
mixin _$MeetupCard {
  String get id => throw _privateConstructorUsedError;
  String? get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'start_at')
  DateTime? get startAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'end_at')
  DateTime? get endAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'location_name')
  String? get locationName => throw _privateConstructorUsedError;
  int? get capacity => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_cancelled')
  bool get isCancelled => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_host')
  bool get isHost => throw _privateConstructorUsedError;
  String? get visibility => throw _privateConstructorUsedError;
  @JsonKey(name: 'owner_profile_id')
  String? get ownerProfileId => throw _privateConstructorUsedError;
  MeetupHost? get host => throw _privateConstructorUsedError;
  MeetupCounts get counts => throw _privateConstructorUsedError;
  @JsonKey(name: 'my_status')
  String? get myStatus => throw _privateConstructorUsedError;

  /// Serializes this MeetupCard to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MeetupCard
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MeetupCardCopyWith<MeetupCard> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MeetupCardCopyWith<$Res> {
  factory $MeetupCardCopyWith(
    MeetupCard value,
    $Res Function(MeetupCard) then,
  ) = _$MeetupCardCopyWithImpl<$Res, MeetupCard>;
  @useResult
  $Res call({
    String id,
    String? title,
    String? description,
    @JsonKey(name: 'start_at') DateTime? startAt,
    @JsonKey(name: 'end_at') DateTime? endAt,
    @JsonKey(name: 'location_name') String? locationName,
    int? capacity,
    @JsonKey(name: 'is_cancelled') bool isCancelled,
    @JsonKey(name: 'is_host') bool isHost,
    String? visibility,
    @JsonKey(name: 'owner_profile_id') String? ownerProfileId,
    MeetupHost? host,
    MeetupCounts counts,
    @JsonKey(name: 'my_status') String? myStatus,
  });

  $MeetupHostCopyWith<$Res>? get host;
  $MeetupCountsCopyWith<$Res> get counts;
}

/// @nodoc
class _$MeetupCardCopyWithImpl<$Res, $Val extends MeetupCard>
    implements $MeetupCardCopyWith<$Res> {
  _$MeetupCardCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MeetupCard
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = freezed,
    Object? description = freezed,
    Object? startAt = freezed,
    Object? endAt = freezed,
    Object? locationName = freezed,
    Object? capacity = freezed,
    Object? isCancelled = null,
    Object? isHost = null,
    Object? visibility = freezed,
    Object? ownerProfileId = freezed,
    Object? host = freezed,
    Object? counts = null,
    Object? myStatus = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: freezed == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String?,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            startAt: freezed == startAt
                ? _value.startAt
                : startAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            endAt: freezed == endAt
                ? _value.endAt
                : endAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            locationName: freezed == locationName
                ? _value.locationName
                : locationName // ignore: cast_nullable_to_non_nullable
                      as String?,
            capacity: freezed == capacity
                ? _value.capacity
                : capacity // ignore: cast_nullable_to_non_nullable
                      as int?,
            isCancelled: null == isCancelled
                ? _value.isCancelled
                : isCancelled // ignore: cast_nullable_to_non_nullable
                      as bool,
            isHost: null == isHost
                ? _value.isHost
                : isHost // ignore: cast_nullable_to_non_nullable
                      as bool,
            visibility: freezed == visibility
                ? _value.visibility
                : visibility // ignore: cast_nullable_to_non_nullable
                      as String?,
            ownerProfileId: freezed == ownerProfileId
                ? _value.ownerProfileId
                : ownerProfileId // ignore: cast_nullable_to_non_nullable
                      as String?,
            host: freezed == host
                ? _value.host
                : host // ignore: cast_nullable_to_non_nullable
                      as MeetupHost?,
            counts: null == counts
                ? _value.counts
                : counts // ignore: cast_nullable_to_non_nullable
                      as MeetupCounts,
            myStatus: freezed == myStatus
                ? _value.myStatus
                : myStatus // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of MeetupCard
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MeetupHostCopyWith<$Res>? get host {
    if (_value.host == null) {
      return null;
    }

    return $MeetupHostCopyWith<$Res>(_value.host!, (value) {
      return _then(_value.copyWith(host: value) as $Val);
    });
  }

  /// Create a copy of MeetupCard
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MeetupCountsCopyWith<$Res> get counts {
    return $MeetupCountsCopyWith<$Res>(_value.counts, (value) {
      return _then(_value.copyWith(counts: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MeetupCardImplCopyWith<$Res>
    implements $MeetupCardCopyWith<$Res> {
  factory _$$MeetupCardImplCopyWith(
    _$MeetupCardImpl value,
    $Res Function(_$MeetupCardImpl) then,
  ) = __$$MeetupCardImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? title,
    String? description,
    @JsonKey(name: 'start_at') DateTime? startAt,
    @JsonKey(name: 'end_at') DateTime? endAt,
    @JsonKey(name: 'location_name') String? locationName,
    int? capacity,
    @JsonKey(name: 'is_cancelled') bool isCancelled,
    @JsonKey(name: 'is_host') bool isHost,
    String? visibility,
    @JsonKey(name: 'owner_profile_id') String? ownerProfileId,
    MeetupHost? host,
    MeetupCounts counts,
    @JsonKey(name: 'my_status') String? myStatus,
  });

  @override
  $MeetupHostCopyWith<$Res>? get host;
  @override
  $MeetupCountsCopyWith<$Res> get counts;
}

/// @nodoc
class __$$MeetupCardImplCopyWithImpl<$Res>
    extends _$MeetupCardCopyWithImpl<$Res, _$MeetupCardImpl>
    implements _$$MeetupCardImplCopyWith<$Res> {
  __$$MeetupCardImplCopyWithImpl(
    _$MeetupCardImpl _value,
    $Res Function(_$MeetupCardImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MeetupCard
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = freezed,
    Object? description = freezed,
    Object? startAt = freezed,
    Object? endAt = freezed,
    Object? locationName = freezed,
    Object? capacity = freezed,
    Object? isCancelled = null,
    Object? isHost = null,
    Object? visibility = freezed,
    Object? ownerProfileId = freezed,
    Object? host = freezed,
    Object? counts = null,
    Object? myStatus = freezed,
  }) {
    return _then(
      _$MeetupCardImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: freezed == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        startAt: freezed == startAt
            ? _value.startAt
            : startAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        endAt: freezed == endAt
            ? _value.endAt
            : endAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        locationName: freezed == locationName
            ? _value.locationName
            : locationName // ignore: cast_nullable_to_non_nullable
                  as String?,
        capacity: freezed == capacity
            ? _value.capacity
            : capacity // ignore: cast_nullable_to_non_nullable
                  as int?,
        isCancelled: null == isCancelled
            ? _value.isCancelled
            : isCancelled // ignore: cast_nullable_to_non_nullable
                  as bool,
        isHost: null == isHost
            ? _value.isHost
            : isHost // ignore: cast_nullable_to_non_nullable
                  as bool,
        visibility: freezed == visibility
            ? _value.visibility
            : visibility // ignore: cast_nullable_to_non_nullable
                  as String?,
        ownerProfileId: freezed == ownerProfileId
            ? _value.ownerProfileId
            : ownerProfileId // ignore: cast_nullable_to_non_nullable
                  as String?,
        host: freezed == host
            ? _value.host
            : host // ignore: cast_nullable_to_non_nullable
                  as MeetupHost?,
        counts: null == counts
            ? _value.counts
            : counts // ignore: cast_nullable_to_non_nullable
                  as MeetupCounts,
        myStatus: freezed == myStatus
            ? _value.myStatus
            : myStatus // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MeetupCardImpl implements _MeetupCard {
  const _$MeetupCardImpl({
    required this.id,
    this.title,
    this.description,
    @JsonKey(name: 'start_at') this.startAt,
    @JsonKey(name: 'end_at') this.endAt,
    @JsonKey(name: 'location_name') this.locationName,
    this.capacity,
    @JsonKey(name: 'is_cancelled') this.isCancelled = false,
    @JsonKey(name: 'is_host') this.isHost = false,
    this.visibility,
    @JsonKey(name: 'owner_profile_id') this.ownerProfileId,
    this.host,
    this.counts = const MeetupCounts(),
    @JsonKey(name: 'my_status') this.myStatus,
  });

  factory _$MeetupCardImpl.fromJson(Map<String, dynamic> json) =>
      _$$MeetupCardImplFromJson(json);

  @override
  final String id;
  @override
  final String? title;
  @override
  final String? description;
  @override
  @JsonKey(name: 'start_at')
  final DateTime? startAt;
  @override
  @JsonKey(name: 'end_at')
  final DateTime? endAt;
  @override
  @JsonKey(name: 'location_name')
  final String? locationName;
  @override
  final int? capacity;
  @override
  @JsonKey(name: 'is_cancelled')
  final bool isCancelled;
  @override
  @JsonKey(name: 'is_host')
  final bool isHost;
  @override
  final String? visibility;
  @override
  @JsonKey(name: 'owner_profile_id')
  final String? ownerProfileId;
  @override
  final MeetupHost? host;
  @override
  @JsonKey()
  final MeetupCounts counts;
  @override
  @JsonKey(name: 'my_status')
  final String? myStatus;

  @override
  String toString() {
    return 'MeetupCard(id: $id, title: $title, description: $description, startAt: $startAt, endAt: $endAt, locationName: $locationName, capacity: $capacity, isCancelled: $isCancelled, isHost: $isHost, visibility: $visibility, ownerProfileId: $ownerProfileId, host: $host, counts: $counts, myStatus: $myStatus)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeetupCardImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.startAt, startAt) || other.startAt == startAt) &&
            (identical(other.endAt, endAt) || other.endAt == endAt) &&
            (identical(other.locationName, locationName) ||
                other.locationName == locationName) &&
            (identical(other.capacity, capacity) ||
                other.capacity == capacity) &&
            (identical(other.isCancelled, isCancelled) ||
                other.isCancelled == isCancelled) &&
            (identical(other.isHost, isHost) || other.isHost == isHost) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            (identical(other.ownerProfileId, ownerProfileId) ||
                other.ownerProfileId == ownerProfileId) &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.counts, counts) || other.counts == counts) &&
            (identical(other.myStatus, myStatus) ||
                other.myStatus == myStatus));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    description,
    startAt,
    endAt,
    locationName,
    capacity,
    isCancelled,
    isHost,
    visibility,
    ownerProfileId,
    host,
    counts,
    myStatus,
  );

  /// Create a copy of MeetupCard
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MeetupCardImplCopyWith<_$MeetupCardImpl> get copyWith =>
      __$$MeetupCardImplCopyWithImpl<_$MeetupCardImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MeetupCardImplToJson(this);
  }
}

abstract class _MeetupCard implements MeetupCard {
  const factory _MeetupCard({
    required final String id,
    final String? title,
    final String? description,
    @JsonKey(name: 'start_at') final DateTime? startAt,
    @JsonKey(name: 'end_at') final DateTime? endAt,
    @JsonKey(name: 'location_name') final String? locationName,
    final int? capacity,
    @JsonKey(name: 'is_cancelled') final bool isCancelled,
    @JsonKey(name: 'is_host') final bool isHost,
    final String? visibility,
    @JsonKey(name: 'owner_profile_id') final String? ownerProfileId,
    final MeetupHost? host,
    final MeetupCounts counts,
    @JsonKey(name: 'my_status') final String? myStatus,
  }) = _$MeetupCardImpl;

  factory _MeetupCard.fromJson(Map<String, dynamic> json) =
      _$MeetupCardImpl.fromJson;

  @override
  String get id;
  @override
  String? get title;
  @override
  String? get description;
  @override
  @JsonKey(name: 'start_at')
  DateTime? get startAt;
  @override
  @JsonKey(name: 'end_at')
  DateTime? get endAt;
  @override
  @JsonKey(name: 'location_name')
  String? get locationName;
  @override
  int? get capacity;
  @override
  @JsonKey(name: 'is_cancelled')
  bool get isCancelled;
  @override
  @JsonKey(name: 'is_host')
  bool get isHost;
  @override
  String? get visibility;
  @override
  @JsonKey(name: 'owner_profile_id')
  String? get ownerProfileId;
  @override
  MeetupHost? get host;
  @override
  MeetupCounts get counts;
  @override
  @JsonKey(name: 'my_status')
  String? get myStatus;

  /// Create a copy of MeetupCard
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MeetupCardImplCopyWith<_$MeetupCardImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MeetupAttendee _$MeetupAttendeeFromJson(Map<String, dynamic> json) {
  return _MeetupAttendee.fromJson(json);
}

/// @nodoc
mixin _$MeetupAttendee {
  // meetup_rsvps.profile_id is nullable.
  @JsonKey(name: 'actor_profile_id')
  String? get actorProfileId => throw _privateConstructorUsedError;
  @JsonKey(name: 'display_name')
  String? get displayName => throw _privateConstructorUsedError;
  String? get username => throw _privateConstructorUsedError;
  @JsonKey(unknownEnumValue: RsvpStatus.unknown)
  RsvpStatus get status => throw _privateConstructorUsedError;

  /// Serializes this MeetupAttendee to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MeetupAttendee
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MeetupAttendeeCopyWith<MeetupAttendee> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MeetupAttendeeCopyWith<$Res> {
  factory $MeetupAttendeeCopyWith(
    MeetupAttendee value,
    $Res Function(MeetupAttendee) then,
  ) = _$MeetupAttendeeCopyWithImpl<$Res, MeetupAttendee>;
  @useResult
  $Res call({
    @JsonKey(name: 'actor_profile_id') String? actorProfileId,
    @JsonKey(name: 'display_name') String? displayName,
    String? username,
    @JsonKey(unknownEnumValue: RsvpStatus.unknown) RsvpStatus status,
  });
}

/// @nodoc
class _$MeetupAttendeeCopyWithImpl<$Res, $Val extends MeetupAttendee>
    implements $MeetupAttendeeCopyWith<$Res> {
  _$MeetupAttendeeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MeetupAttendee
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? actorProfileId = freezed,
    Object? displayName = freezed,
    Object? username = freezed,
    Object? status = null,
  }) {
    return _then(
      _value.copyWith(
            actorProfileId: freezed == actorProfileId
                ? _value.actorProfileId
                : actorProfileId // ignore: cast_nullable_to_non_nullable
                      as String?,
            displayName: freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            username: freezed == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as RsvpStatus,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MeetupAttendeeImplCopyWith<$Res>
    implements $MeetupAttendeeCopyWith<$Res> {
  factory _$$MeetupAttendeeImplCopyWith(
    _$MeetupAttendeeImpl value,
    $Res Function(_$MeetupAttendeeImpl) then,
  ) = __$$MeetupAttendeeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'actor_profile_id') String? actorProfileId,
    @JsonKey(name: 'display_name') String? displayName,
    String? username,
    @JsonKey(unknownEnumValue: RsvpStatus.unknown) RsvpStatus status,
  });
}

/// @nodoc
class __$$MeetupAttendeeImplCopyWithImpl<$Res>
    extends _$MeetupAttendeeCopyWithImpl<$Res, _$MeetupAttendeeImpl>
    implements _$$MeetupAttendeeImplCopyWith<$Res> {
  __$$MeetupAttendeeImplCopyWithImpl(
    _$MeetupAttendeeImpl _value,
    $Res Function(_$MeetupAttendeeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MeetupAttendee
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? actorProfileId = freezed,
    Object? displayName = freezed,
    Object? username = freezed,
    Object? status = null,
  }) {
    return _then(
      _$MeetupAttendeeImpl(
        actorProfileId: freezed == actorProfileId
            ? _value.actorProfileId
            : actorProfileId // ignore: cast_nullable_to_non_nullable
                  as String?,
        displayName: freezed == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        username: freezed == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as RsvpStatus,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MeetupAttendeeImpl implements _MeetupAttendee {
  const _$MeetupAttendeeImpl({
    @JsonKey(name: 'actor_profile_id') this.actorProfileId,
    @JsonKey(name: 'display_name') this.displayName,
    this.username,
    @JsonKey(unknownEnumValue: RsvpStatus.unknown)
    this.status = RsvpStatus.unknown,
  });

  factory _$MeetupAttendeeImpl.fromJson(Map<String, dynamic> json) =>
      _$$MeetupAttendeeImplFromJson(json);

  // meetup_rsvps.profile_id is nullable.
  @override
  @JsonKey(name: 'actor_profile_id')
  final String? actorProfileId;
  @override
  @JsonKey(name: 'display_name')
  final String? displayName;
  @override
  final String? username;
  @override
  @JsonKey(unknownEnumValue: RsvpStatus.unknown)
  final RsvpStatus status;

  @override
  String toString() {
    return 'MeetupAttendee(actorProfileId: $actorProfileId, displayName: $displayName, username: $username, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeetupAttendeeImpl &&
            (identical(other.actorProfileId, actorProfileId) ||
                other.actorProfileId == actorProfileId) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, actorProfileId, displayName, username, status);

  /// Create a copy of MeetupAttendee
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MeetupAttendeeImplCopyWith<_$MeetupAttendeeImpl> get copyWith =>
      __$$MeetupAttendeeImplCopyWithImpl<_$MeetupAttendeeImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MeetupAttendeeImplToJson(this);
  }
}

abstract class _MeetupAttendee implements MeetupAttendee {
  const factory _MeetupAttendee({
    @JsonKey(name: 'actor_profile_id') final String? actorProfileId,
    @JsonKey(name: 'display_name') final String? displayName,
    final String? username,
    @JsonKey(unknownEnumValue: RsvpStatus.unknown) final RsvpStatus status,
  }) = _$MeetupAttendeeImpl;

  factory _MeetupAttendee.fromJson(Map<String, dynamic> json) =
      _$MeetupAttendeeImpl.fromJson;

  // meetup_rsvps.profile_id is nullable.
  @override
  @JsonKey(name: 'actor_profile_id')
  String? get actorProfileId;
  @override
  @JsonKey(name: 'display_name')
  String? get displayName;
  @override
  String? get username;
  @override
  @JsonKey(unknownEnumValue: RsvpStatus.unknown)
  RsvpStatus get status;

  /// Create a copy of MeetupAttendee
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MeetupAttendeeImplCopyWith<_$MeetupAttendeeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RsvpEligibility _$RsvpEligibilityFromJson(Map<String, dynamic> json) {
  return _RsvpEligibility.fromJson(json);
}

/// @nodoc
mixin _$RsvpEligibility {
  bool get allowed => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _ctaFromJson, toJson: _ctaToJson)
  RsvpCta get cta => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;

  /// Serializes this RsvpEligibility to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RsvpEligibility
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RsvpEligibilityCopyWith<RsvpEligibility> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RsvpEligibilityCopyWith<$Res> {
  factory $RsvpEligibilityCopyWith(
    RsvpEligibility value,
    $Res Function(RsvpEligibility) then,
  ) = _$RsvpEligibilityCopyWithImpl<$Res, RsvpEligibility>;
  @useResult
  $Res call({
    bool allowed,
    @JsonKey(fromJson: _ctaFromJson, toJson: _ctaToJson) RsvpCta cta,
    String? reason,
  });
}

/// @nodoc
class _$RsvpEligibilityCopyWithImpl<$Res, $Val extends RsvpEligibility>
    implements $RsvpEligibilityCopyWith<$Res> {
  _$RsvpEligibilityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RsvpEligibility
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allowed = null,
    Object? cta = null,
    Object? reason = freezed,
  }) {
    return _then(
      _value.copyWith(
            allowed: null == allowed
                ? _value.allowed
                : allowed // ignore: cast_nullable_to_non_nullable
                      as bool,
            cta: null == cta
                ? _value.cta
                : cta // ignore: cast_nullable_to_non_nullable
                      as RsvpCta,
            reason: freezed == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RsvpEligibilityImplCopyWith<$Res>
    implements $RsvpEligibilityCopyWith<$Res> {
  factory _$$RsvpEligibilityImplCopyWith(
    _$RsvpEligibilityImpl value,
    $Res Function(_$RsvpEligibilityImpl) then,
  ) = __$$RsvpEligibilityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool allowed,
    @JsonKey(fromJson: _ctaFromJson, toJson: _ctaToJson) RsvpCta cta,
    String? reason,
  });
}

/// @nodoc
class __$$RsvpEligibilityImplCopyWithImpl<$Res>
    extends _$RsvpEligibilityCopyWithImpl<$Res, _$RsvpEligibilityImpl>
    implements _$$RsvpEligibilityImplCopyWith<$Res> {
  __$$RsvpEligibilityImplCopyWithImpl(
    _$RsvpEligibilityImpl _value,
    $Res Function(_$RsvpEligibilityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RsvpEligibility
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allowed = null,
    Object? cta = null,
    Object? reason = freezed,
  }) {
    return _then(
      _$RsvpEligibilityImpl(
        allowed: null == allowed
            ? _value.allowed
            : allowed // ignore: cast_nullable_to_non_nullable
                  as bool,
        cta: null == cta
            ? _value.cta
            : cta // ignore: cast_nullable_to_non_nullable
                  as RsvpCta,
        reason: freezed == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RsvpEligibilityImpl implements _RsvpEligibility {
  const _$RsvpEligibilityImpl({
    this.allowed = false,
    @JsonKey(fromJson: _ctaFromJson, toJson: _ctaToJson)
    this.cta = RsvpCta.notAllowed,
    this.reason,
  });

  factory _$RsvpEligibilityImpl.fromJson(Map<String, dynamic> json) =>
      _$$RsvpEligibilityImplFromJson(json);

  @override
  @JsonKey()
  final bool allowed;
  @override
  @JsonKey(fromJson: _ctaFromJson, toJson: _ctaToJson)
  final RsvpCta cta;
  @override
  final String? reason;

  @override
  String toString() {
    return 'RsvpEligibility(allowed: $allowed, cta: $cta, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RsvpEligibilityImpl &&
            (identical(other.allowed, allowed) || other.allowed == allowed) &&
            (identical(other.cta, cta) || other.cta == cta) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, allowed, cta, reason);

  /// Create a copy of RsvpEligibility
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RsvpEligibilityImplCopyWith<_$RsvpEligibilityImpl> get copyWith =>
      __$$RsvpEligibilityImplCopyWithImpl<_$RsvpEligibilityImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RsvpEligibilityImplToJson(this);
  }
}

abstract class _RsvpEligibility implements RsvpEligibility {
  const factory _RsvpEligibility({
    final bool allowed,
    @JsonKey(fromJson: _ctaFromJson, toJson: _ctaToJson) final RsvpCta cta,
    final String? reason,
  }) = _$RsvpEligibilityImpl;

  factory _RsvpEligibility.fromJson(Map<String, dynamic> json) =
      _$RsvpEligibilityImpl.fromJson;

  @override
  bool get allowed;
  @override
  @JsonKey(fromJson: _ctaFromJson, toJson: _ctaToJson)
  RsvpCta get cta;
  @override
  String? get reason;

  /// Create a copy of RsvpEligibility
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RsvpEligibilityImplCopyWith<_$RsvpEligibilityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MeetupSport _$MeetupSportFromJson(Map<String, dynamic> json) {
  return _MeetupSport.fromJson(json);
}

/// @nodoc
mixin _$MeetupSport {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'sport_key')
  String? get sportKey => throw _privateConstructorUsedError;
  @JsonKey(name: 'name_en')
  String get nameEn => throw _privateConstructorUsedError;
  @JsonKey(name: 'name_ar')
  String? get nameAr => throw _privateConstructorUsedError;
  String? get emoji => throw _privateConstructorUsedError;

  /// Serializes this MeetupSport to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MeetupSport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MeetupSportCopyWith<MeetupSport> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MeetupSportCopyWith<$Res> {
  factory $MeetupSportCopyWith(
    MeetupSport value,
    $Res Function(MeetupSport) then,
  ) = _$MeetupSportCopyWithImpl<$Res, MeetupSport>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'sport_key') String? sportKey,
    @JsonKey(name: 'name_en') String nameEn,
    @JsonKey(name: 'name_ar') String? nameAr,
    String? emoji,
  });
}

/// @nodoc
class _$MeetupSportCopyWithImpl<$Res, $Val extends MeetupSport>
    implements $MeetupSportCopyWith<$Res> {
  _$MeetupSportCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MeetupSport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sportKey = freezed,
    Object? nameEn = null,
    Object? nameAr = freezed,
    Object? emoji = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            sportKey: freezed == sportKey
                ? _value.sportKey
                : sportKey // ignore: cast_nullable_to_non_nullable
                      as String?,
            nameEn: null == nameEn
                ? _value.nameEn
                : nameEn // ignore: cast_nullable_to_non_nullable
                      as String,
            nameAr: freezed == nameAr
                ? _value.nameAr
                : nameAr // ignore: cast_nullable_to_non_nullable
                      as String?,
            emoji: freezed == emoji
                ? _value.emoji
                : emoji // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MeetupSportImplCopyWith<$Res>
    implements $MeetupSportCopyWith<$Res> {
  factory _$$MeetupSportImplCopyWith(
    _$MeetupSportImpl value,
    $Res Function(_$MeetupSportImpl) then,
  ) = __$$MeetupSportImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'sport_key') String? sportKey,
    @JsonKey(name: 'name_en') String nameEn,
    @JsonKey(name: 'name_ar') String? nameAr,
    String? emoji,
  });
}

/// @nodoc
class __$$MeetupSportImplCopyWithImpl<$Res>
    extends _$MeetupSportCopyWithImpl<$Res, _$MeetupSportImpl>
    implements _$$MeetupSportImplCopyWith<$Res> {
  __$$MeetupSportImplCopyWithImpl(
    _$MeetupSportImpl _value,
    $Res Function(_$MeetupSportImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MeetupSport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sportKey = freezed,
    Object? nameEn = null,
    Object? nameAr = freezed,
    Object? emoji = freezed,
  }) {
    return _then(
      _$MeetupSportImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        sportKey: freezed == sportKey
            ? _value.sportKey
            : sportKey // ignore: cast_nullable_to_non_nullable
                  as String?,
        nameEn: null == nameEn
            ? _value.nameEn
            : nameEn // ignore: cast_nullable_to_non_nullable
                  as String,
        nameAr: freezed == nameAr
            ? _value.nameAr
            : nameAr // ignore: cast_nullable_to_non_nullable
                  as String?,
        emoji: freezed == emoji
            ? _value.emoji
            : emoji // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MeetupSportImpl implements _MeetupSport {
  const _$MeetupSportImpl({
    required this.id,
    @JsonKey(name: 'sport_key') this.sportKey,
    @JsonKey(name: 'name_en') required this.nameEn,
    @JsonKey(name: 'name_ar') this.nameAr,
    this.emoji,
  });

  factory _$MeetupSportImpl.fromJson(Map<String, dynamic> json) =>
      _$$MeetupSportImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'sport_key')
  final String? sportKey;
  @override
  @JsonKey(name: 'name_en')
  final String nameEn;
  @override
  @JsonKey(name: 'name_ar')
  final String? nameAr;
  @override
  final String? emoji;

  @override
  String toString() {
    return 'MeetupSport(id: $id, sportKey: $sportKey, nameEn: $nameEn, nameAr: $nameAr, emoji: $emoji)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeetupSportImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sportKey, sportKey) ||
                other.sportKey == sportKey) &&
            (identical(other.nameEn, nameEn) || other.nameEn == nameEn) &&
            (identical(other.nameAr, nameAr) || other.nameAr == nameAr) &&
            (identical(other.emoji, emoji) || other.emoji == emoji));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, sportKey, nameEn, nameAr, emoji);

  /// Create a copy of MeetupSport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MeetupSportImplCopyWith<_$MeetupSportImpl> get copyWith =>
      __$$MeetupSportImplCopyWithImpl<_$MeetupSportImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MeetupSportImplToJson(this);
  }
}

abstract class _MeetupSport implements MeetupSport {
  const factory _MeetupSport({
    required final String id,
    @JsonKey(name: 'sport_key') final String? sportKey,
    @JsonKey(name: 'name_en') required final String nameEn,
    @JsonKey(name: 'name_ar') final String? nameAr,
    final String? emoji,
  }) = _$MeetupSportImpl;

  factory _MeetupSport.fromJson(Map<String, dynamic> json) =
      _$MeetupSportImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'sport_key')
  String? get sportKey;
  @override
  @JsonKey(name: 'name_en')
  String get nameEn;
  @override
  @JsonKey(name: 'name_ar')
  String? get nameAr;
  @override
  String? get emoji;

  /// Create a copy of MeetupSport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MeetupSportImplCopyWith<_$MeetupSportImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MeetupSportVariant _$MeetupSportVariantFromJson(Map<String, dynamic> json) {
  return _MeetupSportVariant.fromJson(json);
}

/// @nodoc
mixin _$MeetupSportVariant {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'sport_id')
  String get sportId => throw _privateConstructorUsedError;
  @JsonKey(name: 'variant_key')
  String? get variantKey => throw _privateConstructorUsedError;
  @JsonKey(name: 'name_en')
  String get nameEn => throw _privateConstructorUsedError;
  @JsonKey(name: 'name_ar')
  String? get nameAr => throw _privateConstructorUsedError;
  @JsonKey(name: 'required_players')
  int get requiredPlayers => throw _privateConstructorUsedError;

  /// Serializes this MeetupSportVariant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MeetupSportVariant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MeetupSportVariantCopyWith<MeetupSportVariant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MeetupSportVariantCopyWith<$Res> {
  factory $MeetupSportVariantCopyWith(
    MeetupSportVariant value,
    $Res Function(MeetupSportVariant) then,
  ) = _$MeetupSportVariantCopyWithImpl<$Res, MeetupSportVariant>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'sport_id') String sportId,
    @JsonKey(name: 'variant_key') String? variantKey,
    @JsonKey(name: 'name_en') String nameEn,
    @JsonKey(name: 'name_ar') String? nameAr,
    @JsonKey(name: 'required_players') int requiredPlayers,
  });
}

/// @nodoc
class _$MeetupSportVariantCopyWithImpl<$Res, $Val extends MeetupSportVariant>
    implements $MeetupSportVariantCopyWith<$Res> {
  _$MeetupSportVariantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MeetupSportVariant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sportId = null,
    Object? variantKey = freezed,
    Object? nameEn = null,
    Object? nameAr = freezed,
    Object? requiredPlayers = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            sportId: null == sportId
                ? _value.sportId
                : sportId // ignore: cast_nullable_to_non_nullable
                      as String,
            variantKey: freezed == variantKey
                ? _value.variantKey
                : variantKey // ignore: cast_nullable_to_non_nullable
                      as String?,
            nameEn: null == nameEn
                ? _value.nameEn
                : nameEn // ignore: cast_nullable_to_non_nullable
                      as String,
            nameAr: freezed == nameAr
                ? _value.nameAr
                : nameAr // ignore: cast_nullable_to_non_nullable
                      as String?,
            requiredPlayers: null == requiredPlayers
                ? _value.requiredPlayers
                : requiredPlayers // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MeetupSportVariantImplCopyWith<$Res>
    implements $MeetupSportVariantCopyWith<$Res> {
  factory _$$MeetupSportVariantImplCopyWith(
    _$MeetupSportVariantImpl value,
    $Res Function(_$MeetupSportVariantImpl) then,
  ) = __$$MeetupSportVariantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'sport_id') String sportId,
    @JsonKey(name: 'variant_key') String? variantKey,
    @JsonKey(name: 'name_en') String nameEn,
    @JsonKey(name: 'name_ar') String? nameAr,
    @JsonKey(name: 'required_players') int requiredPlayers,
  });
}

/// @nodoc
class __$$MeetupSportVariantImplCopyWithImpl<$Res>
    extends _$MeetupSportVariantCopyWithImpl<$Res, _$MeetupSportVariantImpl>
    implements _$$MeetupSportVariantImplCopyWith<$Res> {
  __$$MeetupSportVariantImplCopyWithImpl(
    _$MeetupSportVariantImpl _value,
    $Res Function(_$MeetupSportVariantImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MeetupSportVariant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sportId = null,
    Object? variantKey = freezed,
    Object? nameEn = null,
    Object? nameAr = freezed,
    Object? requiredPlayers = null,
  }) {
    return _then(
      _$MeetupSportVariantImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        sportId: null == sportId
            ? _value.sportId
            : sportId // ignore: cast_nullable_to_non_nullable
                  as String,
        variantKey: freezed == variantKey
            ? _value.variantKey
            : variantKey // ignore: cast_nullable_to_non_nullable
                  as String?,
        nameEn: null == nameEn
            ? _value.nameEn
            : nameEn // ignore: cast_nullable_to_non_nullable
                  as String,
        nameAr: freezed == nameAr
            ? _value.nameAr
            : nameAr // ignore: cast_nullable_to_non_nullable
                  as String?,
        requiredPlayers: null == requiredPlayers
            ? _value.requiredPlayers
            : requiredPlayers // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MeetupSportVariantImpl implements _MeetupSportVariant {
  const _$MeetupSportVariantImpl({
    required this.id,
    @JsonKey(name: 'sport_id') required this.sportId,
    @JsonKey(name: 'variant_key') this.variantKey,
    @JsonKey(name: 'name_en') required this.nameEn,
    @JsonKey(name: 'name_ar') this.nameAr,
    @JsonKey(name: 'required_players') this.requiredPlayers = 1,
  });

  factory _$MeetupSportVariantImpl.fromJson(Map<String, dynamic> json) =>
      _$$MeetupSportVariantImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'sport_id')
  final String sportId;
  @override
  @JsonKey(name: 'variant_key')
  final String? variantKey;
  @override
  @JsonKey(name: 'name_en')
  final String nameEn;
  @override
  @JsonKey(name: 'name_ar')
  final String? nameAr;
  @override
  @JsonKey(name: 'required_players')
  final int requiredPlayers;

  @override
  String toString() {
    return 'MeetupSportVariant(id: $id, sportId: $sportId, variantKey: $variantKey, nameEn: $nameEn, nameAr: $nameAr, requiredPlayers: $requiredPlayers)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MeetupSportVariantImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sportId, sportId) || other.sportId == sportId) &&
            (identical(other.variantKey, variantKey) ||
                other.variantKey == variantKey) &&
            (identical(other.nameEn, nameEn) || other.nameEn == nameEn) &&
            (identical(other.nameAr, nameAr) || other.nameAr == nameAr) &&
            (identical(other.requiredPlayers, requiredPlayers) ||
                other.requiredPlayers == requiredPlayers));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    sportId,
    variantKey,
    nameEn,
    nameAr,
    requiredPlayers,
  );

  /// Create a copy of MeetupSportVariant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MeetupSportVariantImplCopyWith<_$MeetupSportVariantImpl> get copyWith =>
      __$$MeetupSportVariantImplCopyWithImpl<_$MeetupSportVariantImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MeetupSportVariantImplToJson(this);
  }
}

abstract class _MeetupSportVariant implements MeetupSportVariant {
  const factory _MeetupSportVariant({
    required final String id,
    @JsonKey(name: 'sport_id') required final String sportId,
    @JsonKey(name: 'variant_key') final String? variantKey,
    @JsonKey(name: 'name_en') required final String nameEn,
    @JsonKey(name: 'name_ar') final String? nameAr,
    @JsonKey(name: 'required_players') final int requiredPlayers,
  }) = _$MeetupSportVariantImpl;

  factory _MeetupSportVariant.fromJson(Map<String, dynamic> json) =
      _$MeetupSportVariantImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'sport_id')
  String get sportId;
  @override
  @JsonKey(name: 'variant_key')
  String? get variantKey;
  @override
  @JsonKey(name: 'name_en')
  String get nameEn;
  @override
  @JsonKey(name: 'name_ar')
  String? get nameAr;
  @override
  @JsonKey(name: 'required_players')
  int get requiredPlayers;

  /// Create a copy of MeetupSportVariant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MeetupSportVariantImplCopyWith<_$MeetupSportVariantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
