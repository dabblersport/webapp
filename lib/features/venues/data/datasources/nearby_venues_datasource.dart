import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/venues/domain/venue_listing_filters.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/features/venues/data/models/nearby_venue_model.dart';

abstract class NearbyVenuesDatasource {
  Future<Result<List<NearbyVenueModel>, Failure>> getNearbyVenues({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? sportId,
    VenueSortOrder sortOrder = VenueSortOrder.distance,
    bool? indoor,
    double? maxPrice,
    double? minRating,
  });
}

class SupabaseNearbyVenuesDatasource implements NearbyVenuesDatasource {
  const SupabaseNearbyVenuesDatasource(this._svc);

  final SupabaseService _svc;

  @override
  Future<Result<List<NearbyVenueModel>, Failure>> getNearbyVenues({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? sportId,
    VenueSortOrder sortOrder = VenueSortOrder.distance,
    bool? indoor,
    double? maxPrice,
    double? minRating,
  }) => Result.guard(() async {
    final response = await _svc.client.rpc(
      'rpc_get_nearby_venues',
      params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_meters': radiusMeters,
        if (sportId != null) 'p_sport_id': sportId,
        'p_sort': sortOrder.rpcValue,
        if (indoor != null) 'p_indoor': indoor,
        if (maxPrice != null) 'p_max_price': maxPrice,
        if (minRating != null) 'p_min_rating': minRating,
      },
    );

    final rows = response as List<dynamic>;
    return rows
        .map(
          (r) => NearbyVenueModel.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }, (e) => Failure.from(e));
}
