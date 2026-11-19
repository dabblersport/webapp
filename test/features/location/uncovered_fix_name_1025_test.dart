import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/location/data/device_location_store.dart';
import 'package:dabbler/features/location/data/point_geocoder.dart';
import 'package:dabbler/features/location/presentation/active_location_label.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// KAN-1025: a device fix outside every covered Area shows a reverse-geocoded
// name; the stored location and the Area stay nameless.

class _Uncovered implements AreaRepository {
  @override
  Future<Area?> resolveNearest(double lat, double lng) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoSaved extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => const <ProfileLocation>[];
}

class _Platform extends GeolocatorPlatform {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.always;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 24.4539,
    longitude: 54.3773,
    timestamp: DateTime(2026),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

ProviderContainer _container(PointGeocoder geocoder) {
  final c = ProviderContainer(
    overrides: [
      profileLocationNotifierProvider.overrideWith(_NoSaved.new),
      areaRepositoryV2Provider.overrideWithValue(_Uncovered()),
      pointGeocoderProvider.overrideWithValue(geocoder),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<ActiveLocation> _fix(ProviderContainer c) async {
  await c.read(activeLocationProvider.future);
  await c.read(activeLocationProvider.notifier).useGpsLocation();
  await pumpEventQueue();
  return (c.read(activeLocationProvider).value as ActiveLocationReady).location;
}

String _label(ProviderContainer c) => activeLocationLabel(
  AppLocalizationsEn(),
  c.read(activeLocationProvider).valueOrNull,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform original;
  setUp(() {
    original = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _Platform();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  test('an uncovered fix is labelled with its geocoded name', () async {
    final c = _container((_, _) async => 'Abu Dhabi');
    final loc = await _fix(c);
    expect(loc.displayName, 'Abu Dhabi');
    expect(loc.area.name, isEmpty);
    expect(loc.area.city, isEmpty);
    expect(_label(c), 'Abu Dhabi');
  });

  test('a failed lookup keeps "Current location"', () async {
    final c = _container((_, _) async => throw Exception('no network'));
    final loc = await _fix(c);
    expect(loc.displayName, isNull);
    expect(_label(c), 'Current location');
  });

  test('the persisted location is unchanged by the name', () async {
    final c = _container((_, _) async => 'Abu Dhabi');
    await _fix(c);
    final stored = DeviceLocationStore(
      await SharedPreferences.getInstance(),
      accountId: null,
    ).read()!;
    expect(stored.area, isNull);
    expect(stored.city, isEmpty);
    expect(stored.lat, 24.4539);
  });

  test('label order: city beats displayName', () {
    final s = ActiveLocationReady(
      const ActiveLocation(
        lat: 1,
        lng: 1,
        area: Area(
          id: 'point',
          name: '',
          district: '',
          city: 'Dubai',
          country: '',
          centerLat: 1,
          centerLng: 1,
        ),
        source: ActiveLocationSource.gps,
        displayName: 'Elsewhere',
      ),
    );
    expect(activeLocationLabel(AppLocalizationsEn(), s), 'Dubai');
  });
}
