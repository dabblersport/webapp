/// UAE cities and popular areas for location selection
class UAELocations {
  static const List<LocationData> cities = [
    // Dubai
    LocationData(
      city: 'Dubai',
      area: 'Downtown Dubai',
      displayName: 'Downtown Dubai',
      lat: 25.1972,
      lng: 55.2744,
    ),
    LocationData(
      city: 'Dubai',
      area: 'Dubai Marina',
      displayName: 'Dubai Marina',
      lat: 25.0805,
      lng: 55.1396,
    ),
    LocationData(
      city: 'Dubai',
      area: 'Jumeirah Beach Residence (JBR)',
      displayName: 'JBR, Dubai',
      lat: 25.0779,
      lng: 55.1328,
    ),
    LocationData(
      city: 'Dubai',
      area: 'Business Bay',
      displayName: 'Business Bay, Dubai',
      lat: 25.1861,
      lng: 55.2631,
    ),
    LocationData(
      city: 'Dubai',
      area: 'Dubai Sports City',
      displayName: 'Dubai Sports City',
      lat: 25.0394,
      lng: 55.2181,
    ),
    LocationData(
      city: 'Dubai',
      area: 'Deira',
      displayName: 'Deira, Dubai',
      lat: 25.2698,
      lng: 55.3131,
    ),
    LocationData(
      city: 'Dubai',
      area: 'Bur Dubai',
      displayName: 'Bur Dubai',
      lat: 25.2587,
      lng: 55.2972,
    ),
    LocationData(
      city: 'Dubai',
      area: 'Al Barsha',
      displayName: 'Al Barsha, Dubai',
      lat: 25.1126,
      lng: 55.1959,
    ),
    LocationData(
      city: 'Dubai',
      area: 'Dubai Silicon Oasis',
      displayName: 'Dubai Silicon Oasis',
      lat: 25.1246,
      lng: 55.3785,
    ),
    LocationData(
      city: 'Dubai',
      area: 'Jumeirah',
      displayName: 'Jumeirah, Dubai',
      lat: 25.2306,
      lng: 55.2631,
    ),
    LocationData(
      city: 'Dubai',
      area: 'International City',
      displayName: 'International City, Dubai',
      lat: 25.1696,
      lng: 55.4091,
    ),
    LocationData(
      city: 'Dubai',
      area: 'Discovery Gardens',
      displayName: 'Discovery Gardens, Dubai',
      lat: 25.0431,
      lng: 55.1385,
    ),

    // Abu Dhabi
    LocationData(
      city: 'Abu Dhabi',
      area: 'Abu Dhabi',
      displayName: 'Abu Dhabi City',
      lat: 24.4539,
      lng: 54.3773,
    ),
    LocationData(
      city: 'Abu Dhabi',
      area: 'Yas Island',
      displayName: 'Yas Island, Abu Dhabi',
      lat: 24.4888,
      lng: 54.6056,
    ),
    LocationData(
      city: 'Abu Dhabi',
      area: 'Saadiyat Island',
      displayName: 'Saadiyat Island, Abu Dhabi',
      lat: 24.5425,
      lng: 54.4358,
    ),
    LocationData(
      city: 'Abu Dhabi',
      area: 'Al Reem Island',
      displayName: 'Al Reem Island, Abu Dhabi',
      lat: 24.4948,
      lng: 54.3989,
    ),
    LocationData(
      city: 'Abu Dhabi',
      area: 'Khalifa City',
      displayName: 'Khalifa City, Abu Dhabi',
      lat: 24.4186,
      lng: 54.5990,
    ),
    LocationData(
      city: 'Abu Dhabi',
      area: 'Al Ain',
      displayName: 'Al Ain',
      lat: 24.2075,
      lng: 55.7447,
    ),

    // Sharjah
    LocationData(
      city: 'Sharjah',
      area: 'Sharjah',
      displayName: 'Sharjah City',
      lat: 25.3463,
      lng: 55.4209,
    ),
    LocationData(
      city: 'Sharjah',
      area: 'Al Majaz',
      displayName: 'Al Majaz, Sharjah',
      lat: 25.3189,
      lng: 55.3778,
    ),
    LocationData(
      city: 'Sharjah',
      area: 'Al Khan',
      displayName: 'Al Khan, Sharjah',
      lat: 25.3297,
      lng: 55.3747,
    ),

    // Ajman
    LocationData(
      city: 'Ajman',
      area: 'Ajman',
      displayName: 'Ajman City',
      lat: 25.4052,
      lng: 55.5136,
    ),
    LocationData(
      city: 'Ajman',
      area: 'Al Nuaimiya',
      displayName: 'Al Nuaimiya, Ajman',
      lat: 25.3906,
      lng: 55.4455,
    ),

    // Ras Al Khaimah
    LocationData(
      city: 'Ras Al Khaimah',
      area: 'Ras Al Khaimah',
      displayName: 'Ras Al Khaimah City',
      lat: 25.7896,
      lng: 55.9433,
    ),

    // Fujairah
    LocationData(
      city: 'Fujairah',
      area: 'Fujairah',
      displayName: 'Fujairah City',
      lat: 25.1288,
      lng: 56.3265,
    ),

    // Umm Al Quwain
    LocationData(
      city: 'Umm Al Quwain',
      area: 'Umm Al Quwain',
      displayName: 'Umm Al Quwain City',
      lat: 25.5647,
      lng: 55.5553,
    ),
  ];

  /// Search locations by query
  static List<LocationData> search(String query) {
    if (query.isEmpty) return cities;

    final lowerQuery = query.toLowerCase();
    return cities.where((location) {
      return location.displayName.toLowerCase().contains(lowerQuery) ||
          location.city.toLowerCase().contains(lowerQuery) ||
          location.area.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}

class LocationData {
  final String city;
  final String area;
  final String displayName;
  final double lat;
  final double lng;

  const LocationData({
    required this.city,
    required this.area,
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}
