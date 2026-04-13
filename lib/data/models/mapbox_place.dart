class MapboxPlace {
  const MapboxPlace({
    required this.id,
    required this.name,
    required this.fullAddress,
    required this.lat,
    required this.lng,
  });

  final String id;

  /// `properties.name` from the Mapbox Geocoding v6 response.
  final String name;

  /// `properties.full_address` from the Mapbox Geocoding v6 response.
  final String fullAddress;

  /// `geometry.coordinates[1]`
  final double lat;

  /// `geometry.coordinates[0]`
  final double lng;

  factory MapboxPlace.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'] as Map<String, dynamic>? ?? {};
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};
    final coords = geometry['coordinates'] as List<dynamic>? ?? [0.0, 0.0];

    return MapboxPlace(
      id: json['id'] as String? ?? '',
      name: properties['name'] as String? ?? '',
      fullAddress: properties['full_address'] as String? ?? '',
      lat: (coords[1] as num).toDouble(),
      lng: (coords[0] as num).toDouble(),
    );
  }
}
