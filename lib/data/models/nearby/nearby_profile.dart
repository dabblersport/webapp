import 'nearby_entity.dart';

/// Projection of `get_nearby_profiles`.
class NearbyProfile extends NearbyEntity {
  const NearbyProfile({
    required super.id,
    required super.lat,
    required super.lng,
    required super.distanceMeters,
    required this.username,
    this.avatar,
  });

  final String username;
  final String? avatar;

  factory NearbyProfile.fromJson(Map<String, dynamic> json) {
    return NearbyProfile(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Unknown',
      avatar: json['avatar'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      distanceMeters: (json['distance_meters'] as num).toDouble(),
    );
  }
}
