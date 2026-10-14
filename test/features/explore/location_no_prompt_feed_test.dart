import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_post.dart';
import 'package:dabbler/data/repositories/feed_repository.dart';
import 'package:dabbler/features/explore/providers/feed_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// KAN-521: the Home Nearby feed only READS the location permission; it never
/// asks the OS for it. Observed at the platform (the fake counts calls).
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

class _Repo implements FeedRepository {
  final List<({double lat, double lng})> calls = [];

  @override
  Future<Result<List<FeedPost>, Failure>> getNearbyFeed({
    required double lat,
    required double lng,
    int radius = 5000,
  }) async {
    calls.add((lat: lat, lng: lng));
    return const Ok(<FeedPost>[]);
  }
}

void main() {
  late GeolocatorPlatform original;
  setUp(() => original = GeolocatorPlatform.instance);
  tearDown(() => GeolocatorPlatform.instance = original);

  for (final p in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
  ]) {
    test('permission $p: zero requestPermission calls, the feed still loads '
        'with the fallback coordinates and no error', () async {
      final fake = _FakePlatform(p);
      GeolocatorPlatform.instance = fake;
      final repo = _Repo();
      final n = NearbyFeedNotifier(repo);
      await n.load();
      expect(fake.requestCalls, 0);
      expect(fake.positionCalls, 0);
      expect(repo.calls.single, (lat: 25.09, lng: 55.15));
      expect(n.state.error, isNull);
      expect(n.state.loaded, isTrue);
      n.dispose();
    });
  }

  test('permission already granted: the device position is used', () async {
    final fake = _FakePlatform(LocationPermission.whileInUse);
    GeolocatorPlatform.instance = fake;
    final repo = _Repo();
    final n = NearbyFeedNotifier(repo);
    await n.load();
    expect(fake.requestCalls, 0);
    expect(repo.calls.single, (lat: 12.5, lng: 34.5));
    n.dispose();
  });
}
