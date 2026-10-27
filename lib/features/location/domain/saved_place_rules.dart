import 'dart:math' as math;

import 'package:dabbler/data/models/profile_location.dart';

/// Two saved places closer than this are the same location (KAN-589), whatever
/// their labels: a pin dropped twice on one building is one place.
const double kSamePlaceToleranceMeters = 25;

/// Great-circle distance in metres between two points (haversine).
double metersBetween(double lat1, double lng1, double lat2, double lng2) {
  const double earthRadius = 6371000;
  double rad(double d) => d * math.pi / 180;
  final double dLat = rad(lat2 - lat1);
  final double dLng = rad(lng2 - lng1);
  final double a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// The saved place already at ([lat], [lng]) within
/// [kSamePlaceToleranceMeters], or null. [exceptId] skips the place being
/// edited, so a place never collides with itself.
ProfileLocation? savedPlaceAt(
  List<ProfileLocation> places,
  double lat,
  double lng, {
  String? exceptId,
}) {
  for (final ProfileLocation p in places) {
    if (p.id == exceptId || p.lat == null || p.lng == null) continue;
    if (metersBetween(p.lat!, p.lng!, lat, lng) <= kSamePlaceToleranceMeters) {
      return p;
    }
  }
  return null;
}
