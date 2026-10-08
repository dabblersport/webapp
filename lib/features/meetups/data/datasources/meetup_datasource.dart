import '../../domain/models/meetup_inputs.dart';

/// Pure parameter builders: the exact keys sent to each RPC. Kept separate so
/// tests can assert the wire contract without a client.
class MeetupRpcParams {
  const MeetupRpcParams._();

  /// v1 is free + public only; those are fixed here, never caller-controlled.
  /// The retired rpc_meetup_create overloads are never used.
  static Map<String, dynamic> create(
    CreateMeetupInput i, {
    String actorType = 'organiser',
  }) => {
    'p_actor_type': actorType,
    'p_sport_id': i.sportId,
    'p_sport_variant_id': i.sportVariantId,
    'p_title': i.title,
    'p_description': i.description,
    'p_venue_id': i.venueId,
    'p_location_name': i.locationName,
    'p_geo_location_id': i.geoLocationId,
    'p_area_id': i.areaId,
    'p_start_at': i.startAt.toUtc().toIso8601String(),
    'p_end_at': i.endAt?.toUtc().toIso8601String(),
    'p_capacity': i.capacity,
    'p_listing_visibility': 'public',
    'p_rsvp_policy': i.rsvpPolicy,
    'p_members_only': false,
    'p_min_skill': i.minSkill,
    'p_max_skill': i.maxSkill,
    'p_vibe_key': i.vibeKey,
    'p_is_indoor': i.venueId == null ? i.isIndoor : null,
  };

  static Map<String, dynamic> rsvp(
    String meetupId,
    String action, {
    String? profileId,
  }) => {
    'p_meetup_id': meetupId,
    'p_action': action,
    'p_profile_id': profileId,
  };

  static Map<String, dynamic> cancel(String meetupId) => {
    'p_meetup_id': meetupId,
  };

  static Map<String, dynamic> card(String meetupId, String profileType) => {
    'p_meetup_id': meetupId,
    'p_profile_type': profileType,
  };

  static Map<String, dynamic> attendees(
    String meetupId, {
    String? status,
    int limit = 50,
    int offset = 0,
  }) => {
    'p_meetup_id': meetupId,
    'p_status': status,
    'p_limit': limit,
    'p_offset': offset,
  };

  static Map<String, dynamic> nearby(double lat, double lng, double radius) => {
    'p_lat': lat,
    'p_lng': lng,
    'p_radius': radius,
  };

  static Map<String, dynamic> decideRequest(
    String meetupId,
    String userId,
    String decision,
  ) => {'p_meetup_id': meetupId, 'p_user_id': userId, 'p_decision': decision};

  static Map<String, dynamic> removeAttendee(String meetupId, String userId) =>
      {'p_meetup_id': meetupId, 'p_user_id': userId};

  static Map<String, dynamic> canCreate(String actorProfileId) => {
    'p_actor': actorProfileId,
  };

  static Map<String, dynamic> canRsvp(String meetupId) => {
    'p_meetup_id': meetupId,
  };

  static Map<String, dynamic> update(UpdateMeetupInput i) => {
    'p_meetup_id': i.meetupId,
    'p_title': i.title,
    'p_description': i.description,
    'p_start_at': i.startAt?.toUtc().toIso8601String(),
    'p_end_at': i.endAt?.toUtc().toIso8601String(),
    'p_location_name': i.locationName,
    'p_capacity': i.capacity,
  };
}

abstract class MeetupDataSource {
  Future<List<Map<String, dynamic>>> fetchMeetupList({
    String? sportId,
    required int limit,
    required int offset,
  });
  Future<List<Map<String, dynamic>>> nearby(
    double lat,
    double lng,
    double radius,
  );
  Future<Map<String, dynamic>> card(String meetupId, String profileType);
  Future<List<Map<String, dynamic>>> attendees(
    String meetupId, {
    String? status,
    required int limit,
    required int offset,
  });
  Future<Map<String, dynamic>> canRsvp(String meetupId);
  Future<bool> canCreate(String actorProfileId);
  Future<List<Map<String, dynamic>>> soloSports();
  Future<List<Map<String, dynamic>>> sportVariants(String sportId);
  Future<String> create(CreateMeetupInput input, {required String actorType});
  Future<String> rsvp(String meetupId, String action, {String? profileId});
  Future<void> cancel(String meetupId);
  Future<Map<String, dynamic>> update(UpdateMeetupInput input);
  Future<String> decideRequest(String meetupId, String userId, String decision);
  Future<String> removeAttendee(String meetupId, String userId);
}
