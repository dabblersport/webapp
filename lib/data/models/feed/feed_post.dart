/// A post returned by the `get_nearby_posts` RPC, ranked by score.
class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorProfileId,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.isNearby,
    required this.score,
    required this.geoLat,
    required this.geoLng,
    required this.geoLocationId,
    required this.areaId,
    this.body,
    this.lat,
    this.lng,
    this.distanceMeters,
    this.venueId,
    this.locationName,
  });

  final String id;
  final String? body;
  final String authorProfileId;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final double? lat;
  final double? lng;
  final double? distanceMeters;
  final bool isNearby;
  final double score;

  /// Guaranteed non-null geo fields populated by server-side trigger.
  final double geoLat;
  final double geoLng;
  final String geoLocationId;
  final String areaId;

  /// Nullable FK to `venues` table.
  final String? venueId;

  /// Optional human-readable location name.
  final String? locationName;

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'] as String,
      body: json['body'] as String?,
      authorProfileId: json['author_profile_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      isNearby: json['is_nearby'] as bool? ?? false,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      geoLat: (json['geo_lat'] as num).toDouble(),
      geoLng: (json['geo_lng'] as num).toDouble(),
      geoLocationId: json['geo_location_id'] as String,
      areaId: json['area_id'] as String,
      venueId: json['venue_id'] as String?,
      locationName: json['location_name'] as String?,
    );
  }

  FeedPost copyWith({
    String? id,
    String? body,
    String? authorProfileId,
    DateTime? createdAt,
    int? likeCount,
    int? commentCount,
    double? lat,
    double? lng,
    double? distanceMeters,
    bool? isNearby,
    double? score,
    double? geoLat,
    double? geoLng,
    String? geoLocationId,
    String? areaId,
    String? venueId,
    String? locationName,
  }) {
    return FeedPost(
      id: id ?? this.id,
      body: body ?? this.body,
      authorProfileId: authorProfileId ?? this.authorProfileId,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      isNearby: isNearby ?? this.isNearby,
      score: score ?? this.score,
      geoLat: geoLat ?? this.geoLat,
      geoLng: geoLng ?? this.geoLng,
      geoLocationId: geoLocationId ?? this.geoLocationId,
      areaId: areaId ?? this.areaId,
      venueId: venueId ?? this.venueId,
      locationName: locationName ?? this.locationName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'body': body,
    'author_profile_id': authorProfileId,
    'created_at': createdAt.toIso8601String(),
    'like_count': likeCount,
    'comment_count': commentCount,
    'lat': lat,
    'lng': lng,
    'distance_meters': distanceMeters,
    'is_nearby': isNearby,
    'score': score,
    'geo_lat': geoLat,
    'geo_lng': geoLng,
    'geo_location_id': geoLocationId,
    'area_id': areaId,
    'venue_id': venueId,
    'location_name': locationName,
  };
}
