import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/data/models/venue_space.dart';
import 'package:dabbler/data/models/games/venue.dart' as games_venue;
import 'package:dabbler/data/repositories/venues_repository.dart';
import 'package:dabbler/data/repositories/venues_repository_impl.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
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
) {
  final repository = ref.watch(games_providers.venuesRepositoryProvider);
  // KAN-605: a venue the viewer opened is kept for offline reading.
  return swrFetch<games_venue.Venue>(
    ref,
    key: 'venues.detail.$venueId',
    fetch: () async {
      final result = await repository.getVenue(venueId);
      return result.fold(
        (failure) => throw Exception(failure.message),
        (venue) => venue,
      );
    },
    encode: _venueToJson,
    decode: (json) => _venueFromJson(Map<String, dynamic>.from(json as Map)),
  );
});

Map<String, dynamic> _venueToJson(games_venue.Venue v) => {
  'id': v.id,
  'name': v.name,
  'description': v.description,
  'addressLine1': v.addressLine1,
  'addressLine2': v.addressLine2,
  'city': v.city,
  'state': v.state,
  'country': v.country,
  'postalCode': v.postalCode,
  'latitude': v.latitude,
  'longitude': v.longitude,
  'phone': v.phone,
  'email': v.email,
  'website': v.website,
  'openingTime': v.openingTime,
  'closingTime': v.closingTime,
  'rating': v.rating,
  'totalRatings': v.totalRatings,
  'pricePerHour': v.pricePerHour,
  'currency': v.currency,
  'supportedSports': v.supportedSports,
  'amenities': v.amenities,
  'createdAt': v.createdAt.toIso8601String(),
  'updatedAt': v.updatedAt.toIso8601String(),
};

games_venue.Venue _venueFromJson(Map<String, dynamic> j) => games_venue.Venue(
  id: j['id'] as String,
  name: j['name'] as String,
  description: j['description'] as String,
  addressLine1: j['addressLine1'] as String,
  addressLine2: j['addressLine2'] as String?,
  city: j['city'] as String,
  state: j['state'] as String,
  country: j['country'] as String,
  postalCode: j['postalCode'] as String,
  latitude: (j['latitude'] as num).toDouble(),
  longitude: (j['longitude'] as num).toDouble(),
  phone: j['phone'] as String?,
  email: j['email'] as String?,
  website: j['website'] as String?,
  openingTime: j['openingTime'] as String,
  closingTime: j['closingTime'] as String,
  rating: (j['rating'] as num).toDouble(),
  totalRatings: (j['totalRatings'] as num).toInt(),
  pricePerHour: (j['pricePerHour'] as num).toDouble(),
  currency: j['currency'] as String,
  supportedSports: List<String>.from(j['supportedSports'] as List),
  amenities: List<String>.from(j['amenities'] as List),
  createdAt: DateTime.parse(j['createdAt'] as String),
  updatedAt: DateTime.parse(j['updatedAt'] as String),
);

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
