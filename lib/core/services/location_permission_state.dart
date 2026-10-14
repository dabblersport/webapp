import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one-prompt rule for location (CEO, 2026-10-13): the app asks the OS for
/// location permission AT MOST ONCE per device, and that fact survives app
/// restarts. After that it never asks again.
///
/// "Denied" is derived, never stored: asked == true while the platform's own
/// permission is not granted. If the user later grants location in the OS
/// settings the platform reports granted and everything works; this flag never
/// blocks reading a granted permission.
abstract final class LocationPermissionState {
  const LocationPermissionState._();

  /// The SharedPreferences key (device level, not per user).
  static const String askedKey = 'location_permission_asked';

  /// Whether the OS prompt was already requested on this device.
  static Future<bool> asked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(askedKey) ?? false;
  }

  /// Records that the prompt is being requested. Called immediately BEFORE the
  /// platform request, so a crash mid-prompt cannot allow a second prompt.
  static Future<void> markAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(askedKey, true);
  }

  /// Asks the OS at most once per device. If the prompt was already requested
  /// the platform is NOT called and the current permission is returned.
  ///
  /// This is the ONLY place in the app that calls the platform's
  /// `requestPermission`; every prompt path (the location intro, `GpsService`,
  /// `LocationService`, the location picker sheet) goes through it.
  static Future<LocationPermission> requestOnce() {
    // Overlapping callers share ONE in-flight request: two first calls cannot
    // both read "not asked" and both reach the platform.
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  static Future<LocationPermission>? _inFlight;

  static Future<LocationPermission> _run() async {
    if (await asked()) return Geolocator.checkPermission();
    await markAsked();
    return Geolocator.requestPermission();
  }
}

/// Whether the OS location prompt was already requested on this device.
final locationPermissionAskedProvider = FutureProvider.autoDispose<bool>(
  (ref) => LocationPermissionState.asked(),
);
