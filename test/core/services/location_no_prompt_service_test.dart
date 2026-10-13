import 'package:dabbler/core/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-521: LocationService.init() and the default fetchLocation() only READ
/// the permission; only an explicit fetchLocation(requestPermission: true)
/// asks the OS. Observed at the platform (the fake counts calls).
/// A fake platform: it records every call and answers from fields. It is the
/// platform the geolocator plugin talks to, not a mock of our own code.
class _FakePlatform extends GeolocatorPlatform {
  _FakePlatform(this.permission);

  LocationPermission permission;
  LocationPermission afterRequest = LocationPermission.whileInUse;
  int requestCalls = 0;
  int positionCalls = 0;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCalls++;
    permission = afterRequest;
    return permission;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positionCalls++;
    return Position(
      latitude: 12.5,
      longitude: 34.5,
      timestamp: DateTime.utc(2026, 10, 14),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late GeolocatorPlatform original;
  setUp(() {
    original = GeolocatorPlatform.instance;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  test('init() with permission denied: zero requestPermission calls, no '
      'position, the permissionDenied flag is set', () async {
    final fake = _FakePlatform(LocationPermission.denied);
    GeolocatorPlatform.instance = fake;
    final s = LocationService();
    await s.init();
    expect(fake.requestCalls, 0);
    expect(fake.positionCalls, 0);
    expect(s.permissionDenied, isTrue);
    expect(s.hasLocation, isFalse);
  });

  test('the default fetchLocation() never requests', () async {
    final fake = _FakePlatform(LocationPermission.denied);
    GeolocatorPlatform.instance = fake;
    final s = LocationService();
    await s.fetchLocation();
    await s.fetchLocation();
    expect(fake.requestCalls, 0);
  });

  test(
    'permission already granted: init() still stores the position',
    () async {
      final fake = _FakePlatform(LocationPermission.whileInUse);
      GeolocatorPlatform.instance = fake;
      final s = LocationService();
      await s.init();
      expect(fake.requestCalls, 0);
      expect(s.hasLocation, isTrue);
      expect(s.currentPosition!.latitude, 12.5);
    },
  );

  test('explicit fetchLocation(requestPermission: true) asks exactly once '
      'when undecided, then uses the position', () async {
    final fake = _FakePlatform(LocationPermission.denied);
    GeolocatorPlatform.instance = fake;
    final s = LocationService();
    await s.fetchLocation(requestPermission: true);
    expect(fake.requestCalls, 1);
    expect(s.permissionDenied, isFalse);
    expect(s.hasLocation, isTrue);
  });

  test('explicit request that the user refuses leaves no position', () async {
    final fake = _FakePlatform(LocationPermission.denied)
      ..afterRequest = LocationPermission.denied;
    GeolocatorPlatform.instance = fake;
    final s = LocationService();
    await s.fetchLocation(requestPermission: true);
    expect(fake.requestCalls, 1);
    expect(s.permissionDenied, isTrue);
  });
}
