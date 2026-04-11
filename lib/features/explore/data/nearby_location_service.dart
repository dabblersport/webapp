/// Thin wrapper that surfaces a lat/lng pair for the nearby system.
///
/// Currently returns a hardcoded mock location (Dubai).
/// Swap the implementation to use the global [LocationService] / Geolocator
/// when real device location is wired up.
class NearbyLocationService {
  const NearbyLocationService();

  static const double _mockLat = 25.09;
  static const double _mockLng = 55.15;

  /// Returns the user's current (lat, lng).
  /// For now returns the mock coordinates.
  ({double lat, double lng}) getUserLocation() {
    return (lat: _mockLat, lng: _mockLng);
  }
}
