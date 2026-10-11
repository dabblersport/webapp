import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerMotion;
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
  /// The hard cap on how long any caller waits for a position fix (about 8 s).
  /// Callers that cannot afford the full high-then-medium retry (16 s) pass it
  /// as [getCurrentLocation]'s `cap`.
  static const Duration fixCap = Duration(seconds: 8);

  /// Reads the current position.
  ///
  /// With [requestPermission] true (the default; every explicit "use my
  /// location" action) a denied permission is asked for. Background
  /// initialisation passes false: it only reads what the user already allowed
  /// and NEVER shows the system prompt (a denied permission is simply
  /// [LocationDenied]).
  ///
  /// With a [cap] the wait for the fix itself (never the permission prompt,
  /// which waits on the user) is a single attempt of at most [cap]; a miss is
  /// [LocationTimeout]. Without it: high accuracy 10 s, then medium 6 s.
  Future<LocationResult> getCurrentLocation({
    bool requestPermission = true,
    Duration? cap,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    // 1. Service enabled?
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationServiceOff();

    // 2. Permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationDeniedForever();
    }
    if (permission == LocationPermission.denied) {
      return LocationDenied();
    }

    // 3. The fix. Capped: one attempt.
    if (cap != null) return _fix(accuracy, cap, timedOut: LocationTimeout());

    // Uncapped: high accuracy, 10 s, then one medium retry.
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(DabblerMotion.timeoutNetwork);
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

  /// The device's last known position (fast, no new fix, never prompts), or
  /// null when there is none or the platform has none (web).
  Future<LocationSuccess?> getLastKnownLocation() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return null;
      return LocationSuccess(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyMeters: pos.accuracy,
      );
    } catch (_) {
      return null;
    }
  }

  Future<LocationResult> _fix(
    LocationAccuracy accuracy,
    Duration cap, {
    required LocationResult timedOut,
  }) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
      ).timeout(cap);
      return LocationSuccess(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyMeters: pos.accuracy,
      );
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout') || msg.contains('timed out')) return timedOut;
      return LocationError(e.toString());
    }
  }

  Future<LocationResult> _retryMedium() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(DabblerMotion.timeoutShort);
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
