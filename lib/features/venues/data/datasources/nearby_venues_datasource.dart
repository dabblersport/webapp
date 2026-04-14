import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_sheet.dart'
    show NearbySortOrder;
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/venues/data/models/nearby_venue_model.dart';

abstract class NearbyVenuesDatasource {
  Future<Result<List<NearbyVenueModel>, Failure>> getNearbyVenues({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? sportId,
    NearbySortOrder sortOrder = NearbySortOrder.nearest,
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
    NearbySortOrder sortOrder = NearbySortOrder.nearest,
  }) =>
      Result.guard(
        () async {
          final response = await _svc.client.rpc(
            'rpc_get_nearby_venues',
            params: {
              'p_lat': lat,
              'p_lng': lng,
              'p_radius_meters': radiusMeters,
              if (sportId != null) 'p_sport_id': sportId,
              'p_sort':
                  sortOrder == NearbySortOrder.nearest ? 'distance' : 'default',
            },
          );

          final rows = response as List<dynamic>;
          return rows
              .map((r) => NearbyVenueModel.fromJson(
                    Map<String, dynamic>.from(r as Map),
                  ))
              .toList();
        },
        (e) => Failure.from(e),
      );
}
