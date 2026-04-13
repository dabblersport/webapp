import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

// =============================================================================
// RESULT TYPES
// =============================================================================

sealed class LocationResult {}

class LocationSuccess extends LocationResult {
  LocationSuccess({
    required this.lat,
    required this.lng,
    required this.accuracyMeters,
  });

  final double lat;
  final double lng;
  final double accuracyMeters;
}

/// Permission denied but can still be requested again.
class LocationDenied extends LocationResult {}

/// Permission permanently denied — must redirect to app settings.
class LocationDeniedForever extends LocationResult {}

/// Device location services (GPS radio) are switched off.
class LocationServiceOff extends LocationResult {}

/// GPS timed out on both high and medium accuracy attempts.
class LocationTimeout extends LocationResult {}

class LocationError extends LocationResult {
  LocationError(this.message);
  final String message;
}

// =============================================================================
// SERVICE
// =============================================================================

/// Thin, stateless GPS service that returns a typed [LocationResult].
///
/// Never throws — all errors are encoded in the sealed return type.
///
/// Flow:
/// 1. Check if location service is enabled.
/// 2. Check / request permission.
/// 3. Fetch with [LocationAccuracy.high], 10 s timeout.
/// 4. On timeout, retry once with [LocationAccuracy.medium], 6 s timeout.
class GpsService {
  Future<LocationResult> getCurrentLocation() async {
    // 1. Service enabled?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationServiceOff();

    // 2. Permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationDeniedForever();
    }
    if (permission == LocationPermission.denied) {
      return LocationDenied();
    }

    // 3. High accuracy, 10 s
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
      return LocationSuccess(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyMeters: pos.accuracy,
      );
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout') || msg.contains('timed out')) {
        return _retryMedium();
      }
      return LocationError(e.toString());
    }
  }

  Future<LocationResult> _retryMedium() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 6));
      return LocationSuccess(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyMeters: pos.accuracy,
      );
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout') || msg.contains('timed out')) {
        return LocationTimeout();
      }
      return LocationError(e.toString());
    }
  }
}

// =============================================================================
// PROVIDERS
// =============================================================================

final gpsServiceProvider = Provider<GpsService>((ref) => GpsService());

/// Alias matching the task spec name.
final locationServiceProvider = gpsServiceProvider;
