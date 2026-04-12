class NearbyVenue {
  final String id;
  final String nameEn;
  final String? nameAr;
  final String city;
  final String? district;
  final double? lat;
  final double? lng;
  final String? areaId;
  final bool? isIndoor;
  final String? surfaceType;
  final double? minPricePerHour;
  final double distanceMeters;

  const NearbyVenue({
    required this.id,
    required this.nameEn,
    this.nameAr,
    required this.city,
    this.district,
    this.lat,
    this.lng,
    this.areaId,
    this.isIndoor,
    this.surfaceType,
    this.minPricePerHour,
    required this.distanceMeters,
  });

  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toInt()} m';
  }

  factory NearbyVenue.fromMap(Map<String, dynamic> map) {
    return NearbyVenue(
      id: map['id'] as String,
      nameEn: map['name_en'] as String,
      nameAr: map['name_ar'] as String?,
      city: map['city'] as String,
      district: map['district'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      areaId: map['area_id'] as String?,
      isIndoor: map['is_indoor'] as bool?,
      surfaceType: map['surface_type'] as String?,
      minPricePerHour: (map['min_price_per_hour'] as num?)?.toDouble(),
      distanceMeters: (map['distance_meters'] as num).toDouble(),
    );
  }
}
