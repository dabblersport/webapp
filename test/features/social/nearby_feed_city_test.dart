import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-588: the Home Nearby feed with only a city. No point, no GPS read: the
/// city's posts, newest first. A change of city asks again for the new city.
class _Posts implements PostRepository {
  final List<({double? lat, double? lng, String? city})> calls = [];

  @override
  Future<Result<List<Post>, Failure>> getNearbyFeed({
    double? lat,
    double? lng,
    String? city,
    int limit = 20,
    int offset = 0,
  }) async {
    calls.add((lat: lat, lng: lng, city: city));
    return const Ok(<Post>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Loc extends ActiveLocationNotifier {
  _Loc(this.initial);
  final ActiveLocationState initial;

  @override
  Future<ActiveLocationState> build() async => initial;

  void set(ActiveLocationState s) => state = AsyncData(s);
}

ProviderContainer _container(_Posts repo, ActiveLocationState initial) {
  final c = ProviderContainer(
    overrides: [
      postRepositoryProvider.overrideWithValue(repo),
      activeLocationProvider.overrideWith(() => _Loc(initial)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('only a city: the feed asks for that city and sends no point', () async {
    final repo = _Posts();
    final c = _container(repo, ActiveLocationCityOnly('Dubai', country: 'AE'));
    await c.read(activeLocationProvider.future);
    await c.read(nearbyFeedProvider.notifier).load();
    expect(repo.calls, isNotEmpty);
    expect(repo.calls.last, (lat: null, lng: null, city: 'Dubai'));
  });

  test('a change of city asks for the new city, never the old one', () async {
    final repo = _Posts();
    final c = _container(repo, ActiveLocationCityOnly('Dubai', country: 'AE'));
    await c.read(activeLocationProvider.future);
    await c.read(nearbyFeedProvider.notifier).load();

    (c.read(activeLocationProvider.notifier) as _Loc).set(
      ActiveLocationCityOnly('Doha', country: 'QA'),
    );
    await c.read(nearbyFeedProvider.notifier).load();
    expect(repo.calls.last.city, 'Doha');
    expect(repo.calls.last.lat, isNull);
  });

  test('an Area gives the point, so the distance ranking applies', () async {
    final repo = _Posts();
    final c = _container(
      repo,
      ActiveLocationReady(
        const ActiveLocation(
          lat: 25.2,
          lng: 55.3,
          area: Area(
            id: 'a1',
            name: 'Al Barsha',
            district: 'Dubai',
            city: 'Dubai',
            country: 'AE',
            centerLat: 25.2,
            centerLng: 55.3,
          ),
          source: ActiveLocationSource.manual,
        ),
      ),
    );
    await c.read(activeLocationProvider.future);
    await c.read(nearbyFeedProvider.notifier).load();
    expect(repo.calls.last.lat, 25.2);
    expect(repo.calls.last.lng, 55.3);
  });
}
