// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meetup_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MeetupListItemImpl _$$MeetupListItemImplFromJson(Map<String, dynamic> json) =>
    _$MeetupListItemImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: json['end_at'] == null
          ? null
          : DateTime.parse(json['end_at'] as String),
      capacity: (json['capacity'] as num?)?.toInt(),
      membersOnly: json['members_only'] as bool? ?? false,
      listingVisibility: json['listing_visibility'] as String? ?? 'public',
      rsvpPolicy:
          $enumDecodeNullable(
            _$RsvpPolicyEnumMap,
            json['rsvp_policy'],
            unknownValue: RsvpPolicy.closed,
          ) ??
          RsvpPolicy.closed,
      isCancelled: json['is_cancelled'] as bool? ?? false,
      vibeKey: json['vibe_key'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      creatorProfileId: json['creator_profile_id'] as String?,
      creatorDisplayName: json['creator_display_name'] as String?,
      creatorUsername: json['creator_username'] as String?,
      creatorAvatarUrl: json['creator_avatar_url'] as String?,
      sportId: json['sport_id'] as String?,
      sportKey: json['sport_key'] as String?,
      sportNameEn: json['sport_name_en'] as String?,
      sportNameAr: json['sport_name_ar'] as String?,
      sportEmoji: json['sport_emoji'] as String?,
      areaId: json['area_id'] as String?,
      areaName: json['area_name'] as String?,
      venueId: json['venue_id'] as String?,
      venueName: json['venue_name'] as String?,
      locationName: json['location_name'] as String?,
      geoLocationId: json['geo_location_id'] as String?,
      minSkill: (json['min_skill'] as num?)?.toInt(),
      maxSkill: (json['max_skill'] as num?)?.toInt(),
      joiningRule: json['joining_rule'] as String? ?? 'free',
      costCover: json['cost_cover'] as String? ?? 'free',
      goingCount: (json['going_count'] as num?)?.toInt() ?? 0,
      interestedCount: (json['interested_count'] as num?)?.toInt() ?? 0,
      declinedCount: (json['declined_count'] as num?)?.toInt() ?? 0,
      myRsvpStatus: json['my_rsvp_status'] as String?,
      attendeeAvatars:
          (json['attendee_avatars'] as List<dynamic>?)
              ?.map((e) => MeetupAvatar.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <MeetupAvatar>[],
    );

Map<String, dynamic> _$$MeetupListItemImplToJson(
  _$MeetupListItemImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'start_at': instance.startAt.toIso8601String(),
  'end_at': instance.endAt?.toIso8601String(),
  'capacity': instance.capacity,
  'members_only': instance.membersOnly,
  'listing_visibility': instance.listingVisibility,
  'rsvp_policy': _$RsvpPolicyEnumMap[instance.rsvpPolicy]!,
  'is_cancelled': instance.isCancelled,
  'vibe_key': instance.vibeKey,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
  'creator_profile_id': instance.creatorProfileId,
  'creator_display_name': instance.creatorDisplayName,
  'creator_username': instance.creatorUsername,
  'creator_avatar_url': instance.creatorAvatarUrl,
  'sport_id': instance.sportId,
  'sport_key': instance.sportKey,
  'sport_name_en': instance.sportNameEn,
  'sport_name_ar': instance.sportNameAr,
  'sport_emoji': instance.sportEmoji,
  'area_id': instance.areaId,
  'area_name': instance.areaName,
  'venue_id': instance.venueId,
  'venue_name': instance.venueName,
  'location_name': instance.locationName,
  'geo_location_id': instance.geoLocationId,
  'min_skill': instance.minSkill,
  'max_skill': instance.maxSkill,
  'joining_rule': instance.joiningRule,
  'cost_cover': instance.costCover,
  'going_count': instance.goingCount,
  'interested_count': instance.interestedCount,
  'declined_count': instance.declinedCount,
  'my_rsvp_status': instance.myRsvpStatus,
  'attendee_avatars': instance.attendeeAvatars,
};

const _$RsvpPolicyEnumMap = {
  RsvpPolicy.open: 'open',
  RsvpPolicy.request: 'request',
  RsvpPolicy.closed: 'closed',
};

_$NearbyMeetupImpl _$$NearbyMeetupImplFromJson(Map<String, dynamic> json) =>
    _$NearbyMeetupImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      startsAt: json['starts_at'] == null
          ? null
          : DateTime.parse(json['starts_at'] as String),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      areaId: json['areaid'] as String?,
      distanceM: (json['distance_m'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$NearbyMeetupImplToJson(_$NearbyMeetupImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'starts_at': instance.startsAt?.toIso8601String(),
      'lat': instance.lat,
      'lng': instance.lng,
      'areaid': instance.areaId,
      'distance_m': instance.distanceM,
    };

_$MeetupAvatarImpl _$$MeetupAvatarImplFromJson(Map<String, dynamic> json) =>
    _$MeetupAvatarImpl(
      avatarUrl: json['avatar_url'] as String?,
      displayName: json['display_name'] as String?,
    );

Map<String, dynamic> _$$MeetupAvatarImplToJson(_$MeetupAvatarImpl instance) =>
    <String, dynamic>{
      'avatar_url': instance.avatarUrl,
      'display_name': instance.displayName,
    };

_$MeetupHostImpl _$$MeetupHostImplFromJson(Map<String, dynamic> json) =>
    _$MeetupHostImpl(
      actorProfileId: json['actor_profile_id'] as String?,
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );

Map<String, dynamic> _$$MeetupHostImplToJson(_$MeetupHostImpl instance) =>
    <String, dynamic>{
      'actor_profile_id': instance.actorProfileId,
      'display_name': instance.displayName,
      'username': instance.username,
      'avatar_url': instance.avatarUrl,
    };

_$MeetupCountsImpl _$$MeetupCountsImplFromJson(Map<String, dynamic> json) =>
    _$MeetupCountsImpl(
      going: (json['going'] as num?)?.toInt() ?? 0,
      interested: (json['interested'] as num?)?.toInt() ?? 0,
      declined: (json['declined'] as num?)?.toInt() ?? 0,
      pending: (json['pending'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$MeetupCountsImplToJson(_$MeetupCountsImpl instance) =>
    <String, dynamic>{
      'going': instance.going,
      'interested': instance.interested,
      'declined': instance.declined,
      'pending': instance.pending,
    };

_$MeetupCardImpl _$$MeetupCardImplFromJson(Map<String, dynamic> json) =>
    _$MeetupCardImpl(
      id: json['id'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      startAt: json['start_at'] == null
          ? null
          : DateTime.parse(json['start_at'] as String),
      endAt: json['end_at'] == null
          ? null
          : DateTime.parse(json['end_at'] as String),
      locationName: json['location_name'] as String?,
      capacity: (json['capacity'] as num?)?.toInt(),
      isCancelled: json['is_cancelled'] as bool? ?? false,
      isHost: json['is_host'] as bool? ?? false,
      visibility: json['visibility'] as String?,
      ownerProfileId: json['owner_profile_id'] as String?,
      host: json['host'] == null
          ? null
          : MeetupHost.fromJson(json['host'] as Map<String, dynamic>),
      counts: json['counts'] == null
          ? const MeetupCounts()
          : MeetupCounts.fromJson(json['counts'] as Map<String, dynamic>),
      myStatus: json['my_status'] as String?,
      sportKey: json['sport_key'] as String?,
      sportNameEn: json['sport_name_en'] as String?,
      sportNameAr: json['sport_name_ar'] as String?,
      minSkill: (json['min_skill'] as num?)?.toInt(),
      maxSkill: (json['max_skill'] as num?)?.toInt(),
      areaName: json['area_name'] as String?,
      venueName: json['venue_name'] as String?,
      attendees:
          (json['attendees'] as List<dynamic>?)
              ?.map((e) => MeetupAvatar.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <MeetupAvatar>[],
    );

Map<String, dynamic> _$$MeetupCardImplToJson(_$MeetupCardImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'start_at': instance.startAt?.toIso8601String(),
      'end_at': instance.endAt?.toIso8601String(),
      'location_name': instance.locationName,
      'capacity': instance.capacity,
      'is_cancelled': instance.isCancelled,
      'is_host': instance.isHost,
      'visibility': instance.visibility,
      'owner_profile_id': instance.ownerProfileId,
      'host': instance.host,
      'counts': instance.counts,
      'my_status': instance.myStatus,
      'sport_key': instance.sportKey,
      'sport_name_en': instance.sportNameEn,
      'sport_name_ar': instance.sportNameAr,
      'min_skill': instance.minSkill,
      'max_skill': instance.maxSkill,
      'area_name': instance.areaName,
      'venue_name': instance.venueName,
      'attendees': instance.attendees,
    };

_$MeetupAttendeeImpl _$$MeetupAttendeeImplFromJson(Map<String, dynamic> json) =>
    _$MeetupAttendeeImpl(
      actorProfileId: json['actor_profile_id'] as String?,
      displayName: json['display_name'] as String?,
      username: json['username'] as String?,
      status:
          $enumDecodeNullable(
            _$RsvpStatusEnumMap,
            json['status'],
            unknownValue: RsvpStatus.unknown,
          ) ??
          RsvpStatus.unknown,
    );

Map<String, dynamic> _$$MeetupAttendeeImplToJson(
  _$MeetupAttendeeImpl instance,
) => <String, dynamic>{
  'actor_profile_id': instance.actorProfileId,
  'display_name': instance.displayName,
  'username': instance.username,
  'status': _$RsvpStatusEnumMap[instance.status]!,
};

const _$RsvpStatusEnumMap = {
  RsvpStatus.going: 'going',
  RsvpStatus.interested: 'interested',
  RsvpStatus.pending: 'pending',
  RsvpStatus.declined: 'declined',
  RsvpStatus.cancelled: 'cancelled',
  RsvpStatus.unknown: 'unknown',
};

_$RsvpEligibilityImpl _$$RsvpEligibilityImplFromJson(
  Map<String, dynamic> json,
) => _$RsvpEligibilityImpl(
  allowed: json['allowed'] as bool? ?? false,
  cta: json['cta'] == null ? RsvpCta.notAllowed : _ctaFromJson(json['cta']),
  reason: json['reason'] as String?,
);

Map<String, dynamic> _$$RsvpEligibilityImplToJson(
  _$RsvpEligibilityImpl instance,
) => <String, dynamic>{
  'allowed': instance.allowed,
  'cta': _ctaToJson(instance.cta),
  'reason': instance.reason,
};

_$MeetupSportImpl _$$MeetupSportImplFromJson(Map<String, dynamic> json) =>
    _$MeetupSportImpl(
      id: json['id'] as String,
      sportKey: json['sport_key'] as String?,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String?,
      emoji: json['emoji'] as String?,
    );

Map<String, dynamic> _$$MeetupSportImplToJson(_$MeetupSportImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sport_key': instance.sportKey,
      'name_en': instance.nameEn,
      'name_ar': instance.nameAr,
      'emoji': instance.emoji,
    };

_$MeetupSportVariantImpl _$$MeetupSportVariantImplFromJson(
  Map<String, dynamic> json,
) => _$MeetupSportVariantImpl(
  id: json['id'] as String,
  sportId: json['sport_id'] as String,
  variantKey: json['variant_key'] as String?,
  nameEn: json['name_en'] as String,
  nameAr: json['name_ar'] as String?,
  requiredPlayers: (json['required_players'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$$MeetupSportVariantImplToJson(
  _$MeetupSportVariantImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'sport_id': instance.sportId,
  'variant_key': instance.variantKey,
  'name_en': instance.nameEn,
  'name_ar': instance.nameAr,
  'required_players': instance.requiredPlayers,
};
