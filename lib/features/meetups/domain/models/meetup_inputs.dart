/// Input for `rpc_create_meetup`. v1 is public + free only: those are fixed by
/// the datasource, not caller-controlled.
class CreateMeetupInput {
  const CreateMeetupInput({
    required this.sportId,
    required this.sportVariantId,
    required this.title,
    required this.locationName,
    required this.startAt,
    this.description,
    this.venueId,
    this.geoLocationId,
    this.areaId,
    this.endAt,
    this.capacity,
    this.rsvpPolicy = 'open',
    this.minSkill,
    this.maxSkill,
    this.vibeKey,
  });

  final String sportId;
  final String sportVariantId;
  final String title;
  final String locationName;
  final DateTime startAt;
  final String? description;
  final String? venueId;
  final String? geoLocationId;
  final String? areaId;
  final DateTime? endAt;
  final int? capacity;

  /// open | request | closed (db values of RsvpPolicy).
  final String rsvpPolicy;

  /// 1-10 skill bounds, both or neither.
  final int? minSkill;
  final int? maxSkill;

  /// A `DabblerVibe.key`.
  final String? vibeKey;
}

/// Input for `rpc_meetup_update`. Null = unchanged (the RPC cannot clear
/// description, end time or capacity).
class UpdateMeetupInput {
  const UpdateMeetupInput({
    required this.meetupId,
    this.title,
    this.description,
    this.startAt,
    this.endAt,
    this.locationName,
    this.capacity,
  });

  final String meetupId;
  final String? title;
  final String? description;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? locationName;
  final int? capacity;
}
