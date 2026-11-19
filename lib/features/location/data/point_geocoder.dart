import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' show placemarkFromCoordinates;

/// Reverse-geocodes a point to a display name (KAN-1025), or null when there
/// is none or the lookup fails. Display only: never persisted.
typedef PointGeocoder = Future<String?> Function(double lat, double lng);

Future<String?> _placemarkName(double lat, double lng) async {
  try {
    final placemarks = await placemarkFromCoordinates(lat, lng);
    if (placemarks.isEmpty) return null;
    final pm = placemarks.first;
    for (final String? v in [
      pm.locality,
      pm.subLocality,
      pm.administrativeArea,
    ]) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Injectable so tests can answer without the platform plugin.
final pointGeocoderProvider = Provider<PointGeocoder>((ref) => _placemarkName);
