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
    this.body,
    this.lat,
    this.lng,
    this.distanceMeters,
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
    );
  }
}
