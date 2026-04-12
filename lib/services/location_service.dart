import 'package:geolocator/geolocator.dart';

class LocationService {
  // Dubai Downtown fallback coordinates
  static const double _fallbackLat = 25.2048;
  static const double _fallbackLng = 55.2708;

  Future<({double lat, double lng})> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return _fallback();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return _fallback();
    }
    if (permission == LocationPermission.deniedForever) return _fallback();

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return (lat: position.latitude, lng: position.longitude);
  }

  ({double lat, double lng}) _fallback() =>
      (lat: _fallbackLat, lng: _fallbackLng);
}
