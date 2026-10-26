// KAN-589 round E, defect 1: the address search asked Mapbox Geocoding v6,
// which has no points of interest. In the real app "Dubai Mall" came back as
// "Al Mail Street" and "Avenue Dubai, Morocco" (network log, 2026-10-25).
// The earlier test stubbed the HTTP client without looking at which API was
// asked, so it passed against the wrong endpoint. These tests pin the API and
// the Search Box response shape (no top-level id; `properties.mapbox_id`).
import 'dart:convert';

import 'package:dabbler/core/config/mapbox_config.dart';
import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/mapbox_geocode_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Active extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

/// One Search Box `/forward` feature, as the live API returns it.
Map<String, dynamic> _searchBoxPoi() => {
  'type': 'Feature',
  'geometry': {
    'type': 'Point',
    'coordinates': [55.279605, 25.198055],
  },
  'properties': {
    'name': 'The Dubai Mall',
    'mapbox_id': 'dXJuOm1ieHBvaTpkdWJhaS1tYWxs',
    'feature_type': 'poi',
    'place_formatted': 'Dubai, United Arab Emirates',
    'context': {
      'country': {'name': 'United Arab Emirates', 'country_code': 'AE'},
    },
  },
};

void main() {
  test('the place search asks the Search Box API, which has points of '
      'interest', () async {
    final List<Uri> asked = [];
    // Like the live services: only Search Box knows the mall.
    final client = MockClient((http.Request r) async {
      asked.add(r.url);
      final bool searchBox = r.url.path.startsWith('/search/searchbox/');
      return http.Response(
        jsonEncode({
          'type': 'FeatureCollection',
          'features': searchBox ? [_searchBoxPoi()] : [],
        }),
        200,
      );
    });
    final c = ProviderContainer(
      overrides: [
        activeLocationProvider.overrideWith(_Active.new),
        mapTokenProvider.overrideWithValue('pk.test'),
        mapboxHttpClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(c.dispose);

    final results = await c.read(mapboxGeocodeProvider('Dubai Mall').future);

    expect(
      asked.single.toString().split('?').first,
      MapboxConfig.searchBoxForwardUrl,
    );
    expect(asked.single.queryParameters['q'], 'Dubai Mall');
    expect(results, hasLength(1));
    expect(results.single.name, 'The Dubai Mall');
    expect(results.single.lat, closeTo(25.198055, 1e-9));
    expect(results.single.lng, closeTo(55.279605, 1e-9));
  });

  test('a Search Box feature keeps its id and address', () {
    final MapboxPlace p = MapboxPlace.fromJson(_searchBoxPoi());
    expect(p.id, 'dXJuOm1ieHBvaTpkdWJhaS1tYWxs');
    expect(p.fullAddress, 'Dubai, United Arab Emirates');
    expect(p.countryCode, 'AE');
  });

  test('city search stays on Geocoding v6, limited to places', () async {
    final List<Uri> asked = [];
    final client = MockClient((http.Request r) async {
      asked.add(r.url);
      return http.Response(jsonEncode({'features': []}), 200);
    });
    final c = ProviderContainer(
      overrides: [
        mapTokenProvider.overrideWithValue('pk.test'),
        mapboxHttpClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(c.dispose);

    await c.read(mapboxCityProvider('Dubai').future);

    expect(asked.single.toString(), startsWith(MapboxConfig.geocodeBaseUrl));
    expect(asked.single.queryParameters['types'], 'place');
  });
}
