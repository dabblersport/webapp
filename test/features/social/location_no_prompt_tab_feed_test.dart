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
  @override
  Future<Result<List<Post>, Failure>> getPostsByIds(List<String> ids) async =>
      const Ok(<Post>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// No app-level location (denied): there is no City, so Nearby does not query.
class _NoAppLocation extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

/// KAN-594: the candidate fetch; counts how often the City set was read.
int _candidateCalls = 0;

ProviderContainer _container(_Posts repo) {
  _candidateCalls = 0;
  final c = ProviderContainer(
    overrides: [
      postRepositoryProvider.overrideWithValue(repo),
      nearbyCandidateFetchProvider.overrideWithValue(({
        required city,
        required asOf,
      }) async {
        _candidateCalls++;
        return const [];
      }),
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
    LocationPermission.whileInUse,
  ]) {
    test('permission $p and no selected City: no OS prompt, no device read, '
        'no Nearby query (never an all-cities feed), no error', () async {
      final fake = _FakePlatform(p);
      GeolocatorPlatform.instance = fake;
      final repo = _Posts();
      final c = _container(repo);
      await c.read(activeLocationProvider.future);
      await c.read(nearbyFeedProvider.notifier).load();
      expect(fake.requestCalls, 0);
      expect(fake.positionCalls, 0);
      expect(_candidateCalls, 0);
      final state = c.read(nearbyFeedProvider);
      expect(state, isA<TabFeedData>());
      expect((state as TabFeedData).posts, isEmpty);
    });
  }
}
