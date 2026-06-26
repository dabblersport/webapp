import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
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

        // Apply limit and order
        final response = await query
            .order('name_en', ascending: true)
            .limit(limit);

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
