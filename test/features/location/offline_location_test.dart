import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-607: offline, the saved location stays, an area that cannot be
/// resolved keeps the last saved area, and no permission prompt appears.
class _Platform extends GeolocatorPlatform {
  _Platform({this.permission = LocationPermission.always});
  final LocationPermission permission;
  int requestCalls = 0;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCalls++;
    return permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 25.0805,
    longitude: 55.1396,
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

/// The area lookup fails the way it does with no network.
class _OfflineAreas implements AreaRepository {
  @override
  Future<List<Area>> loadAll() async => throw Exception('offline');
  @override
  Future<Area?> resolveNearest(double lat, double lng) async =>
      throw Exception('offline');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoSaved extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => const <ProfileLocation>[];
}

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [
      profileLocationNotifierProvider.overrideWith(_NoSaved.new),
      areaRepositoryV2Provider.overrideWithValue(_OfflineAreas()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform original;
  setUp(() => original = GeolocatorPlatform.instance);
  tearDown(() => GeolocatorPlatform.instance = original);

  test('a saved manual location shows offline with no area lookup', () async {
    final platform = _Platform(permission: LocationPermission.deniedForever);
    GeolocatorPlatform.instance = platform;
    SharedPreferences.setMockInitialValues({
      'device_location.-.city': 'Dubai',
      'device_location.-.area': 'Dubai Marina',
      'device_location.-.lat': 25.0805,
      'device_location.-.lng': 55.1396,
      'device_location.-.mode': 'manual',
      'device_location.-.provenance': 'manual',
      'device_location.-.updatedAt': '2026-10-20T10:00:00.000',
    });
    final s = await _container().read(activeLocationProvider.future);
    expect(s, isA<ActiveLocationReady>());
    expect((s as ActiveLocationReady).location.area.name, 'Dubai Marina');
    expect(platform.requestCalls, 0);
  });

  test(
    'GPS fix whose area cannot be resolved keeps the last saved area',
    () async {
      GeolocatorPlatform.instance = _Platform();
      SharedPreferences.setMockInitialValues({
        'device_location.-.city': 'Dubai',
        'device_location.-.area': 'Dubai Marina',
        'device_location.-.lat': 25.0805,
        'device_location.-.lng': 55.1396,
        'device_location.-.mode': 'auto',
        'device_location.-.provenance': 'gps',
        'device_location.-.updatedAt': '2026-10-20T10:00:00.000',
      });
      final c = _container();
      await c.read(activeLocationProvider.future);
      await c.read(activeLocationProvider.notifier).useGpsLocation();
      final s = c.read(activeLocationProvider).valueOrNull;
      expect(s, isA<ActiveLocationReady>());
      expect((s as ActiveLocationReady).location.area.name, 'Dubai Marina');
    },
  );

  test('nothing saved and the area unresolved is "Set location", not an '
      'English error', () async {
    GeolocatorPlatform.instance = _Platform();
    SharedPreferences.setMockInitialValues({});
    final c = _container();
    await c.read(activeLocationProvider.future);
    await c.read(activeLocationProvider.notifier).useGpsLocation();
    final s = c.read(activeLocationProvider).valueOrNull;
    expect(s, isNot(isA<ActiveLocationError>()));
    expect(s, isA<ActiveLocationDenied>());
  });
}
