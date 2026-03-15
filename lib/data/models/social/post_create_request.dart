import 'package:dabbler/data/models/social/post_enums.dart';

/// Immutable request DTO for creating a new post.
///
/// Maps 1:1 to the `posts` table columns. The repository resolves
/// `author_profile_id` and `author_user_id` from the current session,
/// so they are intentionally excluded from this request class.
class PostCreateRequest {
  const PostCreateRequest({
    required this.kind,
    required this.visibility,
    this.body,
    this.lang,
    this.media,
    this.tags,
    this.vibeId,
    this.sportId,
    this.venueId,
    this.locationTagId,
    this.locationName,
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
  });

  /// Required — the kind of post (moment, dab, kickin).
  final PostKind kind;

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

  /// Free-text or resolved location name.
  final String? locationName;

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
      'post_type': kind.defaultPostType.dbValue,
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
      if (locationName != null) 'location_name': locationName,
      if (geoLat != null) 'geo_lat': geoLat,
      if (geoLng != null) 'geo_lng': geoLng,
      if (linkToken != null) 'link_token': linkToken,
      if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
      if (gameId != null) 'game_id': gameId,
      if (originId != null) 'origin_id': originId,
      if (personaTypeSnapshot != null)
        'persona_type_snapshot': personaTypeSnapshot,
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
    String? locationName,
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
      locationName: locationName ?? this.locationName,
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
