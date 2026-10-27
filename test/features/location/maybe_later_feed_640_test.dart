import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_post.dart';
import 'package:dabbler/data/repositories/feed_repository.dart';
import 'package:dabbler/features/explore/providers/feed_providers.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/listing_city.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// KAN-640: after "Maybe later" the app has no city. The general feed stays
/// usable, nothing asks the OS for the location, and the city-gated lists say
/// "Choose city" (their own empty state, covered by city_listings_test).
class _Platform extends GeolocatorPlatform {
  int requestCalls = 0;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCalls++;
    return LocationPermission.denied;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;
}

class _Repo implements FeedRepository {
  int calls = 0;

  @override
  Future<Result<List<FeedPost>, Failure>> getNearbyFeed({
    required double lat,
    required double lng,
    int radius = 5000,
  }) async {
    calls++;
    return const Ok(<FeedPost>[]);
  }
}

/// No city, no point: the state "Maybe later" leaves a fresh user in.
class _NoCity extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationDenied();
}

class _City extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationCityOnly('Dubai');
}

void main() {
  late GeolocatorPlatform original;
  late _Platform platform;
  setUp(() {
    original = GeolocatorPlatform.instance;
    platform = _Platform();
    GeolocatorPlatform.instance = platform;
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  test('no city after Maybe later: the feed loads, nothing prompts, the lists '
      'say Choose city', () async {
    final repo = _Repo();
    final c = ProviderContainer(
      overrides: [
        activeLocationProvider.overrideWith(_NoCity.new),
        feedRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    await c.read(activeLocationProvider.future);

    final feed = c.read(nearbyRpcFeedProvider.notifier);
    await feed.load();

    final s = c.read(nearbyRpcFeedProvider);
    expect(repo.calls, 1, reason: 'the feed was fetched');
    expect(s.loaded, isTrue);
    expect(s.error, isNull);
    expect(platform.requestCalls, 0, reason: 'the OS was never asked');
    // The point-of-use gate is intact: no city invented.
    expect(c.read(listingCityProvider), isNull);
    expect(c.read(listingCityMissingProvider), isTrue);
  });

  test('a city set later is the one the lists use', () async {
    final c = ProviderContainer(
      overrides: [activeLocationProvider.overrideWith(_City.new)],
    );
    addTearDown(c.dispose);
    await c.read(activeLocationProvider.future);
    expect(c.read(listingCityProvider)?.name, 'Dubai');
    expect(c.read(listingCityMissingProvider), isFalse);
  });
}
