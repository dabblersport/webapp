import 'dart:math' as math;

class Venue {
  final String id;
  final String name;
  final String description;

  // Address components
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String country;
  final String postalCode;

  // Coordinates
  final double latitude;
  final double longitude;

  // Contact information
  final String? phone;
  final String? email;
  final String? website;

  // Operating hours (24-hour format)
  final String openingTime; // Format: "HH:mm"
  final String closingTime; // Format: "HH:mm"

  // Rating and pricing
  final double rating;
  final int totalRatings;
  final double pricePerHour;
  final String currency;

  // Sports and amenities
  final List<String> supportedSports;
  final List<String> amenities;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  const Venue({
    required this.id,
    required this.name,
    required this.description,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.email,
    this.website,
    required this.openingTime,
    required this.closingTime,
    required this.rating,
    required this.totalRatings,
    required this.pricePerHour,
    required this.currency,
    required this.supportedSports,
    required this.amenities,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get the full formatted address
  String get fullAddress {
    final components = [
      addressLine1,
      if (addressLine2 != null && addressLine2!.isNotEmpty) addressLine2!,
      city,
      state,
      postalCode,
      country,
    ];
    return components.join(', ');
  }

  /// Get short address (line1, city)
  String get shortAddress {
    return '$addressLine1, $city';
  }

  /// Check if venue is open at a specific time
  bool isOpenAt(DateTime dateTime) {
    final timeOfDay =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    // Handle venues that close after midnight
    if (_isTimeAfterMidnight(closingTime) &&
        _isTimeAfterMidnight(openingTime)) {
      // Both times are after midnight (unusual case)
      return _isTimeBetween(timeOfDay, openingTime, closingTime);
    } else if (_isTimeAfterMidnight(closingTime)) {
      // Venue closes after midnight (e.g., 22:00 - 02:00)
      return _isTimeBetween(timeOfDay, openingTime, '23:59') ||
          _isTimeBetween(timeOfDay, '00:00', closingTime);
    } else {
      // Normal operating hours (e.g., 08:00 - 22:00)
      return _isTimeBetween(timeOfDay, openingTime, closingTime);
    }
  }

  /// Calculate distance from given coordinates in kilometers
  double distanceFrom(double lat, double lon) {
    return _calculateHaversineDistance(latitude, longitude, lat, lon);
  }

  /// Check if venue supports a specific sport
  bool supportsSport(String sport) {
    return supportedSports.contains(sport.toLowerCase()) ||
        supportedSports.any((s) => s.toLowerCase() == sport.toLowerCase());
  }

  /// Check if venue has a specific amenity
  bool hasAmenity(String amenity) {
    return amenities.contains(amenity.toLowerCase()) ||
        amenities.any((a) => a.toLowerCase() == amenity.toLowerCase());
  }

  /// Get rating display text
  String get ratingText {
    if (totalRatings == 0) return 'No ratings';
    return '${rating.toStringAsFixed(1)} ($totalRatings reviews)';
  }

  /// Get price display text
  String get priceText {
    return '$currency${pricePerHour.toStringAsFixed(0)}/hour';
  }

  // Private helper methods
  bool _isTimeAfterMidnight(String time) {
    final hour = int.parse(time.split(':')[0]);
    return hour < 12;
  }

  bool _isTimeBetween(String current, String start, String end) {
    final currentMinutes = _timeToMinutes(current);
    final startMinutes = _timeToMinutes(start);
    final endMinutes = _timeToMinutes(end);

    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// Calculate distance using Haversine formula
  double _calculateHaversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  Venue copyWith({
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
    return Venue(
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Venue && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Venue{id: $id, name: $name, city: $city}';
  }
}
