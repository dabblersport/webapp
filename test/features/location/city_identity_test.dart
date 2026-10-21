import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/mapbox_place.dart';
import 'package:dabbler/features/location/data/device_location_store.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-587: a chosen City keeps its map-service identity (id and country), so
/// two cities with the same name stay distinct and scope their own Areas.
Area _area(String id, String city, String country) => Area(
  id: id,
  name: 'Area $id',
  district: 'D',
  city: city,
  country: country,
  centerLat: 1,
  centerLng: 2,
);

Future<DeviceLocationStore> _store() async =>
    DeviceLocationStore(await SharedPreferences.getInstance(), accountId: 'u1');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('MapboxPlace reads the country from the v6 context', () {
    final MapboxPlace p = MapboxPlace.fromJson(<String, dynamic>{
      'id': 'dXJuOm1ieHBsYzpBUWc',
      'properties': <String, dynamic>{
        'name': 'Paris',
        'full_address': 'Paris, France',
        'context': <String, dynamic>{
          'country': <String, dynamic>{'name': 'France', 'country_code': 'FR'},
        },
      },
      'geometry': <String, dynamic>{
        'coordinates': <double>[2.35, 48.85],
      },
    });
    expect(
      (p.id, p.country, p.countryCode),
      ('dXJuOm1ieHBsYzpBUWc', 'France', 'FR'),
    );
  });

  group('store keeps the city identity', () {
    test('id and country survive a restart', () async {
      await (await _store()).changeCity(
        'Paris',
        cityId: 'fr-paris',
        country: 'France',
        countryCode: 'FR',
      );
      final DeviceLocation l = (await _store()).read()!;
      expect(
        (l.city, l.cityId, l.country, l.countryCode),
        ('Paris', 'fr-paris', 'France', 'FR'),
      );
    });

    test('same name, other country: a different city, area cleared', () async {
      final s = await _store();
      await s.changeCity('Paris', cityId: 'fr', countryCode: 'FR');
      await s.setManual(city: 'Paris', area: 'Marais', lat: 48.8, lng: 2.3);
      expect((await _store()).read()!.cityId, 'fr', reason: 'identity kept');

      final DeviceLocation tx = await s.changeCity(
        'Paris',
        cityId: 'us-tx',
        country: 'United States',
        countryCode: 'US',
      );
      expect(tx.cityId, 'us-tx');
      expect(tx.area, isNull, reason: 'the French area must not carry over');
      expect(tx.hasPoint, isFalse);
    });

    test('the same city again keeps its area', () async {
      final s = await _store();
      await s.changeCity('Paris', cityId: 'fr', countryCode: 'FR');
      await s.setManual(city: 'Paris', area: 'Marais', lat: 48.8, lng: 2.3);
      final DeviceLocation again = await s.changeCity(
        'Paris',
        cityId: 'fr',
        countryCode: 'fr',
      );
      expect(again.area, 'Marais');
    });

    test('a different city name clears the area (identity or not)', () async {
      final s = await _store();
      await s.setManual(city: 'Dubai', area: 'Deira', lat: 25.2, lng: 55.3);
      final DeviceLocation next = await s.changeCity(
        'Lyon',
        cityId: 'fr-lyon',
        countryCode: 'FR',
      );
      expect(next.area, isNull);
      expect(next.hasPoint, isFalse);
    });
  });

  group('Areas are scoped to the selected city', () {
    final List<Area> areas = <Area>[
      _area('1', 'Paris', 'FR'),
      _area('2', 'Paris', 'US'),
      _area('3', 'Dubai', 'AE'),
    ];
    List<String> ids(List<Area> a) => <String>[for (final x in a) x.id];

    test('Paris, France shows only its own Areas', () {
      final scoped = scopeAreasToCity(
        areas,
        ActiveLocationCityOnly(
          'Paris',
          cityId: 'fr',
          country: 'France',
          countryCode: 'FR',
        ),
      );
      expect(ids(scoped), <String>['1']);
    });

    test('Paris, Texas shows none of the French Areas', () {
      final scoped = scopeAreasToCity(
        areas,
        ActiveLocationCityOnly('Paris', cityId: 'us', countryCode: 'US'),
      );
      expect(ids(scoped), <String>['2']);
    });

    test('a city with no Areas yields none', () {
      expect(
        scopeAreasToCity(
          areas,
          ActiveLocationCityOnly('Oslo', countryCode: 'NO'),
        ),
        isEmpty,
      );
    });

    test('a manual area pick scopes to that area\'s city', () {
      final ActiveLocationState s = ActiveLocationReady(
        ActiveLocation(
          lat: 1,
          lng: 2,
          area: _area('3', 'Dubai', 'AE'),
          nearbyRadiusMeters: 1000,
          source: ActiveLocationSource.manual,
        ),
      );
      expect(ids(scopeAreasToCity(areas, s)), <String>['3']);
    });

    test('no manual city (Auto or nothing): every Area, as before', () {
      expect(scopeAreasToCity(areas, null), hasLength(3));
      final ActiveLocationState gps = ActiveLocationReady(
        ActiveLocation(
          lat: 1,
          lng: 2,
          area: _area('3', 'Dubai', 'AE'),
          nearbyRadiusMeters: 1000,
          source: ActiveLocationSource.gps,
        ),
      );
      expect(scopeAreasToCity(areas, gps), hasLength(3));
    });
  });
}
