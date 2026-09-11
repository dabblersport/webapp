import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/nearby/nearby.dart';
import 'package:dabbler/core/services/location_service.dart';
import 'package:dabbler/data/repositories/nearby_games_repository.dart';
import 'package:dabbler/data/repositories/nearby_games_repository_impl.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

final nearbyRepositoryProvider = Provider<NearbyRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return NearbyRepositoryImpl(svc);
});

// ---------------------------------------------------------------------------
// Location service provider (real device location)
// ---------------------------------------------------------------------------

final nearbyLocationServiceProvider = Provider<LocationService>((_) {
  return LocationService();
});

// ---------------------------------------------------------------------------
// Query params value object
// ---------------------------------------------------------------------------

class NearbyParams {
  const NearbyParams({
    required this.lat,
    required this.lng,
    this.radius = 5000,
  });

  final double lat;
  final double lng;
  final int radius;

  @override
  bool operator ==(Object other) =>
      other is NearbyParams &&
      other.lat == lat &&
      other.lng == lng &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(lat, lng, radius);
}

// ---------------------------------------------------------------------------
// Entity filter enum (drives the filter chips in the UI)
// ---------------------------------------------------------------------------

enum NearbyFilter { games, venues, players, posts }

// ---------------------------------------------------------------------------
// Data providers — one per entity type
// ---------------------------------------------------------------------------

final nearbyGamesProvider = FutureProvider.autoDispose
    .family<List<NearbyGame>, NearbyParams>((ref, params) async {
      final repo = ref.watch(nearbyRepositoryProvider);
      final result = await repo.getNearbyGames(
        lat: params.lat,
        lng: params.lng,
        radius: params.radius,
      );
      return result.fold(
        (failure) => throw Exception(failure.message),
        (data) => data,
      );
    });

final nearbyVenuesProvider = FutureProvider.autoDispose
    .family<List<NearbyVenue>, NearbyParams>((ref, params) async {
      final repo = ref.watch(nearbyRepositoryProvider);
      final result = await repo.getNearbyVenues(
        lat: params.lat,
        lng: params.lng,
        radius: params.radius,
      );
      return result.fold(
        (failure) => throw Exception(failure.message),
        (data) => data,
      );
    });

final nearbyPostsProvider = FutureProvider.autoDispose
    .family<List<NearbyPost>, NearbyParams>((ref, params) async {
      final repo = ref.watch(nearbyRepositoryProvider);
      final result = await repo.getNearbyPosts(
        lat: params.lat,
        lng: params.lng,
        radius: params.radius,
      );
      return result.fold(
        (failure) => throw Exception(failure.message),
        (data) => data,
      );
    });

final nearbyProfilesProvider = FutureProvider.autoDispose
    .family<List<NearbyProfile>, NearbyParams>((ref, params) async {
      final repo = ref.watch(nearbyRepositoryProvider);
      final result = await repo.getNearbyProfiles(
        lat: params.lat,
        lng: params.lng,
        radius: params.radius,
      );
      return result.fold(
        (failure) => throw Exception(failure.message),
        (data) => data,
      );
    });

// ---------------------------------------------------------------------------
// Active filter state
// ---------------------------------------------------------------------------

final nearbyFilterProvider = StateProvider<NearbyFilter>((ref) {
  return NearbyFilter.games;
});
