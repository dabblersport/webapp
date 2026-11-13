import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/core/config/mapbox_config.dart';
import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';

/// The Mapbox public token: the `MAPBOX_TOKEN` define, else the
/// `MAPBOX_ACCESS_TOKEN` define or `.env` value. The map tiles and every place
/// search read this one value (KAN-589: the search read only `MAPBOX_TOKEN`,
/// so a build that carried the token as `MAPBOX_ACCESS_TOKEN` showed the map
/// but every search came back empty).
String mapboxTileToken() {
  if (MapboxConfig.accessToken.isNotEmpty) return MapboxConfig.accessToken;
  try {
    return Environment.mapboxAccessToken;
  } catch (_) {
    return '';
  }
}

/// The Mapbox token the map and the place searches use. Tests override it.
final mapTokenProvider = Provider<String>((ref) => mapboxTileToken());

/// The HTTP client of the place searches. Tests override it.
final mapboxHttpClientProvider = Provider<http.Client>((ref) => http.Client());

/// Address / place search (KAN-589): any place by name, worldwide, biased
/// toward the active location. Queries shorter than 2 characters return empty.
/// A failed request is an error (the dropdown says so), never "no results".
/// Results are cached per query string (Riverpod's family cache).
///
/// It asks the Search Box API, not Geocoding v6: v6 has no points of
/// interest, so a venue or mall name came back as unrelated streets in other
/// countries. City and area searches below stay on v6, where `types` limits
/// them to places and neighbourhoods.
final mapboxGeocodeProvider = FutureProvider.family<List<MapboxPlace>, String>((
  ref,
  query,
) async {
  if (query.trim().length < 2) return [];

  final params = <String, String>{'q': query.trim(), 'limit': '8'};

  // Bias results toward the user's active location if available.
  final locState = ref.read(activeLocationProvider).valueOrNull;
  if (locState is ActiveLocationReady) {
    final loc = locState.location;
    params['proximity'] = '${loc.lng},${loc.lat}';
  }

  return _forward(ref, params, baseUrl: MapboxConfig.searchBoxForwardUrl);
});

/// City-only search (KAN-587): Mapbox `place` results worldwide, no country
/// restriction and never an address, area or POI. The chosen city's name, id
/// and country are the canonical City the device stores. Queries under 2
/// characters return empty. A failed request is an error (not "no results"),
/// so the UI can offer a retry.
final mapboxCityProvider = FutureProvider.family<List<MapboxPlace>, String>((
  ref,
  query,
) async {
  if (query.trim().length < 2) return [];
  final List<MapboxPlace> all = await _forward(ref, <String, String>{
    'q': query,
    'limit': '8',
    'types': 'place',
    'language': 'en',
  });
  final seen = <String>{};
  return [
    for (final p in all)
      if (seen.add(p.fullAddress)) p,
  ];
});

/// City search inside one country (KAN-640): the manual flow picks the country
/// first, so only that country's cities are searched.
typedef CountryCityQuery = ({String query, String countryCode});

final mapboxCountryCityProvider =
    FutureProvider.family<List<MapboxPlace>, CountryCityQuery>((ref, q) async {
      if (q.query.trim().length < 2) return [];
      final List<MapboxPlace> all = await _forward(ref, <String, String>{
        'q': q.query,
        'limit': '8',
        'types': 'place',
        'language': 'en',
        'country': q.countryCode.toLowerCase(),
      });
      final seen = <String>{};
      return [
        for (final p in all)
          if (seen.add(p.fullAddress)) p,
      ];
    });

/// Area search inside a chosen city (KAN-587): Mapbox neighborhoods, localities
/// and districts, limited to the city's country and biased to its point.
typedef AreaQuery = ({String query, String? countryCode, String? proximity});

final mapboxAreaProvider = FutureProvider.family<List<MapboxPlace>, AreaQuery>((
  ref,
  q,
) async {
  if (q.query.trim().length < 2) return [];
  return _forward(ref, <String, String>{
    'q': q.query,
    'limit': '8',
    'types': 'neighborhood,locality,district',
    'language': 'en',
    if (q.countryCode != null) 'country': q.countryCode!.toLowerCase(),
    if (q.proximity != null) 'proximity': q.proximity!,
  });
});

Future<List<MapboxPlace>> _forward(
  Ref ref,
  Map<String, String> params, {
  String baseUrl = MapboxConfig.geocodeBaseUrl,
}) async {
  final String token = ref.read(mapTokenProvider);
  if (token.isEmpty) {
    throw StateError('Map service is not configured');
  }
  final uri = Uri.parse(baseUrl).replace(
    queryParameters: <String, String>{...params, 'access_token': token},
  );
  final response = await ref.read(mapboxHttpClientProvider).get(uri);
  if (response.statusCode != 200) {
    throw StateError('Map service error ${response.statusCode}');
  }
  final body = json.decode(response.body) as Map<String, dynamic>;
  final features = body['features'] as List<dynamic>? ?? [];
  return [
    for (final f in features) MapboxPlace.fromJson(f as Map<String, dynamic>),
  ];
}
