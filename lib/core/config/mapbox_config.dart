class MapboxConfig {
  MapboxConfig._();

  /// Read from --dart-define=MAPBOX_TOKEN=... at build time.
  /// Falls back to empty string in debug if not provided.
  static const String accessToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '',
  );

  /// Geocoding API base URL
  static const String geocodeBaseUrl =
      'https://api.mapbox.com/search/geocode/v6/forward';
}
