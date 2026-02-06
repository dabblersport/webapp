/// Model for location_tags table
class LocationTagModel {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? country;
  final double? lat;
  final double? lng;
  final String? placeId; // Google Places ID or similar
  final Map<String, dynamic>? meta;
  final DateTime createdAt;

  const LocationTagModel({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.country,
    this.lat,
    this.lng,
    this.placeId,
    this.meta,
    required this.createdAt,
  });

  factory LocationTagModel.fromJson(Map<String, dynamic> json) {
    return LocationTagModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      lat: json['lat'] as double?,
      lng: json['lng'] as double?,
      placeId: json['place_id'] as String?,
      meta: json['meta'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'country': country,
      'lat': lat,
      'lng': lng,
      'place_id': placeId,
      'meta': meta,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get formatted location string
  String getFormattedLocation() {
    final parts = <String>[];
    parts.add(name);
    if (city != null && city!.isNotEmpty) {
      parts.add(city!);
    }
    if (country != null && country!.isNotEmpty) {
      parts.add(country!);
    }
    return parts.join(', ');
  }

  @override
  String toString() => 'LocationTagModel(name: $name, city: $city)';
}
