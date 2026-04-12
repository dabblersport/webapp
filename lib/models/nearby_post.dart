class NearbyPost {
  final String id;
  final String? body;
  final String? authorProfileId;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final double? lat;
  final double? lng;
  final double distanceMeters;
  final bool isNearby;
  final double? score;

  const NearbyPost({
    required this.id,
    this.body,
    this.authorProfileId,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    this.lat,
    this.lng,
    required this.distanceMeters,
    required this.isNearby,
    this.score,
  });

  factory NearbyPost.fromMap(Map<String, dynamic> map) {
    return NearbyPost(
      id: map['id'] as String,
      body: map['body'] as String?,
      authorProfileId: map['author_profile_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      likeCount: map['like_count'] as int,
      commentCount: map['comment_count'] as int,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      distanceMeters: (map['distance_meters'] as num).toDouble(),
      isNearby: map['is_nearby'] as bool,
      score: (map['score'] as num?)?.toDouble(),
    );
  }
}
