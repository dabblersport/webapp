import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const String _cachedAreaKey = 'cached_area';
  static const String _cachedLatKey = 'cached_latitude';
  static const String _cachedLngKey = 'cached_longitude';
  static const String _locationPromptPreferenceKey =
      'location_prompt_preference';

  String? _currentArea;
  Position? _currentPosition;
  bool _permissionDenied = false;
  bool _isLoading = false;
  Timer? _locationUpdateTimer;

  String? get currentArea => _currentArea;
  Position? get currentPosition => _currentPosition;
  bool get permissionDenied => _permissionDenied;
  bool get isLoading => _isLoading;
  bool get hasLocation => _currentPosition != null;

  Future<void> init() async {
    await _loadCachedLocation();
    await fetchLocation();
    _startPeriodicLocationUpdates();
  }

  void _startPeriodicLocationUpdates() {
    // Cancel existing timer if any
    _locationUpdateTimer?.cancel();

    // Update location every 15 minutes
    _locationUpdateTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => fetchLocation(),
    );
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchLocation() async {
    _isLoading = true;
    notifyListeners();
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      print('Location permission status: $permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('Permission after request: $permission');
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _permissionDenied = true;
        _isLoading = false;
        notifyListeners();
        print('Location permission denied');
        return;
      }
      _permissionDenied = false;
      print('Getting current position...');
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print(
        'Position obtained: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}',
      );
      await _reverseGeocode(_currentPosition!);
      print('Current area: $_currentArea');
      await _cacheLocation(_currentPosition!, _currentArea);
    } catch (e) {
      print('Location fetch error: $e');
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _reverseGeocode(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        _currentArea = placemark.subLocality?.isNotEmpty == true
            ? placemark.subLocality
            : placemark.locality?.isNotEmpty == true
            ? placemark.locality
            : placemark.administrativeArea?.isNotEmpty == true
            ? placemark.administrativeArea
            : placemark.country;
      } else {
        _currentArea = null;
      }
    } catch (e) {
      _currentArea = null;
    }
  }

  Future<void> _cacheLocation(Position position, String? area) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cachedLatKey, position.latitude);
    await prefs.setDouble(_cachedLngKey, position.longitude);
    if (area != null) {
      await prefs.setString(_cachedAreaKey, area);
    }
  }

  Future<void> _loadCachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_cachedLatKey);
    final lng = prefs.getDouble(_cachedLngKey);
    final area = prefs.getString(_cachedAreaKey);
    if (lat != null && lng != null) {
      _currentPosition = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
    _currentArea = area;
  }

  Future<void> overrideLocation(String area) async {
    _currentArea = area;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedAreaKey, area);
    notifyListeners();
  }

  Future<void> setManualLocation(
    String area, {
    double? latitude,
    double? longitude,
  }) async {
    _currentArea = area;
    _permissionDenied =
        false; // Reset permission denied if user sets location manually

    // If coordinates provided, create a Position object
    if (latitude != null && longitude != null) {
      _currentPosition = Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedAreaKey, area);
    if (latitude != null && longitude != null) {
      await prefs.setDouble(_cachedLatKey, latitude);
      await prefs.setDouble(_cachedLngKey, longitude);
    }
    notifyListeners();
  }

  Future<void> clearLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedAreaKey);
    await prefs.remove(_cachedLatKey);
    await prefs.remove(_cachedLngKey);
    _currentArea = null;
    _currentPosition = null;
    notifyListeners();
  }

  /// Check if we should show the location permission prompt
  /// Returns true if user hasn't decided yet (remind later or never asked)
  Future<bool> shouldShowLocationPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final preference = prefs.getString(_locationPromptPreferenceKey);
    // Show if never asked or if user chose "remind later"
    return preference == null || preference == 'remind_later';
  }

  /// Save user's location permission preference
  /// Options: 'allow', 'remind_later', 'never'
  Future<void> saveLocationPreference(String preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationPromptPreferenceKey, preference);
  }

  /// Check current permission status without requesting
  Future<LocationPermission> checkPermissionStatus() async {
    return await Geolocator.checkPermission();
  }
}
