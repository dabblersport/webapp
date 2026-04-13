import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/area.dart';

/// Contract for area-related data operations.
abstract class AreaRepository {
  /// Fetch a single area by ID.
  Future<Result<Area, Failure>> getArea(String areaId);

  /// List all active areas, ordered by name.
  Future<Result<List<Area>, Failure>> getActiveAreas();

  /// Find the nearest area to the given coordinates.
  Future<Result<Area, Failure>> getNearestArea({
    required double lat,
    required double lng,
  });
}
