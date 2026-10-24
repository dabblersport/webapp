import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:dabbler/core/config/mapbox_config.dart';
import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';

/// Family provider: takes a query string, returns `List<MapboxPlace>`.
/// Returns empty list for queries shorter than 2 chars.
/// Caches results per unique query string (via Riverpod's built-in cache).
final mapboxGeocodeProvider = FutureProvider.family<List<MapboxPlace>, String>((
  ref,
  query,
) async {
  if (query.trim().length < 2) return [];
  if (MapboxConfig.accessToken.isEmpty) return [];

  final params = <String, String>{
    'q': query,
    'access_token': MapboxConfig.accessToken,
    'limit': '5',
    'country': 'ae',
    'language': 'en',
  };

  // Bias results toward the user's active location if available.
  final locState = ref.read(activeLocationProvider).valueOrNull;
  if (locState is ActiveLocationReady) {
    final loc = locState.location;
    params['proximity'] = '${loc.lng},${loc.lat}';
  }

  try {
    final uri = Uri.parse(
      MapboxConfig.geocodeBaseUrl,
    ).replace(queryParameters: params);
    final response = await http.get(uri);

    if (response.statusCode != 200) return [];

    final body = json.decode(response.body) as Map<String, dynamic>;
    final features = body['features'] as List<dynamic>? ?? [];

    return features
        .map((f) => MapboxPlace.fromJson(f as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
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
  final List<MapboxPlace> all = await _forward(<String, String>{
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
      final List<MapboxPlace> all = await _forward(<String, String>{
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
  return _forward(<String, String>{
    'q': q.query,
    'limit': '8',
    'types': 'neighborhood,locality,district',
    'language': 'en',
    if (q.countryCode != null) 'country': q.countryCode!.toLowerCase(),
    if (q.proximity != null) 'proximity': q.proximity!,
  });
});

Future<List<MapboxPlace>> _forward(Map<String, String> params) async {
  if (MapboxConfig.accessToken.isEmpty) {
    throw StateError('Map service is not configured');
  }
  final uri = Uri.parse(MapboxConfig.geocodeBaseUrl).replace(
    queryParameters: <String, String>{
      ...params,
      'access_token': MapboxConfig.accessToken,
    },
  );
  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw StateError('Map service error ${response.statusCode}');
  }
  final body = json.decode(response.body) as Map<String, dynamic>;
  final features = body['features'] as List<dynamic>? ?? [];
  return [
    for (final f in features) MapboxPlace.fromJson(f as Map<String, dynamic>),
  ];
}
