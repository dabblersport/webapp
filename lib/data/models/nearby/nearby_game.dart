import 'nearby_entity.dart';
import 'package:dabbler/core/utils/instant.dart';

/// Projection of `get_nearby_games`.
class NearbyGame extends NearbyEntity {
  const NearbyGame({
    required super.id,
    required super.lat,
    required super.lng,
    required super.distanceMeters,
    required this.title,
    required this.startAt,
    required this.capacity,
  });

  final String title;
  final DateTime startAt;
  final int capacity;

  factory NearbyGame.fromJson(Map<String, dynamic> json) {
    return NearbyGame(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Game',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      startAt: parseInstantLocal(json['start_at'])!,
      capacity: (json['capacity'] as num).toInt(),
      distanceMeters: (json['distance_meters'] as num).toDouble(),
    );
  }
}
