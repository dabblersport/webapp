class NearbyGame {
  final String id;
  final String title;
  final double? lat;
  final double? lng;
  final DateTime startAt;
  final int? capacity;
  final String? sportId;
  final String? areaId;
  final double distanceMeters;

  const NearbyGame({
    required this.id,
    required this.title,
    this.lat,
    this.lng,
    required this.startAt,
    this.capacity,
    this.sportId,
    this.areaId,
    required this.distanceMeters,
  });

  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toInt()} m';
  }

  factory NearbyGame.fromMap(Map<String, dynamic> map) {
    return NearbyGame(
      id: map['id'] as String,
      title: map['title'] as String,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      startAt: DateTime.parse(map['start_at'] as String),
      capacity: map['capacity'] as int?,
      sportId: map['sport_id'] as String?,
      areaId: map['area_id'] as String?,
      distanceMeters: (map['distance_meters'] as num).toDouble(),
    );
  }
}
