import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/profile_location.dart';
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
    expect(prefs.getDouble(ActiveLocationNotifier.manualLatKey), 25.1972);
    expect(prefs.getDouble(ActiveLocationNotifier.manualLngKey), 55.2744);
    expect(
      prefs.getString(ActiveLocationNotifier.manualLabelKey),
      'Downtown Dubai',
    );
    expect(fake.requestCalls, 0);
  });

  test('restart: a new container reads the stored point before the denied '
      'path, without GPS or a permission call', () async {
    SharedPreferences.setMockInitialValues({
      ActiveLocationNotifier.manualLatKey: 25.0805,
      ActiveLocationNotifier.manualLngKey: 55.1396,
      ActiveLocationNotifier.manualLabelKey: 'Dubai Marina',
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
