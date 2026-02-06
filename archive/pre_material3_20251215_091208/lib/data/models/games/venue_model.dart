import 'package:dabbler/data/models/games/venue.dart';

class VenueModel extends Venue {
  const VenueModel({
    required super.id,
    required super.name,
    required super.description,
    required super.addressLine1,
    super.addressLine2,
    required super.city,
    required super.state,
    required super.country,
    required super.postalCode,
    required super.latitude,
    required super.longitude,
    super.phone,
    super.email,
    super.website,
    required super.openingTime,
    required super.closingTime,
    required super.rating,
    required super.totalRatings,
    required super.pricePerHour,
    required super.currency,
    required super.supportedSports,
    required super.amenities,
    required super.createdAt,
    required super.updatedAt,
  });

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    try {
      // Use name_en for English name, fallback to name if present
      final name =
          json['name_en'] as String? ??
          json['name'] as String? ??
          'Unnamed Venue';

      // Extract sports from venue_spaces join
      final List<String> sports = [];
      if (json['venue_spaces'] != null) {
        final spaces = json['venue_spaces'] as List<dynamic>?;
        if (spaces != null) {
          for (final space in spaces) {
            if (space is Map<String, dynamic>) {
              final sport = space['sport'] as String?;
              final isActive = space['is_active'] as bool? ?? true;
              if (sport != null && sport.isNotEmpty && isActive) {
                if (!sports.contains(sport)) {
                  sports.add(sport);
                }
              }
            }
          }
        }
      }

      // Extract rating from venue_rating_aggregate join
      double rating = 0.0;
      int totalRatings = 0;
      if (json['venue_rating_aggregate'] != null) {
        final ratingData = json['venue_rating_aggregate'];
        if (ratingData is List && ratingData.isNotEmpty) {
          final aggregate = ratingData[0] as Map<String, dynamic>?;
          if (aggregate != null) {
            rating = (aggregate['composite_score'] as num?)?.toDouble() ?? 0.0;
            totalRatings = aggregate['event_count'] as int? ?? 0;
          }
        } else if (ratingData is Map<String, dynamic>) {
          rating = (ratingData['composite_score'] as num?)?.toDouble() ?? 0.0;
          totalRatings = ratingData['event_count'] as int? ?? 0;
        }
      }
      // Fallback to direct rating field if aggregate is not available or empty
      if (rating == 0.0 && json['rating'] != null) {
        rating = (json['rating'] as num?)?.toDouble() ?? 0.0;
      }
      if (totalRatings == 0 && json['total_ratings'] != null) {
        totalRatings = json['total_ratings'] as int? ?? 0;
      }

      // Extract amenities from venue_amenities join or amenities array
      List<String> amenitiesList = [];
      if (json['venue_amenities'] != null) {
        final venueAmenities = json['venue_amenities'] as List<dynamic>?;
        if (venueAmenities != null && venueAmenities.isNotEmpty) {
          amenitiesList = venueAmenities
              .map((item) {
                if (item is Map<String, dynamic>) {
                  // Prefer amenity_key, fallback to value
                  final amenity =
                      item['amenity_key'] as String? ??
                      item['value'] as String?;
                  if (amenity != null && amenity.isNotEmpty) {
                    return amenity;
                  }
                }
                return item.toString();
              })
              .where((a) => a.isNotEmpty)
              .toList();
        }
      }
      // Fallback to amenities array if venue_amenities not available or empty
      if (amenitiesList.isEmpty && json['amenities'] != null) {
        final parsed = _parseAmenities(json['amenities']);
        if (parsed != null && parsed.isNotEmpty) {
          amenitiesList = parsed;
        }
      }

      // Extract opening hours from venue_opening_hours join
      String openingTime = '09:00';
      String closingTime = '18:00';
      if (json['venue_opening_hours'] != null) {
        final hours = json['venue_opening_hours'] as List<dynamic>?;
        if (hours != null && hours.isNotEmpty) {
          // Use first day's hours as default, or find today's weekday
          final today = DateTime.now().weekday % 7; // Convert to 0-6 (Sun-Sat)
          final todayHours = hours.firstWhere(
            (h) =>
                h is Map<String, dynamic> &&
                (h['weekday'] as int?) == today &&
                (h['is_open'] as bool?) == true,
            orElse: () => hours.first,
          );
          if (todayHours is Map<String, dynamic>) {
            openingTime = _parseTime(todayHours['open_time']) ?? openingTime;
            closingTime = _parseTime(todayHours['close_time']) ?? closingTime;
          }
        }
      }

      return VenueModel(
        id: json['id'] as String,
        name: name,
        description:
            json['description_en'] as String? ??
            json['description'] as String? ??
            '',
        addressLine1:
            json['address_line1'] as String? ??
            json['address_line_1'] as String? ??
            '',
        addressLine2:
            json['address_line2'] as String? ??
            json['address_line_2'] as String?,
        city: json['city'] as String? ?? '',
        state: json['district'] as String? ?? json['state'] as String? ?? '',
        country: json['country'] as String? ?? '',
        postalCode: json['postal_code'] as String? ?? '',
        latitude:
            (json['latitude'] as num?)?.toDouble() ??
            (json['lat'] as num?)?.toDouble() ??
            0.0,
        longitude:
            (json['longitude'] as num?)?.toDouble() ??
            (json['lng'] as num?)?.toDouble() ??
            0.0,
        phone: json['phone'] as String? ?? json['phone_number'] as String?,
        email: json['email'] as String?,
        website: json['website'] as String?,
        openingTime: openingTime,
        closingTime: closingTime,
        rating: rating,
        totalRatings: totalRatings,
        pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency'] as String? ?? 'AED',
        supportedSports: sports.isNotEmpty
            ? sports
            : ['Football', 'Padel'], // Default sports
        amenities: amenitiesList,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
    } catch (e) {
      rethrow;
    }
  }

  static String? _parseTime(dynamic timeData) {
    if (timeData == null) return null;
    if (timeData is String) return timeData;
    // Handle PostgreSQL time format
    return timeData.toString();
  }

  static List<String>? _parseStringList(dynamic listData) {
    if (listData == null) return null;

    if (listData is List) {
      return listData.map((item) => item.toString()).toList();
    }

    if (listData is String) {
      if (listData.contains(',')) {
        return listData.split(',').map((s) => s.trim()).toList();
      }
      return [listData];
    }

    return null;
  }

  static List<String>? _parseAmenities(dynamic amenitiesData) {
    if (amenitiesData == null) return null;

    if (amenitiesData is List) {
      // Handle array of amenity objects
      return amenitiesData.map((item) {
        if (item is Map<String, dynamic>) {
          return item['name'] as String? ??
              item['amenity'] as String? ??
              item.toString();
        }
        return item.toString();
      }).toList();
    }

    return _parseStringList(amenitiesData);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'city': city,
      'state': state,
      'country': country,
      'postal_code': postalCode,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'email': email,
      'website': website,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'rating': rating,
      'total_ratings': totalRatings,
      'price_per_hour': pricePerHour,
      'currency': currency,
      'supported_sports': supportedSports,
      'amenities': amenities,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'description': description,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'city': city,
      'state': state,
      'country': country,
      'postal_code': postalCode,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'email': email,
      'website': website,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'price_per_hour': pricePerHour,
      'currency': currency,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'description': description,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'city': city,
      'state': state,
      'country': country,
      'postal_code': postalCode,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'email': email,
      'website': website,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'price_per_hour': pricePerHour,
      'currency': currency,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // Get formatted distance string
  String getFormattedDistance(double fromLatitude, double fromLongitude) {
    final distance = distanceFrom(fromLatitude, fromLongitude);

    if (distance < 1000) {
      return '${distance.round()}m away';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km away';
    }
  }

  // Get venue coordinate as string
  String get coordinateString {
    return '$latitude, $longitude';
  }

  // Get full address string
  @override
  String get fullAddress {
    final parts = <String>[addressLine1];
    if (addressLine2 != null && addressLine2!.isNotEmpty) {
      parts.add(addressLine2!);
    }
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    if (country.isNotEmpty) parts.add(country);
    if (postalCode.isNotEmpty) parts.add(postalCode);

    return parts.join(', ');
  }

  // Get rating display string
  String get ratingDisplay {
    if (totalRatings == 0) return 'No ratings';
    return '${rating.toStringAsFixed(1)} ($totalRatings reviews)';
  }

  // Check if venue has specific amenity
  @override
  bool hasAmenity(String amenityName) {
    return amenities.any(
      (amenity) => amenity.toLowerCase().contains(amenityName.toLowerCase()),
    );
  }

  // Check if venue supports specific sport
  @override
  bool supportsSport(String sportName) {
    return supportedSports.any(
      (sport) => sport.toLowerCase().contains(sportName.toLowerCase()),
    );
  }

  // Get price display text
  String get priceDisplay {
    return '$currency${pricePerHour.toStringAsFixed(2)}/hour';
  }

  // Get operating hours display text
  String get operatingHoursDisplay {
    return '$openingTime - $closingTime';
  }

  factory VenueModel.fromVenue(Venue venue) {
    return VenueModel(
      id: venue.id,
      name: venue.name,
      description: venue.description,
      addressLine1: venue.addressLine1,
      addressLine2: venue.addressLine2,
      city: venue.city,
      state: venue.state,
      country: venue.country,
      postalCode: venue.postalCode,
      latitude: venue.latitude,
      longitude: venue.longitude,
      phone: venue.phone,
      email: venue.email,
      website: venue.website,
      openingTime: venue.openingTime,
      closingTime: venue.closingTime,
      rating: venue.rating,
      totalRatings: venue.totalRatings,
      pricePerHour: venue.pricePerHour,
      currency: venue.currency,
      supportedSports: venue.supportedSports,
      amenities: venue.amenities,
      createdAt: venue.createdAt,
      updatedAt: venue.updatedAt,
    );
  }

  @override
  VenueModel copyWith({
    String? id,
    String? name,
    String? description,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    double? latitude,
    double? longitude,
    String? phone,
    String? email,
    String? website,
    String? openingTime,
    String? closingTime,
    double? rating,
    int? totalRatings,
    double? pricePerHour,
    String? currency,
    List<String>? supportedSports,
    List<String>? amenities,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VenueModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      rating: rating ?? this.rating,
      totalRatings: totalRatings ?? this.totalRatings,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      currency: currency ?? this.currency,
      supportedSports: supportedSports ?? this.supportedSports,
      amenities: amenities ?? this.amenities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
