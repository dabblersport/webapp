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

  /// Search Box API forward search (KAN-589): the address / place search.
  /// Geocoding v6 has no points of interest, so "Dubai Mall" there returned
  /// "Al Mail Street" and "Avenue Dubai, Morocco"; Search Box returns the
  /// mall, streets and addresses, in English and Arabic.
  static const String searchBoxForwardUrl =
      'https://api.mapbox.com/search/searchbox/v1/forward';
}
