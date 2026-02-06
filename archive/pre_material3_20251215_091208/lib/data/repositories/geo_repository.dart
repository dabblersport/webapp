import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/venue.dart';

abstract class GeoRepository {
  /// Returns venues within ~radiusMeters, sorted by distance ASC.
  /// Uses an RPC if available, otherwise falls back to bounding-box + client sort.
  Future<Result<List<Venue>, Failure>> nearbyVenues({
    required double lat,
    required double lng,
    double radiusMeters = 5000,
    int limit = 20,
    int offset = 0,
  });
}
