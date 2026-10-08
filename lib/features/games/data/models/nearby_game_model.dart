/// A nearby game row returned by the `rpc_get_nearby_games` PostGIS RPC.
///
/// Plain Dart class (no Freezed) matching the pattern in [NearbyVenueModel].
/// Distance is always present because the RPC computes it.
class NearbyGameModel {
  const NearbyGameModel({
    required this.id,
    required this.title,
    this.sportName,
    this.scheduledAt,
    this.status,
    this.venueName,
    this.latitude,
    this.longitude,
    required this.distanceMeters,
    this.playerCount,
    this.spotsRemaining,
    required this.isPublic,
    this.isCreated = false,
    this.isJoined = false,
    this.minSkill,
    this.maxSkill,
    this.endAt,
    this.variantNameEn,
    this.variantNameAr,
    this.hostVerified = false,
    this.favoriteCount = 0,
    this.favouritedByMe = false,
    this.priceAed,
    this.followingJoined = 0,
  });

  final String id;
  final String title;
  final String? sportName;
  final DateTime? scheduledAt;

  /// One of: 'upcoming', 'live', 'ended'  (computed by the RPC).
  final String? status;
  final String? venueName;
  final double? latitude;
  final double? longitude;

  /// Straight-line distance in metres from the query origin.
  final double distanceMeters;
  final int? playerCount;
  final int? spotsRemaining;
  final bool isPublic;

  /// Viewer-relative flags from v_game_card (is_creator / is_joined) —
  /// drive the pinned "My games" section. Always false on the RPC path,
  /// which doesn't return them.
  final bool isCreated;
  final bool isJoined;

  /// Skill range (1-10) the game targets; null = open to any level.
  final int? minSkill;
  final int? maxSkill;

  /// When the game ends; with [scheduledAt] gives its length.
  final DateTime? endAt;

  /// The format (`sport_variants.name_en/ar`) — `Futsal 5s`, `Doubles`.
  final String? variantNameEn;
  final String? variantNameAr;

  /// The host is verified (profile or organiser for the sport), from the DB.
  final bool hostVerified;

  /// How many profiles favourited the game, and whether the viewer did.
  final int favoriteCount;
  final bool favouritedByMe;

  /// The price per player in AED (`games.price_aed`): above 0 it is the price,
  /// 0 is "Free", null (a game made before the price became required) is "Ask".
  final double? priceAed;
  /// How many people the viewer follows are in this game; 0 when none or
  /// unknown. Not part of the listing rows: merged in after they load.
  final int followingJoined;

  bool get isMine => isCreated || isJoined;

  /// The game's length in whole minutes, or null without a valid end.
  int? get durationMinutes {
    final s = scheduledAt, e = endAt;
    if (s == null || e == null || !e.isAfter(s)) return null;
    return e.difference(s).inMinutes;
  }

  /// The format in [languageCode], falling back to English.
  String? formatName(String languageCode) {
    final ar = variantNameAr;
    if (languageCode == 'ar' && ar != null && ar.isNotEmpty) return ar;
    final en = variantNameEn;
    return en != null && en.isNotEmpty ? en : null;
  }

  /// This game with its favourite state replaced.
  NearbyGameModel withFavourite({
    required bool favourited,
    required int count,
  }) => NearbyGameModel(
    id: id,
    title: title,
    sportName: sportName,
    scheduledAt: scheduledAt,
    status: status,
    venueName: venueName,
    latitude: latitude,
    longitude: longitude,
    distanceMeters: distanceMeters,
    playerCount: playerCount,
    spotsRemaining: spotsRemaining,
    isPublic: isPublic,
    isCreated: isCreated,
    isJoined: isJoined,
    minSkill: minSkill,
    maxSkill: maxSkill,
    endAt: endAt,
    variantNameEn: variantNameEn,
    variantNameAr: variantNameAr,
    hostVerified: hostVerified,
    favoriteCount: count,
    favouritedByMe: favourited,
    priceAed: priceAed,
    followingJoined: followingJoined,
  );

  /// This game with [count] people the viewer follows in it (the card's
  /// "N following" note; `rpc_games_following_joined`, merged client side).
  NearbyGameModel withFollowing(int count) => count == followingJoined
      ? this
      : NearbyGameModel(
          id: id,
          title: title,
          sportName: sportName,
          scheduledAt: scheduledAt,
          status: status,
          venueName: venueName,
          latitude: latitude,
          longitude: longitude,
          distanceMeters: distanceMeters,
          playerCount: playerCount,
          spotsRemaining: spotsRemaining,
          isPublic: isPublic,
          isCreated: isCreated,
          isJoined: isJoined,
          minSkill: minSkill,
          maxSkill: maxSkill,
          endAt: endAt,
          variantNameEn: variantNameEn,
          variantNameAr: variantNameAr,
          hostVerified: hostVerified,
          favoriteCount: favoriteCount,
          favouritedByMe: favouritedByMe,
          priceAed: priceAed,
          followingJoined: count,
        );

  factory NearbyGameModel.fromJson(Map<String, dynamic> json) {
    return NearbyGameModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Game',
      sportName: json['sport_name'] as String?,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'] as String)
          : null,
      status: json['status'] as String?,
      venueName: json['venue_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      playerCount: json['player_count'] as int?,
      spotsRemaining: json['spots_remaining'] as int?,
      isPublic: json['is_public'] as bool? ?? true,
      isCreated: json['is_creator'] as bool? ?? false,
      isJoined: json['is_joined'] as bool? ?? false,
      minSkill: json['min_skill'] as int?,
      maxSkill: json['max_skill'] as int?,
      endAt: json['end_at'] != null
          ? DateTime.tryParse(json['end_at'] as String)
          : null,
      variantNameEn: json['variant_name_en'] as String?,
      variantNameAr: json['variant_name_ar'] as String?,
      hostVerified: json['host_verified'] as bool? ?? false,
      favoriteCount: (json['favorite_count'] as num?)?.toInt() ?? 0,
      favouritedByMe: json['favourited_by_me'] as bool? ?? false,
      priceAed: (json['price_aed'] as num?)?.toDouble(),
    );
  }

  /// Formatted distance label: "850 m" or "1.2 km".
  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    final km = distanceMeters / 1000;
    final formatted = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
    return '$formatted km';
  }
}
