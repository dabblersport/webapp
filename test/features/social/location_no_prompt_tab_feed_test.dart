import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// KAN-521: the tab Nearby fetch (no app-level coordinates) only READS the
/// location permission; it never asks the OS for it. Observed at the platform.
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

class _Posts implements PostRepository {
  final List<({double? lat, double? lng})> calls = [];

  @override
  Future<Result<List<Post>, Failure>> getNearbyFeed({
    double? lat,
    double? lng,
    String? city,
    int limit = 20,
    int offset = 0,
  }) async {
    calls.add((lat: lat, lng: lng));
    return const Ok(<Post>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// No app-level location (denied): the fetcher falls back to the raw read.
class _NoAppLocation extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

ProviderContainer _container(_Posts repo) {
  final c = ProviderContainer(
    overrides: [
      postRepositoryProvider.overrideWithValue(repo),
      activeLocationProvider.overrideWith(_NoAppLocation.new),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  late GeolocatorPlatform original;
  setUp(() => original = GeolocatorPlatform.instance);
  tearDown(() => GeolocatorPlatform.instance = original);

  for (final p in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
  ]) {
    test('permission $p: zero requestPermission calls, the feed loads by '
        'recency (no coordinates), no error', () async {
      final fake = _FakePlatform(p);
      GeolocatorPlatform.instance = fake;
      final repo = _Posts();
      final c = _container(repo);
      await c.read(activeLocationProvider.future);
      await c.read(nearbyFeedProvider.notifier).load();
      expect(fake.requestCalls, 0);
      expect(fake.positionCalls, 0);
      expect(repo.calls.single, (lat: null, lng: null));
      expect(c.read(nearbyFeedProvider), isA<TabFeedData>());
    });
  }

  test('permission already granted: the device position is passed to the '
      'repository', () async {
    final fake = _FakePlatform(LocationPermission.whileInUse);
    GeolocatorPlatform.instance = fake;
    final repo = _Posts();
    final c = _container(repo);
    await c.read(activeLocationProvider.future);
    await c.read(nearbyFeedProvider.notifier).load();
    expect(fake.requestCalls, 0);
    expect(repo.calls.single, (lat: 12.5, lng: 34.5));
  });
}
