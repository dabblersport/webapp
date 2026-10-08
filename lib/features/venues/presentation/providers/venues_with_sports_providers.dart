import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/venues/data/datasources/venues_with_sports_datasource.dart';
import 'package:dabbler/features/venues/data/repositories/venues_with_sports_repository.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/domain/venue_listing_filters.dart';

/// Datasource provider
final venuesWithSportsDataSourceProvider = Provider<VenuesWithSportsDataSource>(
  (ref) {
    return SupabaseVenuesWithSportsDataSource(Supabase.instance.client);
  },
);

/// Repository provider
final venuesWithSportsRepositoryProvider = Provider<VenuesWithSportsRepository>(
  (ref) {
    return VenuesWithSportsRepositoryImpl(
      ref.watch(venuesWithSportsDataSourceProvider),
    );
  },
);

/// Provider to fetch venues by sport key
/// Usage: ref.watch(venuesBySportProvider('football'))
final venuesBySportProvider =
    FutureProvider.family<List<VenueWithSportModel>, String>((
      ref,
      sportKey,
    ) async {
      final repository = ref.watch(venuesWithSportsRepositoryProvider);

      final result = await repository.getVenuesBySport(
        sportId: sportKey,
        isActive: true, // Only show active venues by default
      );

      return result.fold(
        (failure) => throw Exception(failure.message),
        (venues) => venues,
      );
    });

/// Provider with filters for more control
final venuesBySportWithFiltersProvider =
    FutureProvider.family<List<VenueWithSportModel>, VenuesBySportFilters>((
      ref,
      filters,
    ) async {
      final repository = ref.watch(venuesWithSportsRepositoryProvider);

      final result = await repository.getVenuesBySport(
        sportId: filters.sportId,
        city: filters.city,
        isActive: filters.isActive ?? true,
        isIndoor: filters.isIndoor,
        limit: filters.limit,
        maxPrice: filters.maxPrice,
        minRating: filters.minRating,
        sortOrder: filters.sortOrder,
      );

      return result.fold(
        (failure) => throw Exception(failure.message),
        (venues) => venues,
      );
    });

/// Filter parameters for querying venues
class VenuesBySportFilters {
  final String sportId;
  final String? city;
  final bool? isActive;
  final bool? isIndoor;
  final int limit;
  final double? maxPrice;
  final double? minRating;
  final VenueSortOrder sortOrder;

  const VenuesBySportFilters({
    required this.sportId,
    this.city,
    this.isActive,
    this.isIndoor,
    this.limit = 50,
    this.maxPrice,
    this.minRating,
    this.sortOrder = VenueSortOrder.distance,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VenuesBySportFilters &&
          runtimeType == other.runtimeType &&
          sportId == other.sportId &&
          city == other.city &&
          isActive == other.isActive &&
          isIndoor == other.isIndoor &&
          limit == other.limit &&
          maxPrice == other.maxPrice &&
          minRating == other.minRating &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode =>
      sportId.hashCode ^
      city.hashCode ^
      isActive.hashCode ^
      isIndoor.hashCode ^
      limit.hashCode ^
      maxPrice.hashCode ^
      minRating.hashCode ^
      sortOrder.hashCode;
}

/// One row of `amenities_catalog`: the labels the card shows for a key.
typedef VenueAmenityLabel = ({String en, String? ar});

/// `amenities_catalog` keyed by `key` — the facility labels of the venue card.
final venueAmenityCatalogProvider =
    FutureProvider<Map<String, VenueAmenityLabel>>((ref) async {
      final rows = await Supabase.instance.client
          .from(SupabaseConfig.amenitiesCatalogTable)
          .select('key,label_en,label_ar')
          .eq('is_active', true);
      return {
        for (final r in (rows as List))
          (r as Map)['key'] as String: (
            en: r['label_en'] as String? ?? r['key'] as String,
            ar: r['label_ar'] as String?,
          ),
      };
    });
