/// A nearby venue row returned by the `rpc_get_nearby_venues` PostGIS RPC.
///
/// Intentionally a plain Dart class (no Freezed) to avoid needing a
/// build_runner pass. Distance is always present because the RPC computes it.
class NearbyVenueModel {
  const NearbyVenueModel({
    required this.id,
    required this.nameEn,
    this.nameAr,
    required this.city,
    this.area,
    this.isIndoor,
    this.pricePerHour,
    this.latitude,
    this.longitude,
    required this.distanceMeters,
    this.sportNames = const [],
    this.coverUrl,
    this.rating,
    this.ratingCount = 0,
    this.isVerified = false,
    this.isOpenNow = false,
    this.amenities = const [],
    this.sports = const [],
    this.sportsAr = const [],
  });

  final String id;
  final String nameEn;
  final String? nameAr;
  final String city;
  final String? area;
  final bool? isIndoor;
  final double? pricePerHour;
  final double? latitude;
  final double? longitude;

  /// Straight-line distance in metres from the query origin.
  final double distanceMeters;

  /// All sport names supported by this venue.
  final List<String> sportNames;

  final String? coverUrl;

  /// Aggregate rating (null: not rated yet) and its review count.
  final double? rating;
  final int ratingCount;
  final bool isVerified;
  final bool isOpenNow;

  /// Amenity catalog keys.
  final List<String> amenities;

  /// Every sport the venue offers (English / Arabic names).
  final List<String> sports;
  final List<String> sportsAr;

  factory NearbyVenueModel.fromJson(Map<String, dynamic> json) {
    return NearbyVenueModel(
      id: json['id'] as String,
      nameEn: json['name_en'] as String? ?? '',
      nameAr: json['name_ar'] as String?,
      city: json['city'] as String? ?? '',
      area: json['area'] as String?,
      isIndoor: json['is_indoor'] as bool?,
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      sportNames: _parseStrings(json['sport_names']),
      coverUrl: json['cover_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isOpenNow: json['is_open_now'] as bool? ?? false,
      amenities: _parseStrings(json['amenities']),
      sports: _parseStrings(json['sports']),
      sportsAr: _parseStrings(json['sports_ar']),
    );
  }

  static List<String> _parseStrings(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return const [];
  }

  /// Formatted distance label: "850 m" or "1.2 km".
  String get distanceLabel => formatDistanceMeters(distanceMeters);
}

/// Formatted distance: "850 m" or "1.2 km" (one decimal under 10 km).
String formatDistanceMeters(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  final formatted = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
  return '$formatted km';
}
