import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/features/location/data/device_location_store.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-526: a point chosen in the "Set location" drawer is the active location
/// after a restart, with no GPS read and no permission call.
class _FakePlatform extends GeolocatorPlatform {
  int requestCalls = 0;
  int positionCalls = 0;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.deniedForever;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCalls++;
    return LocationPermission.deniedForever;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    positionCalls++;
    throw const PermissionDeniedException('denied');
  }
}

class _SavedPrimary extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => <ProfileLocation>[
    ProfileLocation(
      id: 'saved-1',
      profileId: 'p1',
      lat: 24.45,
      lng: 54.38,
      areaId: 'abu-dhabi-area',
      label: ProfileLocationLabel.home,
      isPrimary: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];
}

class _OneAreaRepo implements AreaRepository {
  @override
  Future<List<Area>> loadAll() async => [_abuDhabi];
  @override
  Future<Area?> resolveNearest(double lat, double lng) async => _abuDhabi;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _abuDhabi = Area(
  id: 'abu-dhabi-area',
  name: 'Corniche',
  district: 'Abu Dhabi',
  city: 'Abu Dhabi',
  country: 'AE',
  centerLat: 24.45,
  centerLng: 54.38,
);

class _NoSaved extends ProfileLocationNotifier {
  @override
  Future<List<ProfileLocation>> build() async => const <ProfileLocation>[];
}

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [profileLocationNotifierProvider.overrideWith(_NoSaved.new)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform original;
  late _FakePlatform fake;
  setUp(() {
    original = GeolocatorPlatform.instance;
    fake = _FakePlatform();
    GeolocatorPlatform.instance = fake;
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  test('useManualPoint makes the location Ready and persists it', () async {
    SharedPreferences.setMockInitialValues({});
    final c = _container();
    await c.read(activeLocationProvider.future);
    await c
        .read(activeLocationProvider.notifier)
        .useManualPoint(25.1972, 55.2744, 'Downtown Dubai');
    final s = c.read(activeLocationProvider).valueOrNull;
    expect(s, isA<ActiveLocationReady>());
    final loc = (s as ActiveLocationReady).location;
    expect((loc.lat, loc.lng), (25.1972, 55.2744));
    expect(loc.area.name, 'Downtown Dubai');
    expect(loc.source, ActiveLocationSource.manual);
    final prefs = await SharedPreferences.getInstance();
    final stored = DeviceLocationStore(prefs, accountId: null).read()!;
    expect((stored.lat, stored.lng), (25.1972, 55.2744));
    expect(stored.area, 'Downtown Dubai');
    expect(stored.mode, DeviceLocationMode.manual);
    expect(fake.requestCalls, 0);
  });

  test('restart: a new container reads the stored point before the denied '
      'path, without GPS or a permission call', () async {
    SharedPreferences.setMockInitialValues({
      'device_location.-.city': 'Dubai',
      'device_location.-.area': 'Dubai Marina',
      'device_location.-.lat': 25.0805,
      'device_location.-.lng': 55.1396,
      'device_location.-.mode': 'manual',
      'device_location.-.provenance': 'manual',
      'device_location.-.updatedAt': '2026-10-20T10:00:00.000',
      'location_permission_asked': true,
    });
    final c = _container();
    final s = await c.read(activeLocationProvider.future);
    expect(s, isA<ActiveLocationReady>());
    final loc = (s as ActiveLocationReady).location;
    expect((loc.lat, loc.lng), (25.0805, 55.1396));
    expect(loc.area.name, 'Dubai Marina');
    // Let any background work run: none may touch the platform.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      c.read(activeLocationProvider).valueOrNull,
      isA<ActiveLocationReady>(),
    );
    expect(fake.requestCalls, 0);
    expect(fake.positionCalls, 0);
  });

  test('no stored point: the denied path is unchanged', () async {
    SharedPreferences.setMockInitialValues({'location_permission_asked': true});
    final c = _container();
    await c.read(activeLocationProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      c.read(activeLocationProvider).valueOrNull,
      isA<ActiveLocationDenied>(),
    );
    expect(fake.requestCalls, 0);
  });

  Map<String, Object> _seed(
    String uid, {
    required String mode,
    required String provenance,
    String? area = 'Business Bay',
    double? lat = 25.18,
    double? lng = 55.26,
  }) => {
    'device_location.$uid.city': 'Dubai',
    if (area != null) 'device_location.$uid.area': area,
    if (lat != null) 'device_location.$uid.lat': lat,
    if (lng != null) 'device_location.$uid.lng': lng,
    'device_location.$uid.mode': mode,
    'device_location.$uid.provenance': provenance,
    'device_location.$uid.updatedAt': '2026-10-20T10:00:00.000',
    'location_permission_asked': true,
  };

  test('KAN-586 Auto unavailable: the last known point is used, labelled, '
      'and the OS is never asked', () async {
    SharedPreferences.setMockInitialValues(
      _seed('-', mode: 'auto', provenance: 'gps'),
    );
    final c = _container();
    await c.read(activeLocationProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final s = c.read(activeLocationProvider).valueOrNull;
    expect(s, isA<ActiveLocationReady>());
    final loc = (s as ActiveLocationReady).location;
    expect(loc.source, ActiveLocationSource.lastKnown);
    expect((loc.lat, loc.lng), (25.18, 55.26));
    expect(fake.requestCalls, 0);
  });

  test('KAN-586 a city without an area has no point: not Ready', () async {
    SharedPreferences.setMockInitialValues(
      _seed(
        '-',
        mode: 'manual',
        provenance: 'manual',
        area: null,
        lat: null,
        lng: null,
      ),
    );
    final c = _container();
    final s = await c.read(activeLocationProvider.future);
    expect(s, isA<ActiveLocationCityOnly>());
    expect((s as ActiveLocationCityOnly).city, 'Dubai');
    expect(c.read(distanceControlsEnabledProvider), isFalse);
  });

  test('KAN-586 useManualCity clears the previous point', () async {
    SharedPreferences.setMockInitialValues({'location_permission_asked': true});
    final c = _container();
    await c.read(activeLocationProvider.future);
    final n = c.read(activeLocationProvider.notifier);
    await n.useManualPoint(
      25.27,
      55.31,
      'Deira, Dubai',
      city: 'Dubai',
      area: 'Deira',
    );
    expect(c.read(distanceControlsEnabledProvider), isTrue);
    await n.useManualCity('Abu Dhabi');
    expect(
      c.read(activeLocationProvider).valueOrNull,
      isA<ActiveLocationCityOnly>(),
    );
    expect(c.read(distanceControlsEnabledProvider), isFalse);
  });

  test('KAN-586 a stored selection of another account is not shown', () async {
    SharedPreferences.setMockInitialValues(
      _seed('someone-else', mode: 'manual', provenance: 'manual'),
    );
    final c = _container(); // signed-out scope '-'
    await c.read(activeLocationProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      c.read(activeLocationProvider).valueOrNull,
      isNot(isA<ActiveLocationReady>()),
    );
  });

  test(
    'KAN-586 restart: stored Auto wins over a saved primary location',
    () async {
      SharedPreferences.setMockInitialValues(
        _seed('-', mode: 'auto', provenance: 'gps'),
      );
      final c = ProviderContainer(
        overrides: [
          profileLocationNotifierProvider.overrideWith(_SavedPrimary.new),
          areaRepositoryV2Provider.overrideWithValue(_OneAreaRepo()),
        ],
      );
      addTearDown(c.dispose);
      final s = await c.read(activeLocationProvider.future);
      expect(s, isA<ActiveLocationReady>());
      final loc = (s as ActiveLocationReady).location;
      // The device's stored fix (Dubai, Business Bay), not the saved Abu Dhabi.
      expect((loc.lat, loc.lng), (25.18, 55.26));
      expect(loc.source, ActiveLocationSource.gps);
      expect(loc.area.name, 'Business Bay');
      // GPS is denied: after the silent refresh misses it is labelled last known
      // and the OS is never asked.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final after = c.read(activeLocationProvider).valueOrNull;
      expect(
        (after as ActiveLocationReady).location.source,
        ActiveLocationSource.lastKnown,
      );
      expect(fake.requestCalls, 0);
    },
  );

  test('the drawer title key: EN "Set location", AR has its own value', () {
    expect(
      lookupAppLocalizations(const Locale('en')).listing_set_location,
      'Set location',
    );
    expect(
      lookupAppLocalizations(const Locale('ar')).listing_set_location,
      'حدد الموقع',
    );
  });
}
