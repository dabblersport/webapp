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
