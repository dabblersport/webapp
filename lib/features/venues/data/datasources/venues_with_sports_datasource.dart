import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/domain/venue_listing_filters.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';

/// Datasource for querying v_venues_with_sports view
/// This view is read-only and maintained by the backend
abstract class VenuesWithSportsDataSource {
  /// Fetch venues filtered by sport ID (UUID)
  /// Additional filters: city, isActive, isIndoor
  Future<Result<List<VenueWithSportModel>, Failure>> getVenuesBySport({
    required String sportId,
    String? city,
    bool? isActive,
    bool? isIndoor,
    int limit = 50,
    double? maxPrice,
    double? minRating,
    VenueSortOrder sortOrder = VenueSortOrder.distance,
  });
}

class SupabaseVenuesWithSportsDataSource implements VenuesWithSportsDataSource {
  final SupabaseClient _client;

  SupabaseVenuesWithSportsDataSource(this._client);

  @override
  Future<Result<List<VenueWithSportModel>, Failure>> getVenuesBySport({
    required String sportId,
    String? city,
    bool? isActive,
    bool? isIndoor,
    int limit = 50,
    double? maxPrice,
    double? minRating,
    VenueSortOrder sortOrder = VenueSortOrder.distance,
  }) async {
    return Result.guard(
      () async {
        // Build query on the read-only view
        var query = _client
            .from(SupabaseConfig.vVenuesWithSportsTable)
            .select()
            .eq('sport_id', sportId);

        // Apply optional filters
        if (city != null) {
          query = query.eq('city', city);
        }

        if (isActive != null) {
          query = query.eq('is_active', isActive);
        }

        if (isIndoor != null) {
          query = query.eq('is_indoor', isIndoor);
        }

        if (maxPrice != null) {
          query = query.lte('price_per_hour', maxPrice);
        }
        if (minRating != null) {
          query = query.gte('rating', minRating);
        }

        // Apply order and limit. Distance is ordered on the client (it needs
        // the user's position), so the server order is by name there.
        final ordered = switch (sortOrder) {
          VenueSortOrder.rating => query.order(
            'rating',
            ascending: false,
            nullsFirst: false,
          ),
          VenueSortOrder.price => query.order(
            'price_per_hour',
            ascending: true,
            nullsFirst: false,
          ),
          VenueSortOrder.distance => query.order('name_en', ascending: true),
        };
        final response = await ordered.limit(limit);

        // Parse response
        final venues = (response as List)
            .map(
              (json) =>
                  VenueWithSportModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();

        return venues;
      },
      (error) => Failure(
        category: FailureCode.unknown,
        message: 'Failed to fetch venues: ${error.toString()}',
        cause: error,
      ),
    );
  }
}
