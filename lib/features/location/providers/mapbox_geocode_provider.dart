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
/// restriction and never an address, area or POI. The chosen city's name is the
/// canonical City the device stores. Queries under 2 characters return empty.
final mapboxCityProvider = FutureProvider.family<List<MapboxPlace>, String>((
  ref,
  query,
) async {
  if (query.trim().length < 2) return [];
  if (MapboxConfig.accessToken.isEmpty) return [];

  final params = <String, String>{
    'q': query,
    'access_token': MapboxConfig.accessToken,
    'limit': '8',
    'types': 'place',
    'language': 'en',
  };

  try {
    final uri = Uri.parse(
      MapboxConfig.geocodeBaseUrl,
    ).replace(queryParameters: params);
    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final body = json.decode(response.body) as Map<String, dynamic>;
    final features = body['features'] as List<dynamic>? ?? [];
    final seen = <String>{};
    return [
      for (final f in features)
        if (seen.add(
          MapboxPlace.fromJson(f as Map<String, dynamic>).fullAddress,
        ))
          MapboxPlace.fromJson(f),
    ];
  } catch (_) {
    return [];
  }
});
