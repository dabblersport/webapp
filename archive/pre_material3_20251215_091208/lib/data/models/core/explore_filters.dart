class ExploreFilters {
  final String? sport;
  final DateTime? date;
  final double? radiusKm;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? timeSlot; // morning, afternoon, evening
  final String? skillLevel; // beginner, intermediate, advanced
  final int? maxPlayers;

  const ExploreFilters({
    this.sport,
    this.date,
    this.radiusKm,
    this.location,
    this.latitude,
    this.longitude,
    this.timeSlot,
    this.skillLevel,
    this.maxPlayers,
  });

  // Create filters with defaults
  factory ExploreFilters.defaults({
    String? sport,
    String? location,
    double? latitude,
    double? longitude,
  }) {
    return ExploreFilters(
      sport: sport ?? 'All',
      date: DateTime.now(),
      radiusKm: 10.0,
      location: location,
      latitude: latitude,
      longitude: longitude,
      timeSlot: null,
      skillLevel: null,
      maxPlayers: null,
    );
  }

  // Create filters for "Find Games" CTA
  factory ExploreFilters.quickFind({
    String? userLocation,
    double? latitude,
    double? longitude,
    String? preferredSport,
  }) {
    return ExploreFilters(
      sport: preferredSport ?? 'All',
      date: DateTime.now(),
      radiusKm: 5.0, // Smaller radius for quick find
      location: userLocation,
      latitude: latitude,
      longitude: longitude,
      timeSlot: _getTimeSlotForNow(),
      skillLevel: null,
      maxPlayers: null,
    );
  }

  static String _getTimeSlotForNow() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  ExploreFilters copyWith({
    String? sport,
    DateTime? date,
    double? radiusKm,
    String? location,
    double? latitude,
    double? longitude,
    String? timeSlot,
    String? skillLevel,
    int? maxPlayers,
  }) {
    return ExploreFilters(
      sport: sport ?? this.sport,
      date: date ?? this.date,
      radiusKm: radiusKm ?? this.radiusKm,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timeSlot: timeSlot ?? this.timeSlot,
      skillLevel: skillLevel ?? this.skillLevel,
      maxPlayers: maxPlayers ?? this.maxPlayers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sport': sport,
      'date': date?.toIso8601String(),
      'radiusKm': radiusKm,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'timeSlot': timeSlot,
      'skillLevel': skillLevel,
      'maxPlayers': maxPlayers,
    };
  }

  factory ExploreFilters.fromJson(Map<String, dynamic> json) {
    return ExploreFilters(
      sport: json['sport'] as String?,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : null,
      radiusKm: (json['radiusKm'] as num?)?.toDouble(),
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      timeSlot: json['timeSlot'] as String?,
      skillLevel: json['skillLevel'] as String?,
      maxPlayers: json['maxPlayers'] as int?,
    );
  }

  bool get hasLocationData => latitude != null && longitude != null;

  bool get isValidForApi => sport != null && radiusKm != null;

  @override
  String toString() {
    return 'ExploreFilters(sport: $sport, location: $location, radius: ${radiusKm}km)';
  }
}
