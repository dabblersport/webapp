import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/data/models/venue_space.dart';
import 'package:dabbler/data/models/games/venue.dart' as games_venue;
import 'package:dabbler/data/repositories/venues_repository.dart';
import 'package:dabbler/data/repositories/venues_repository_impl.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/games/providers/games_providers.dart'
    as games_providers;
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;

final venuesRepositoryProvider = Provider<VenuesRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return VenuesRepositoryImpl(svc);
});

// Provider for fetching a single venue by ID (from games venues datasource)
final venueDetailProvider = FutureProvider.family<games_venue.Venue, String>((
  ref,
  venueId,
) async {
  final repository = ref.watch(games_providers.venuesRepositoryProvider);
  final result = await repository.getVenue(venueId);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (venue) => venue,
  );
});

final activeVenuesProvider =
    FutureProvider.family<
      Result<List<Venue>, Failure>,
      ({String? city, String? district, String? q})
    >((ref, params) async {
      return ref
          .watch(venuesRepositoryProvider)
          .listVenues(
            activeOnly: true,
            city: params.city,
            district: params.district,
            q: params.q,
          );
    });

final spacesByVenueStreamProvider =
    StreamProvider.family<Result<List<VenueSpace>, Failure>, String>((
      ref,
      venueId,
    ) {
      return ref.watch(venuesRepositoryProvider).watchSpacesByVenue(venueId);
    });

/// Current user's favorited venues (aka saved/bookmarked venues).
///
/// Backed by the games venues repository (`venue_favorites` table + `toggle_venue_favorite` RPC).
final favoriteVenuesForCurrentUserProvider =
    FutureProvider.autoDispose<List<games_venue.Venue>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null || userId.isEmpty) return <games_venue.Venue>[];

      final repository = ref.watch(games_providers.venuesRepositoryProvider);
      final result = await repository.getFavoriteVenues(
        userId,
        page: 1,
        limit: 200,
      );

      return result.fold(
        (failure) => throw Exception(failure.message),
        (venues) => venues,
      );
    });

/// Convenience: Set of favorited venue ids for current user.
final favoriteVenueIdsForCurrentUserProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
      final venues = await ref.watch(
        favoriteVenuesForCurrentUserProvider.future,
      );
      return venues.map((v) => v.id).toSet();
    });
