/// Lightweight projection returned by the `get_nearby_games` Postgres RPC.
/// This is a read-only value object – no mutations, no Freezed codegen needed.
class NearbyGame {
  const NearbyGame({
    required this.id,
    required this.title,
    required this.lat,
    required this.lng,
    required this.startAt,
    required this.capacity,
    required this.distanceMeters,
  });

  final String id;
  final String title;
  final double lat;
  final double lng;
  final DateTime startAt;
  final int capacity;
  final double distanceMeters;

  factory NearbyGame.fromJson(Map<String, dynamic> json) {
    return NearbyGame(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Game',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      startAt: DateTime.parse(json['start_at'] as String),
      capacity: (json['capacity'] as num).toInt(),
      distanceMeters: (json['distance_meters'] as num).toDouble(),
    );
  }

  @override
  String toString() =>
      'NearbyGame(id: $id, title: $title, distanceMeters: $distanceMeters)';
}
