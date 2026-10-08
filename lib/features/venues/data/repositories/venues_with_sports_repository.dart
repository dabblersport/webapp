import 'package:dabbler/features/venues/data/models/venue_with_sport_model.dart';
import 'package:dabbler/features/venues/data/datasources/venues_with_sports_datasource.dart';
import 'package:dabbler/features/venues/domain/venue_listing_filters.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';

/// Repository for venues queried from v_venues_with_sports view
/// Provides a clean interface for the UI layer
abstract class VenuesWithSportsRepository {
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

class VenuesWithSportsRepositoryImpl implements VenuesWithSportsRepository {
  final VenuesWithSportsDataSource _dataSource;

  VenuesWithSportsRepositoryImpl(this._dataSource);

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
    return _dataSource.getVenuesBySport(
      sportId: sportId,
      city: city,
      isActive: isActive,
      isIndoor: isIndoor,
      limit: limit,
      maxPrice: maxPrice,
      minRating: minRating,
      sortOrder: sortOrder,
    );
  }
}
