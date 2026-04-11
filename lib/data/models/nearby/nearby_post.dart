import 'nearby_entity.dart';

/// Projection of `get_nearby_posts`.
class NearbyPost extends NearbyEntity {
  const NearbyPost({
    required super.id,
    required super.lat,
    required super.lng,
    required super.distanceMeters,
    required this.content,
    this.media,
  });

  final String content;
  final String? media;

  factory NearbyPost.fromJson(Map<String, dynamic> json) {
    return NearbyPost(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      media: json['media'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      distanceMeters: (json['distance_meters'] as num).toDouble(),
    );
  }
}
