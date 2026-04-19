/// Holds all data collected across the 5-step game creation flow.
class GameCreationState {
  // Pre-loaded (before Screen 1)
  final String sportId;
  final String sportKey;
  final String sportNameEn;
  final String sportEmoji;
  final String? sportVariantId;
  final int requiredPlayers;
  final int playersPerSide;

  // Screen 1
  final String? gameType; // casual | competitive | tournament | friendly
  final String? title;

  // Screen 2
  final DateTime? startAt;
  final DateTime? endAt;
  final String? venueSpaceId;
  final String? venueId;
  final String? venueName;
  final String? venueSpaceName;
  final String? geoLocationId;
  final String? areaId;
  final double? lat;
  final double? lng;
  final String? joiningRule; // free | members_only | paid
  final String? costCover;
  final bool creatorAbsorbsCost;

  // Screen 3
  final int benchSlots;
  final String? squadId;
  final bool allowSpectators;

  // Screen 4
  final String? listingVisibility; // public | friends | private | link
  final String? joinPolicy; // open | request | invite | link
  final int? minSkill;
  final int? maxSkill;
  final bool allowsWaitlist;

  // Screen 5
  final String? rules;
  final Map<String, dynamic>? sportSpecificData;

  const GameCreationState({
    required this.sportId,
    required this.sportKey,
    required this.sportNameEn,
    required this.sportEmoji,
    this.sportVariantId,
    this.requiredPlayers = 0,
    this.playersPerSide = 0,
    this.gameType,
    this.title,
    this.startAt,
    this.endAt,
    this.venueSpaceId,
    this.venueId,
    this.venueName,
    this.venueSpaceName,
    this.geoLocationId,
    this.areaId,
    this.lat,
    this.lng,
    this.joiningRule,
    this.costCover,
    this.creatorAbsorbsCost = false,
    this.benchSlots = 0,
    this.squadId,
    this.allowSpectators = false,
    this.listingVisibility,
    this.joinPolicy,
    this.minSkill,
    this.maxSkill,
    this.allowsWaitlist = false,
    this.rules,
    this.sportSpecificData,
  });

  GameCreationState copyWith({
    String? sportId,
    String? sportKey,
    String? sportNameEn,
    String? sportEmoji,
    Object? sportVariantId = _sentinel,
    int? requiredPlayers,
    int? playersPerSide,
    Object? gameType = _sentinel,
    Object? title = _sentinel,
    Object? startAt = _sentinel,
    Object? endAt = _sentinel,
    Object? venueSpaceId = _sentinel,
    Object? venueId = _sentinel,
    Object? venueName = _sentinel,
    Object? venueSpaceName = _sentinel,
    Object? geoLocationId = _sentinel,
    Object? areaId = _sentinel,
    Object? lat = _sentinel,
    Object? lng = _sentinel,
    Object? joiningRule = _sentinel,
    Object? costCover = _sentinel,
    bool? creatorAbsorbsCost,
    int? benchSlots,
    Object? squadId = _sentinel,
    bool? allowSpectators,
    Object? listingVisibility = _sentinel,
    Object? joinPolicy = _sentinel,
    Object? minSkill = _sentinel,
    Object? maxSkill = _sentinel,
    bool? allowsWaitlist,
    Object? rules = _sentinel,
    Object? sportSpecificData = _sentinel,
  }) {
    return GameCreationState(
      sportId: sportId ?? this.sportId,
      sportKey: sportKey ?? this.sportKey,
      sportNameEn: sportNameEn ?? this.sportNameEn,
      sportEmoji: sportEmoji ?? this.sportEmoji,
      sportVariantId: sportVariantId == _sentinel
          ? this.sportVariantId
          : sportVariantId as String?,
      requiredPlayers: requiredPlayers ?? this.requiredPlayers,
      playersPerSide: playersPerSide ?? this.playersPerSide,
      gameType:
          gameType == _sentinel ? this.gameType : gameType as String?,
      title: title == _sentinel ? this.title : title as String?,
      startAt:
          startAt == _sentinel ? this.startAt : startAt as DateTime?,
      endAt: endAt == _sentinel ? this.endAt : endAt as DateTime?,
      venueSpaceId: venueSpaceId == _sentinel
          ? this.venueSpaceId
          : venueSpaceId as String?,
      venueId:
          venueId == _sentinel ? this.venueId : venueId as String?,
      venueName:
          venueName == _sentinel ? this.venueName : venueName as String?,
      venueSpaceName: venueSpaceName == _sentinel
          ? this.venueSpaceName
          : venueSpaceName as String?,
      geoLocationId: geoLocationId == _sentinel
          ? this.geoLocationId
          : geoLocationId as String?,
      areaId:
          areaId == _sentinel ? this.areaId : areaId as String?,
      lat: lat == _sentinel ? this.lat : lat as double?,
      lng: lng == _sentinel ? this.lng : lng as double?,
      joiningRule: joiningRule == _sentinel
          ? this.joiningRule
          : joiningRule as String?,
      costCover:
          costCover == _sentinel ? this.costCover : costCover as String?,
      creatorAbsorbsCost:
          creatorAbsorbsCost ?? this.creatorAbsorbsCost,
      benchSlots: benchSlots ?? this.benchSlots,
      squadId:
          squadId == _sentinel ? this.squadId : squadId as String?,
      allowSpectators: allowSpectators ?? this.allowSpectators,
      listingVisibility: listingVisibility == _sentinel
          ? this.listingVisibility
          : listingVisibility as String?,
      joinPolicy:
          joinPolicy == _sentinel ? this.joinPolicy : joinPolicy as String?,
      minSkill: minSkill == _sentinel ? this.minSkill : minSkill as int?,
      maxSkill: maxSkill == _sentinel ? this.maxSkill : maxSkill as int?,
      allowsWaitlist: allowsWaitlist ?? this.allowsWaitlist,
      rules: rules == _sentinel ? this.rules : rules as String?,
      sportSpecificData: sportSpecificData == _sentinel
          ? this.sportSpecificData
          : sportSpecificData as Map<String, dynamic>?,
    );
  }
}

// Sentinel object for nullable copyWith
const Object _sentinel = Object();
