import 'dart:math' as math;

/// Sort orders of the Venues listing (`Listings.dc.html:1838`).
enum VenueSortOrder {
  distance('distance'),
  rating('rating'),
  price('price');

  const VenueSortOrder(this.rpcValue);

  /// The `p_sort` value `rpc_get_nearby_venues` understands.
  final String rpcValue;
}

/// "Price per hour" presets of the filter sheet (`Listings.dc.html:1836`).
/// Null is "Any price".
const List<double> kVenueMaxPricePresets = <double>[80, 150];

/// "Rating" presets of the filter sheet (`Listings.dc.html:1837`).
const List<double> kVenueMinRatingPresets = <double>[4.0, 4.5];

/// Rating at or above which a venue is badged "Top rated".
const double kVenueTopRated = 4.5;

/// Search-area steps, in metres, the empty state's "Expand search area" walks.
const List<int> kVenueRadiusSteps = <int>[5000, 10000, 20000, 50000];

/// The next radius step above [current], or null at the largest.
int? nextVenueRadius(int current) {
  for (final step in kVenueRadiusSteps) {
    if (step > current) return step;
  }
  return null;
}

/// Great-circle distance in metres between two coordinates (haversine).
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(a)));
}

/// Amenity catalog key (`amenities_catalog.key`) to the facility glyph.
/// Keys without a glyph draw no facility.
const Map<String, String> kVenueAmenityIcons = <String, String>{
  'parking': 'car',
  'valet_parking': 'car',
  'showers': 'drop',
  'washrooms': 'drop',
  'changing_rooms': 'lock',
  'cafeteria': 'cup',
  'juice_bar': 'cup',
  'lighting': 'flash',
  'pro_shop': 'shop',
  'equipment_rental': 'shop',
};
