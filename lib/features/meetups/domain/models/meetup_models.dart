import 'package:freezed_annotation/freezed_annotation.dart';

import 'meetup_enums.dart';

part 'meetup_models.freezed.dart';
part 'meetup_models.g.dart';

/// One row of `v_meetup_list`. `creator_user_id` is deliberately NOT modelled
/// (SEC-17: WP1 removes it from the view); `creator_profile_id` stays.
@freezed
abstract class MeetupListItem with _$MeetupListItem {
  const MeetupListItem._();

  const factory MeetupListItem({
    required String id,
    required String title,
    String? description,
    @JsonKey(name: 'start_at') required DateTime startAt,
    @JsonKey(name: 'end_at') DateTime? endAt,
    int? capacity,
    @JsonKey(name: 'members_only') @Default(false) bool membersOnly,
    @JsonKey(name: 'listing_visibility') @Default('public') String listingVisibility,
    @JsonKey(name: 'rsvp_policy', unknownEnumValue: RsvpPolicy.closed)
    @Default(RsvpPolicy.closed)
    RsvpPolicy rsvpPolicy,
    @JsonKey(name: 'is_cancelled') @Default(false) bool isCancelled,
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
    @JsonKey(name: 'joining_rule') @Default('free') String joiningRule,
    @JsonKey(name: 'cost_cover') @Default('free') String costCover,
    @JsonKey(name: 'going_count') @Default(0) int goingCount,
    @JsonKey(name: 'interested_count') @Default(0) int interestedCount,
    @JsonKey(name: 'declined_count') @Default(0) int declinedCount,
    // Legacy meetup_attendees status (going/interested/declined) for the
    // caller's player actor; null when no RSVP.
    @JsonKey(name: 'my_rsvp_status') String? myRsvpStatus,
  }) = _MeetupListItem;

  factory MeetupListItem.fromJson(Map<String, dynamic> json) =>
      _$MeetupListItemFromJson(json);

  /// Soft capacity: full means a "going" RSVP is stored as "interested".
  bool get isFull => capacity != null && goingCount >= capacity!;

  MeetupLifecycle lifecycle(DateTime now) => isCancelled
      ? MeetupLifecycle.cancelled
      : (startAt.isAfter(now) ? MeetupLifecycle.upcoming : MeetupLifecycle.started);
}

/// One row of `getnearbymeetups(p_lat, p_lng, p_radius)`.
@freezed
abstract class NearbyMeetup with _$NearbyMeetup {
  const factory NearbyMeetup({
    required String id,
    required String title,
    @JsonKey(name: 'starts_at') DateTime? startsAt,
    double? lat,
    double? lng,
    @JsonKey(name: 'areaid') String? areaId,
    @JsonKey(name: 'distance_m') double? distanceM,
  }) = _NearbyMeetup;

  factory NearbyMeetup.fromJson(Map<String, dynamic> json) =>
      _$NearbyMeetupFromJson(json);
}

@freezed
abstract class MeetupHost with _$MeetupHost {
  const factory MeetupHost({
    @JsonKey(name: 'actor_profile_id') String? actorProfileId,
    @JsonKey(name: 'display_name') String? displayName,
    String? username,
  }) = _MeetupHost;

  factory MeetupHost.fromJson(Map<String, dynamic> json) =>
      _$MeetupHostFromJson(json);
}

@freezed
abstract class MeetupCounts with _$MeetupCounts {
  const factory MeetupCounts({
    @Default(0) int going,
    @Default(0) int interested,
    @Default(0) int declined,
  }) = _MeetupCounts;

  factory MeetupCounts.fromJson(Map<String, dynamic> json) =>
      _$MeetupCountsFromJson(json);
}

/// jsonb returned by `rpc_meetup_card`. Shape per the baseline body; the body
/// reads columns the baseline table lacks (see KAN-428 open questions), so
/// every field except [id] is optional.
@freezed
abstract class MeetupCard with _$MeetupCard {
  const factory MeetupCard({
    required String id,
    String? title,
    @JsonKey(name: 'start_at') DateTime? startAt,
    String? visibility,
    @JsonKey(name: 'owner_user_id') String? ownerUserId,
    @JsonKey(name: 'owner_profile_id') String? ownerProfileId,
    MeetupHost? host,
    @Default(MeetupCounts()) MeetupCounts counts,
    @JsonKey(name: 'my_status') String? myStatus,
  }) = _MeetupCard;

  factory MeetupCard.fromJson(Map<String, dynamic> json) =>
      _$MeetupCardFromJson(json);
}

/// One row of `rpc_meetup_attendees` (reads legacy `meetup_attendees`).
@freezed
abstract class MeetupAttendee with _$MeetupAttendee {
  const factory MeetupAttendee({
    @JsonKey(name: 'actor_profile_id') required String actorProfileId,
    @JsonKey(name: 'display_name') String? displayName,
    String? username,
    @JsonKey(unknownEnumValue: RsvpStatus.unknown)
    @Default(RsvpStatus.unknown)
    RsvpStatus status,
  }) = _MeetupAttendee;

  factory MeetupAttendee.fromJson(Map<String, dynamic> json) =>
      _$MeetupAttendeeFromJson(json);
}

/// jsonb returned by `can_current_user_rsvp_meetup`:
/// {allowed: bool, cta: text, reason?: text}.
@freezed
abstract class RsvpEligibility with _$RsvpEligibility {
  const factory RsvpEligibility({
    @Default(false) bool allowed,
    @JsonKey(fromJson: _ctaFromJson, toJson: _ctaToJson)
    @Default(RsvpCta.notAllowed)
    RsvpCta cta,
    String? reason,
  }) = _RsvpEligibility;

  factory RsvpEligibility.fromJson(Map<String, dynamic> json) =>
      _$RsvpEligibilityFromJson(json);
}

RsvpCta _ctaFromJson(Object? v) => RsvpCta.fromDb(v);
String _ctaToJson(RsvpCta c) => c.dbValue;

/// A solo-friendly sport for the composer (`sports` where can_solo = true).
@freezed
abstract class MeetupSport with _$MeetupSport {
  const factory MeetupSport({
    required String id,
    @JsonKey(name: 'sport_key') String? sportKey,
    @JsonKey(name: 'name_en') required String nameEn,
    @JsonKey(name: 'name_ar') String? nameAr,
    String? emoji,
  }) = _MeetupSport;

  factory MeetupSport.fromJson(Map<String, dynamic> json) =>
      _$MeetupSportFromJson(json);
}

/// `rpc_create_meetup` requires a sport variant (validates it belongs to the
/// sport); the composer picks one from `sport_variants`.
@freezed
abstract class MeetupSportVariant with _$MeetupSportVariant {
  const factory MeetupSportVariant({
    required String id,
    @JsonKey(name: 'sport_id') required String sportId,
    @JsonKey(name: 'variant_key') String? variantKey,
    @JsonKey(name: 'name_en') required String nameEn,
    @JsonKey(name: 'name_ar') String? nameAr,
    @JsonKey(name: 'required_players') @Default(1) int requiredPlayers,
  }) = _MeetupSportVariant;

  factory MeetupSportVariant.fromJson(Map<String, dynamic> json) =>
      _$MeetupSportVariantFromJson(json);
}
