// Venue model for venue list
class Venue {
  final String id;
  final String name;
  final String location;
  final String? imageUrl;
  final double rating;
  final List<String> amenities;
  final List<String> sports;
  final bool isFree;
  final Map<String, dynamic>? coordinates;
  final String? description;
  final String? phone;
  final String? website;
  final Map<String, dynamic>? openingHours;

  const Venue({
    required this.id,
    required this.name,
    required this.location,
    this.imageUrl,
    this.rating = 0.0,
    this.amenities = const [],
    this.sports = const [],
    this.isFree = false,
    this.coordinates,
    this.description,
    this.phone,
    this.website,
    this.openingHours,
  });

  /// Backwards-compatible getter until all callsites migrate to `location`.
  String get city => location;

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'],
      name: json['name'],
      location: json['location'] ?? json['city'] ?? '',
      imageUrl: json['imageUrl'],
      rating: json['rating']?.toDouble() ?? 0.0,
      amenities: List<String>.from(json['amenities'] ?? []),
      sports: List<String>.from(json['sports'] ?? []),
      isFree: json['isFree'] ?? false,
      coordinates: json['coordinates'],
      description: json['description'],
      phone: json['phone'],
      website: json['website'],
      openingHours: json['openingHours'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'imageUrl': imageUrl,
      'rating': rating,
      'amenities': amenities,
      'sports': sports,
      'isFree': isFree,
      'coordinates': coordinates,
      'description': description,
      'phone': phone,
      'website': website,
      'openingHours': openingHours,
    };
  }
}
