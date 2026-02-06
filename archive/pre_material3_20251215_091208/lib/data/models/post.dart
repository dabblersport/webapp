import 'package:dabbler/core/utils/json.dart';

/// Canonical client model for rows in `public.posts`.
/// Matches the actual database schema with all fields.
class Post {
  final String id;
  final String authorProfileId;
  final String authorUserId;
  final String kind; // 'moment', 'dab', 'kickin'
  final String visibility; // 'public', 'circle', 'hidden'
  final String? linkToken;

  // Content fields
  final String? body;
  final String? lang;
  final String? sportKey;

  // Location
  final String? venueId;
  final double? geoLat;
  final double? geoLng;

  // Media (array of media objects)
  final List<dynamic> media;

  // Stats
  final int likeCount;
  final int commentCount;

  // Moderation
  final bool isDeleted;
  final bool isHiddenAdmin;

  // Vibe
  final String? primaryVibeId;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const Post({
    required this.id,
    required this.authorProfileId,
    required this.authorUserId,
    required this.kind,
    required this.visibility,
    required this.createdAt,
    this.linkToken,
    this.body,
    this.lang,
    this.sportKey,
    this.venueId,
    this.geoLat,
    this.geoLng,
    this.media = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.isDeleted = false,
    this.isHiddenAdmin = false,
    this.primaryVibeId,
    this.updatedAt,
  });

  factory Post.fromMap(Map<String, dynamic> row) {
    final m = asMap(row);

    // Safe string extraction with null handling
    String safeString(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    String? safeStringOrNull(dynamic value) {
      if (value == null) return null;
      return value.toString();
    }

    double? safeDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString());
      return parsed;
    }

    int safeInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value.toString());
      return parsed ?? defaultValue;
    }

    bool safeBool(dynamic value, bool defaultValue) {
      if (value == null) return defaultValue;
      if (value is bool) return value;
      return defaultValue;
    }

    List<dynamic> safeList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value;
      return [];
    }

    return Post(
      id: safeString(m['id'], ''),
      authorProfileId: safeString(m['author_profile_id'], ''),
      authorUserId: safeString(m['author_user_id'], ''),
      kind: safeString(m['kind'], 'moment'),
      visibility: safeString(m['visibility'], 'public'),
      linkToken: safeStringOrNull(m['link_token']),
      body: safeStringOrNull(m['body']),
      lang: safeStringOrNull(m['lang']),
      sportKey: safeStringOrNull(m['sport_key']),
      venueId: safeStringOrNull(m['venue_id']),
      geoLat: safeDouble(m['geo_lat']),
      geoLng: safeDouble(m['geo_lng']),
      media: safeList(m['media']),
      likeCount: safeInt(m['like_count'], 0),
      commentCount: safeInt(m['comment_count'], 0),
      isDeleted: safeBool(m['is_deleted'], false),
      isHiddenAdmin: safeBool(m['is_hidden_admin'], false),
      primaryVibeId: safeStringOrNull(m['primary_vibe_id']),
      createdAt:
          asDateTime(m['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: asDateTime(m['updated_at']),
    );
  }

  Map<String, dynamic> toInsert() {
    return {
      'kind': kind,
      'visibility': visibility,
      if (linkToken != null) 'link_token': linkToken,
      if (body != null) 'body': body,
      if (lang != null) 'lang': lang,
      if (sportKey != null) 'sport_key': sportKey,
      if (venueId != null) 'venue_id': venueId,
      if (geoLat != null) 'geo_lat': geoLat,
      if (geoLng != null) 'geo_lng': geoLng,
      'media': media,
      if (primaryVibeId != null) 'primary_vibe_id': primaryVibeId,
      // author_user_id and author_profile_id are enforced server-side via RLS/triggers
      // like_count, comment_count default to 0 server-side
      // is_deleted, is_hidden_admin default to false server-side
    };
  }

  Map<String, dynamic> toUpdate({
    String? newVisibility,
    String? newBody,
    String? newLang,
    String? newSportKey,
    String? newVenueId,
    double? newGeoLat,
    double? newGeoLng,
    List<dynamic>? newMedia,
    String? newPrimaryVibeId,
  }) {
    return {
      if (newVisibility != null) 'visibility': newVisibility,
      if (newBody != null) 'body': newBody,
      if (newLang != null) 'lang': newLang,
      if (newSportKey != null) 'sport_key': newSportKey,
      if (newVenueId != null) 'venue_id': newVenueId,
      if (newGeoLat != null) 'geo_lat': newGeoLat,
      if (newGeoLng != null) 'geo_lng': newGeoLng,
      if (newMedia != null) 'media': newMedia,
      if (newPrimaryVibeId != null) 'primary_vibe_id': newPrimaryVibeId,
    };
  }
}
