import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_post.dart';
import 'package:dabbler/data/repositories/feed_repository.dart';
import 'package:dabbler/features/explore/providers/feed_providers.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-526: the Home Nearby feed uses the active location (the persisted
/// manual point) before its own read-only GPS attempt and before the
/// fallback, and never asks the OS for permission.
class _FakePlatform extends GeolocatorPlatform {
  _FakePlatform(this.permission);

  LocationPermission permission;
  int requestCalls = 0;
  int positionCalls = 0;

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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Starts in a fixed state (no Supabase, no GPS); every other method,
/// including useManualPoint, is the real one.
class _StartingActive extends ActiveLocationNotifier {
  _StartingActive(this._start);
  final ActiveLocationState _start;

  @override
  Future<ActiveLocationState> build() async => _start;
}

void main() {
  late GeolocatorPlatform original;
  setUp(() {
    original = GeolocatorPlatform.instance;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  ProviderContainer containerWith(_Repo repo, ActiveLocationState start) =>
      ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(repo),
          activeLocationProvider.overrideWith(() => _StartingActive(start)),
        ],
      );

  test('permission denied + manual point: the feed queries the manual '
      'lat/lng and requestPermission is never called', () async {
    final fake = _FakePlatform(LocationPermission.denied);
    GeolocatorPlatform.instance = fake;
    final repo = _Repo();
    final c = containerWith(repo, ActiveLocationDenied());
    addTearDown(c.dispose);

    await c.read(activeLocationProvider.future);
    await c
        .read(activeLocationProvider.notifier)
        .useManualPoint(24.45, 54.38, 'Abu Dhabi');

    await c.read(nearbyRpcFeedProvider.notifier).load();

    expect(repo.calls.last, (lat: 24.45, lng: 54.38));
    expect(fake.requestCalls, 0);
    expect(fake.positionCalls, 0);
    expect(c.read(nearbyRpcFeedProvider).loaded, isTrue);
  });

  test('picking a manual point after the feed loaded reloads it once with '
      'the new point, still without a permission request', () async {
    final fake = _FakePlatform(LocationPermission.denied);
    GeolocatorPlatform.instance = fake;
    final repo = _Repo();
    final c = containerWith(repo, ActiveLocationDenied());
    addTearDown(c.dispose);

    await c.read(activeLocationProvider.future);
    await c.read(nearbyRpcFeedProvider.notifier).load();
    expect(repo.calls.single, (lat: 25.09, lng: 55.15));

    await c
        .read(activeLocationProvider.notifier)
        .useManualPoint(24.45, 54.38, 'Abu Dhabi');
    await pumpEventQueue();

    expect(repo.calls.length, 2);
    expect(repo.calls.last, (lat: 24.45, lng: 54.38));
    expect(fake.requestCalls, 0);
  });

  test(
    'granted, no manual point: the GPS position is used as before',
    () async {
      final fake = _FakePlatform(LocationPermission.whileInUse);
      GeolocatorPlatform.instance = fake;
      final repo = _Repo();
      final c = containerWith(repo, ActiveLocationLoading());
      addTearDown(c.dispose);

      await c.read(activeLocationProvider.future);
      await c.read(nearbyRpcFeedProvider.notifier).load();

      expect(repo.calls.single, (lat: 12.5, lng: 34.5));
      expect(fake.requestCalls, 0);
    },
  );
}
