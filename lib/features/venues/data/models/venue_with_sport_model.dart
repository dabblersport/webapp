/// A row of the `v_venues_with_sports` view: venue data for one sport the
/// venue offers, plus the listing fields (cover, aggregate rating, badges'
/// inputs, all sports).
///
/// A plain class (no Freezed), like `NearbyVenueModel`: the code generator
/// cannot run on the current toolchain, and nothing here needs `copyWith`.
class VenueWithSportModel {
  const VenueWithSportModel({
    required this.id,
    required this.sportId,
    required this.nameEn,
    this.nameAr,
    required this.city,
    this.area,
    this.isActive = true,
    this.isIndoor,
    this.pricePerHour,
    this.latitude,
    this.longitude,
    this.address,
    this.phoneNumber,
    this.description,
    this.amenities = const [],
    this.compositeScore,
    this.createdAt,
    this.coverUrl,
    this.rating,
    this.ratingCount = 0,
    this.isVerified = false,
    this.isOpenNow = false,
    this.sports = const [],
    this.sportsAr = const [],
  });

  final String id;
  final String sportId;
  final String nameEn;
  final String? nameAr;
  final String city;
  final String? area;
  final bool isActive;
  final bool? isIndoor;
  final double? pricePerHour;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? phoneNumber;
  final String? description;

  /// `amenities_catalog` keys.
  final List<String> amenities;
  final double? compositeScore;
  final DateTime? createdAt;

  /// First `venue_photos` row by sort order; null until photos exist.
  final String? coverUrl;

  /// `venue_rating_aggregate.composite_score` (null: not rated yet).
  final double? rating;
  final int ratingCount;
  final bool isVerified;

  /// Computed server side from `opening_hours` in the venue's timezone.
  final bool isOpenNow;

  /// Every sport the venue offers (English / Arabic names).
  final List<String> sports;
  final List<String> sportsAr;

  factory VenueWithSportModel.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? raw) =>
        raw is List ? raw.map((e) => e.toString()).toList() : const [];
    double? number(Object? raw) => (raw as num?)?.toDouble();
    return VenueWithSportModel(
      id: json['id'] as String,
      sportId: json['sport_id'] as String,
      nameEn: json['name_en'] as String? ?? '',
      nameAr: json['name_ar'] as String?,
      city: json['city'] as String? ?? '',
      area: json['area'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isIndoor: json['is_indoor'] as bool?,
      pricePerHour: number(json['price_per_hour']),
      latitude: number(json['latitude']),
      longitude: number(json['longitude']),
      address: json['address'] as String?,
      phoneNumber: json['phone_number'] as String?,
      description: json['description'] as String?,
      amenities: strings(json['amenities']),
      compositeScore: number(json['composite_score']),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      coverUrl: json['cover_url'] as String?,
      rating: number(json['rating']),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isOpenNow: json['is_open_now'] as bool? ?? false,
      sports: strings(json['sports']),
      sportsAr: strings(json['sports_ar']),
    );
  }
}
