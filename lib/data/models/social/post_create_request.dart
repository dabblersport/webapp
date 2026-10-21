import 'package:dabbler/data/models/social/post_enums.dart';

/// Immutable request DTO for creating a new post.
///
/// Maps 1:1 to the `posts` table columns. The repository resolves
/// `author_profile_id` and `author_user_id` from the current session,
/// so they are intentionally excluded from this request class.
class PostCreateRequest {
  const PostCreateRequest({
    this.kind = PostKind.original,
    required this.visibility,
    this.postType = PostType.dab,
    this.body,
    this.lang,
    this.media,
    this.tags,
    this.vibeId,
    this.sportId,
    this.venueId,
    this.locationTagId,
    this.areaId,
    this.locationName,
    this.postedFromCity,
    this.postedFromArea,
    this.geoLat,
    this.geoLng,
    this.linkToken,
    this.allowReposts = true,
    this.expiresAt,
    this.originType = OriginType.manual,
    this.contentClass = 'social',
    this.circleId,
    this.squadId,
    this.gameId,
    this.originId,
    this.personaTypeSnapshot,
    this.isPinned = false,
    this.requestId,
  });

  /// Required — the kind of post (original, news, announcement, etc.).
  final PostKind kind;

  /// Layout/behavior type — defaults to dab.
  final PostType postType;

  /// Required — visibility level.
  final PostVisibility visibility;

  /// Post body text (optional but recommended).
  final String? body;

  /// ISO 639-1 language code, auto-detected before insert.
  final String? lang;

  /// Media attachments as JSON-serializable list.
  final List<dynamic>? media;

  /// Hashtags extracted from body.
  final List<String>? tags;

  /// Selected vibe UUID (optional).
  final String? vibeId;

  /// Selected sport UUID (optional).
  final String? sportId;

  /// Structured venue UUID (optional).
  final String? venueId;

  /// Location tag UUID (optional).
  final String? locationTagId;

  /// KAN-492: the chosen place's area. Sent as `area_id` only when known;
  /// with no place (or an unknown area) the key is ABSENT, never a default.
  final String? areaId;

  /// Free-text or resolved location name.
  final String? locationName;

  /// KAN-592: the city (and area, when known) the author posts from. Not the
  /// place the post is about; that is [locationName].
  final String? postedFromCity;
  final String? postedFromArea;

  /// Geo latitude (optional, from device or venue).
  final double? geoLat;

  /// Geo longitude (optional, from device or venue).
  final double? geoLng;

  /// Secure token for link-visibility posts. Null otherwise.
  final String? linkToken;

  /// Whether others can repost this post.
  final bool allowReposts;

  /// Optional expiry timestamp.
  final DateTime? expiresAt;

  /// Origin type — defaults to manual.
  final OriginType originType;

  /// Content class — defaults to 'social'.
  final String contentClass;

  /// Circle ID for circle-visibility posts.
  final String? circleId;

  /// Squad ID for squad-visibility posts.
  final String? squadId;

  /// Game ID to link this post to a game.
  final String? gameId;

  /// Origin ID — auto-set from linked entity (game, venue, etc.).
  final String? originId;

  /// Persona type snapshot captured at creation time.
  final String? personaTypeSnapshot;

  /// Whether this post should be pinned on the author's profile.
  final bool isPinned;

  /// KAN-612: the client request id of this create attempt. A retry of the
  /// same attempt sends the same id, so the server keeps one row.
  final String? requestId;

  /// Convert to the Supabase insert payload.
  ///
  /// `authorProfileId` and `authorUserId` are injected by the repository.
  Map<String, dynamic> toInsertPayload({
    required String authorProfileId,
    required String authorUserId,
  }) {
    return <String, dynamic>{
      'author_profile_id': authorProfileId,
      'author_user_id': authorUserId,
      'kind': kind.name,
      'visibility': visibility.name,
      'post_type': postType.dbValue,
      'origin_type': originType.name,
      'content_class': contentClass,
      'is_active': true,
      'allow_reposts': allowReposts,
      'is_pinned': isPinned,
      'requires_moderation': false,
      'priority_score': 0,
      'view_count': 0,
      if (body != null) 'body': body,
      if (lang != null) 'lang': lang,
      if (media != null && media!.isNotEmpty) 'media': media,
      if (tags != null && tags!.isNotEmpty) 'tags': tags,
      if (vibeId != null) 'vibe_id': vibeId,
      if (sportId != null) 'sport_id': sportId,
      if (venueId != null) 'venue_id': venueId,
      if (locationTagId != null) 'location_tag_id': locationTagId,
      if (areaId != null) 'area_id': areaId,
      if (locationName != null) 'location_name': locationName,
      if (postedFromCity != null) 'posted_from_city': postedFromCity,
      if (postedFromArea != null) 'posted_from_area': postedFromArea,
      if (geoLat != null) 'geo_lat': geoLat,
      if (geoLng != null) 'geo_lng': geoLng,
      if (linkToken != null) 'link_token': linkToken,
      if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
      if (gameId != null) 'game_id': gameId,
      if (originId != null) 'origin_id': originId,
      if (personaTypeSnapshot != null)
        'persona_type_snapshot': personaTypeSnapshot,
      if (requestId != null) 'request_id': requestId,
    };
  }

  /// Copy-with for incremental builder pattern.
  PostCreateRequest copyWith({
    PostKind? kind,
    PostVisibility? visibility,
    String? body,
    String? lang,
    List<dynamic>? media,
    List<String>? tags,
    String? vibeId,
    String? sportId,
    String? venueId,
    String? locationTagId,
    String? areaId,
    String? locationName,
    String? postedFromCity,
    String? postedFromArea,
    double? geoLat,
    double? geoLng,
    String? linkToken,
    bool? allowReposts,
    DateTime? expiresAt,
    OriginType? originType,
    String? contentClass,
    String? circleId,
    String? squadId,
    String? gameId,
    String? originId,
    String? personaTypeSnapshot,
    bool? isPinned,
  }) {
    return PostCreateRequest(
      kind: kind ?? this.kind,
      visibility: visibility ?? this.visibility,
      body: body ?? this.body,
      lang: lang ?? this.lang,
      media: media ?? this.media,
      tags: tags ?? this.tags,
      vibeId: vibeId ?? this.vibeId,
      sportId: sportId ?? this.sportId,
      venueId: venueId ?? this.venueId,
      locationTagId: locationTagId ?? this.locationTagId,
      areaId: areaId ?? this.areaId,
      locationName: locationName ?? this.locationName,
      postedFromCity: postedFromCity ?? this.postedFromCity,
      postedFromArea: postedFromArea ?? this.postedFromArea,
      geoLat: geoLat ?? this.geoLat,
      geoLng: geoLng ?? this.geoLng,
      linkToken: linkToken ?? this.linkToken,
      allowReposts: allowReposts ?? this.allowReposts,
      expiresAt: expiresAt ?? this.expiresAt,
      originType: originType ?? this.originType,
      contentClass: contentClass ?? this.contentClass,
      circleId: circleId ?? this.circleId,
      squadId: squadId ?? this.squadId,
      gameId: gameId ?? this.gameId,
      originId: originId ?? this.originId,
      personaTypeSnapshot: personaTypeSnapshot ?? this.personaTypeSnapshot,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
