import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_sheet.dart'
    show NearbySortOrder;
import 'package:dabbler/features/venues/data/datasources/nearby_venues_datasource.dart';
import 'package:dabbler/features/venues/data/models/nearby_venue_model.dart';

abstract class NearbyVenuesRepository {
  Future<Result<List<NearbyVenueModel>, Failure>> getNearbyVenues({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? sportId,
    NearbySortOrder sortOrder = NearbySortOrder.nearest,
  });
}

class NearbyVenuesRepositoryImpl implements NearbyVenuesRepository {
  const NearbyVenuesRepositoryImpl(this._datasource);

  final NearbyVenuesDatasource _datasource;

  @override
  Future<Result<List<NearbyVenueModel>, Failure>> getNearbyVenues({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? sportId,
    NearbySortOrder sortOrder = NearbySortOrder.nearest,
  }) =>
      _datasource.getNearbyVenues(
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        sportId: sportId,
        sortOrder: sortOrder,
      );
}
