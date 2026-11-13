import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/games/venue.dart';
import 'package:dabbler/features/games/data/repositories/venues_repository_impl.dart';
import 'package:dabbler/features/games/providers/games_providers.dart'
    as games_providers;
import 'package:dabbler/features/venues/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements VenuesRepositoryImpl {
  _Repo(this.venue);
  Venue? venue;

  @override
  Future<Either<Failure, Venue>> getVenue(String venueId) async => venue == null
      ? left(const Failure(message: 'no internet'))
      : right(venue!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// KAN-605: a venue the viewer opened is shown from the cache when the
/// network is gone.
void main() {
  test('a venue opened online opens again offline, intact', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = OfflineCache(prefs: await SharedPreferences.getInstance());
    final venue = Venue(
      id: 'v1',
      name: 'Court',
      description: 'Indoor padel',
      addressLine1: '1 Marina Walk',
      addressLine2: 'Unit 2',
      city: 'Dubai',
      state: 'Dubai',
      country: 'AE',
      postalCode: '000',
      latitude: 25.1,
      longitude: 55.2,
      phone: '+971500000000',
      openingTime: '08:00',
      closingTime: '23:00',
      rating: 4.5,
      totalRatings: 12,
      pricePerHour: 120,
      currency: 'AED',
      supportedSports: const ['Padel'],
      amenities: const ['parking'],
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 2, 1),
    );
    final repo = _Repo(venue);
    ProviderContainer open() => ProviderContainer(
      overrides: [
        offlineCacheProvider.overrideWithValue(cache),
        cacheAccountIdProvider.overrideWith(
          (ref) => CacheAccountNotifier.fixed('A'),
        ),
        games_providers.venuesRepositoryProvider.overrideWithValue(repo),
      ],
    );

    final online = open();
    addTearDown(online.dispose);
    expect((await online.read(venueDetailProvider('v1').future)).name, 'Court');

    repo.venue = null; // the connection is gone
    final offline = open();
    addTearDown(offline.dispose);
    final back = await offline.read(venueDetailProvider('v1').future);
    expect(back.name, 'Court');
    expect(back.addressLine2, 'Unit 2');
    expect(back.supportedSports, ['Padel']);
    expect(back.updatedAt, venue.updatedAt);
  });
}
