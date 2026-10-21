import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/location/data/device_location_store.dart';
import 'package:dabbler/features/location/presentation/active_location_label.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-589 criteria 1, 2 and 3: saved places keep custom labels; selecting one
/// is Manual on this device and shows its label; Auto matches by canonical
/// area membership (one label shows, several show the area name).

const _marina = Area(
  id: 'area-marina',
  name: 'Dubai Marina',
  district: 'Marina',
  city: 'Dubai',
  country: 'AE',
  centerLat: 25.08,
  centerLng: 55.14,
);
const _deira = Area(
  id: 'area-deira',
  name: 'Deira',
  district: 'Deira',
  city: 'Dubai',
  country: 'AE',
  centerLat: 25.27,
  centerLng: 55.31,
);

ProfileLocation _place(
  String id,
  String areaId, {
  ProfileLocationLabel label = ProfileLocationLabel.custom,
  String? custom,
  double lat = 25.08,
  double lng = 55.14,
}) => ProfileLocation(
  id: id,
  profileId: 'p1',
  areaId: areaId,
  lat: lat,
  lng: lng,
  label: label,
  labelCustom: custom,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _Areas implements AreaRepository {
  _Areas(this.resolveTo);
  final Area resolveTo;
  @override
  Future<List<Area>> loadAll() async => [_marina, _deira];
  @override
  Future<Area?> resolveNearest(double lat, double lng) async => resolveTo;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Saved extends ProfileLocationNotifier {
  _Saved(this.places);
  final List<ProfileLocation> places;
  @override
  Future<List<ProfileLocation>> build() async => places;
}

class _Platform extends GeolocatorPlatform {
  int requestCalls = 0;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.always;
  @override
  Future<LocationPermission> requestPermission() async {
    requestCalls++;
    return LocationPermission.always;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: 25.08,
    longitude: 55.14,
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

ProviderContainer _container(List<ProfileLocation> places, Area gpsArea) {
  final c = ProviderContainer(
    overrides: [
      profileLocationNotifierProvider.overrideWith(() => _Saved(places)),
      areaRepositoryV2Provider.overrideWithValue(_Areas(gpsArea)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

String _label(ProviderContainer c) => activeLocationLabel(
  AppLocalizationsEn(),
  c.read(activeLocationProvider).valueOrNull,
);

Future<DeviceLocation> _stored() async => DeviceLocationStore(
  await SharedPreferences.getInstance(),
  accountId: null,
).read()!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform original;
  late _Platform platform;
  setUp(() {
    original = GeolocatorPlatform.instance;
    platform = _Platform();
    GeolocatorPlatform.instance = platform;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  group('AC1 custom labels', () {
    test('a custom label such as Gym is the place label; Home and Work keep '
        'theirs', () {
      expect(_place('g', 'a', custom: 'Gym').effectiveLabel, 'Gym');
      expect(
        _place('h', 'a', label: ProfileLocationLabel.home).effectiveLabel,
        'Home',
      );
      expect(
        _place('w', 'a', label: ProfileLocationLabel.work).effectiveLabel,
        'Work',
      );
    });

    test('a blank custom name never shows as an empty label', () {
      expect(_place('x', 'a', custom: '   ').effectiveLabel, 'Custom');
    });

    test('selecting a saved place is Manual on this device, shows its label '
        'and survives a restart', () async {
      final places = [
        _place('g', 'area-marina', custom: 'Gym'),
        _place('h', 'area-marina', label: ProfileLocationLabel.home),
      ];
      final c = _container(places, _deira);
      await c.read(activeLocationProvider.future);
      await c
          .read(activeLocationProvider.notifier)
          .useSavedLocation(places.first);

      // Two labels share the area, and the explicit choice still shows Gym.
      expect(_label(c), 'Gym');
      final stored = await _stored();
      expect(stored.mode, DeviceLocationMode.manual);
      expect(stored.savedLabel, 'Gym');
      expect(stored.area, 'Dubai Marina');

      // A restart: a new container over the same device storage.
      final restarted = _container(places, _deira);
      await restarted.read(activeLocationProvider.future);
      expect(_label(restarted), 'Gym');
      expect(platform.requestCalls, 0);
    });

    test('this device only: nothing but the device store is written', () async {
      final places = [_place('g', 'area-marina', custom: 'Gym')];
      final c = _container(places, _deira);
      await c.read(activeLocationProvider.future);
      await c
          .read(activeLocationProvider.notifier)
          .useSavedLocation(places.first);
      final keys = (await SharedPreferences.getInstance()).getKeys();
      expect(keys, isNotEmpty);
      expect(keys.every((k) => k.startsWith('device_location.')), isTrue);
    });
  });

  group('AC2 Auto matches by canonical area', () {
    test('exactly one saved place in the area shows its label', () {
      expect(
        matchSavedPlaceLabel('area-marina', [
          _place('g', 'area-marina', custom: 'Gym'),
          _place('w', 'area-deira', label: ProfileLocationLabel.work),
        ]),
        'Gym',
      );
    });

    test('two labels in the same area give no label (the area name shows)', () {
      expect(
        matchSavedPlaceLabel('area-marina', [
          _place('g', 'area-marina', custom: 'Gym'),
          _place('h', 'area-marina', label: ProfileLocationLabel.home),
        ]),
        isNull,
      );
    });

    test('no saved place in the area gives no label', () {
      expect(
        matchSavedPlaceLabel('area-marina', [
          _place('w', 'area-deira', label: ProfileLocationLabel.work),
        ]),
        isNull,
      );
    });

    test('membership is the area id, not the distance: a place a few metres '
        'away in another area does not match', () {
      expect(
        matchSavedPlaceLabel('area-marina', [
          _place('n', 'area-deira', custom: 'Near', lat: 25.0801, lng: 55.1401),
        ]),
        isNull,
      );
    });

    test(
      'Auto with one saved place in the fix area shows that label',
      () async {
        final c = _container([
          _place('g', 'area-marina', custom: 'Gym'),
        ], _marina);
        await c.read(activeLocationProvider.future);
        await c.read(activeLocationProvider.notifier).useGpsLocation();
        expect(_label(c), 'Gym');
        final stored = await _stored();
        expect(stored.mode, DeviceLocationMode.auto);
        expect(stored.savedLabel, 'Gym');
      },
    );

    test('Auto with two saved places in the fix area shows the area name '
        'unless one was selected', () async {
      final places = [
        _place('g', 'area-marina', custom: 'Gym'),
        _place('h', 'area-marina', label: ProfileLocationLabel.home),
      ];
      final c = _container(places, _marina);
      await c.read(activeLocationProvider.future);
      await c.read(activeLocationProvider.notifier).useGpsLocation();
      expect(_label(c), 'Dubai Marina');

      await c
          .read(activeLocationProvider.notifier)
          .useSavedLocation(places.first);
      expect(_label(c), 'Gym');
    });

    test('Auto in an area with no saved place shows the area name', () async {
      final c = _container([_place('w', 'area-deira')], _marina);
      await c.read(activeLocationProvider.future);
      await c.read(activeLocationProvider.notifier).useGpsLocation();
      expect(_label(c), 'Dubai Marina');
    });
  });

  group('AC3 public profile city/country are not touched', () {
    test('selecting a saved place or an Auto fix writes only the device '
        'store', () async {
      final places = [_place('g', 'area-marina', custom: 'Gym')];
      final c = _container(places, _marina);
      await c.read(activeLocationProvider.future);
      await c.read(activeLocationProvider.notifier).useGpsLocation();
      await c
          .read(activeLocationProvider.notifier)
          .useSavedLocation(places.first);
      final keys = (await SharedPreferences.getInstance()).getKeys();
      expect(keys.every((k) => k.startsWith('device_location.')), isTrue);
    });
  });
}
