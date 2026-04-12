class Venue {
  final String id;
  final String? ownerUserId;
  final String nameEn;
  final String? nameAr;
  final String? descriptionEn;
  final String? descriptionAr;
  final String city;
  final String? district;
  final String? area;
  final String? addressLine1;
  final double? lat;
  final double? lng;
  final String? geoLocationId;
  final String? areaId;
  final String? phone;
  final String? website;
  final String? instagram;
  final List<String> amenities;
  final bool isVerified;
  final bool isActive;
  final bool? isIndoor;
  final String? surfaceType;
  final double? minPricePerHour;
  final double? maxPricePerHour;
  final double? rating;
  final int? ratingCount;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Venue({
    required this.id,
    this.ownerUserId,
    required this.nameEn,
    this.nameAr,
    this.descriptionEn,
    this.descriptionAr,
    required this.city,
    this.district,
    this.area,
    this.addressLine1,
    this.lat,
    this.lng,
    this.geoLocationId,
    this.areaId,
    this.phone,
    this.website,
    this.instagram,
    this.amenities = const [],
    required this.isVerified,
    required this.isActive,
    this.isIndoor,
    this.surfaceType,
    this.minPricePerHour,
    this.maxPricePerHour,
    this.rating,
    this.ratingCount,
    this.timezone = 'Asia/Dubai',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Venue.fromMap(Map<String, dynamic> map) {
    return Venue(
      id: map['id'] as String,
      ownerUserId: map['owner_user_id'] as String?,
      nameEn: map['name_en'] as String,
      nameAr: map['name_ar'] as String?,
      descriptionEn: map['description_en'] as String?,
      descriptionAr: map['description_ar'] as String?,
      city: map['city'] as String,
      district: map['district'] as String?,
      area: map['area'] as String?,
      addressLine1: map['address_line1'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      geoLocationId: map['geo_location_id'] as String?,
      areaId: map['area_id'] as String?,
      phone: map['phone'] as String?,
      website: map['website'] as String?,
      instagram: map['instagram'] as String?,
      amenities:
          (map['amenities'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isVerified: map['is_verified'] as bool,
      isActive: map['is_active'] as bool,
      isIndoor: map['is_indoor'] as bool?,
      surfaceType: map['surface_type'] as String?,
      minPricePerHour: (map['min_price_per_hour'] as num?)?.toDouble(),
      maxPricePerHour: (map['max_price_per_hour'] as num?)?.toDouble(),
      rating: (map['rating'] as num?)?.toDouble(),
      ratingCount: map['rating_count'] as int?,
      timezone: map['timezone'] as String? ?? 'Asia/Dubai',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
