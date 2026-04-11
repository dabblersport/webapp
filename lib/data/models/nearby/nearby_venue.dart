import 'nearby_entity.dart';

/// Projection of `get_nearby_venues`.
class NearbyVenue extends NearbyEntity {
  const NearbyVenue({
    required super.id,
    required super.lat,
    required super.lng,
    required super.distanceMeters,
    required this.name,
    this.rating,
    this.price,
  });

  final String name;
  final double? rating;
  final double? price;

  factory NearbyVenue.fromJson(Map<String, dynamic> json) {
    return NearbyVenue(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed Venue',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
      distanceMeters: (json['distance_meters'] as num).toDouble(),
    );
  }
}
