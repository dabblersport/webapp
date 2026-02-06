import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/venue_space.dart';

abstract class VenueConfigRepository {
  /// List active spaces; optionally filter by venue.
  Future<Result<List<VenueSpace>, Failure>> listActiveSpaces({
    String? venueId,
    int limit = 100,
  });

  /// Get opening hours for a space.
  Future<Result<List<OpeningHour>, Failure>> getOpeningHours(
    String venueSpaceId,
  );

  /// Get active prices for a space.
  Future<Result<List<SpacePrice>, Failure>> getActivePrices(
    String venueSpaceId,
  );

  /// Admin/Manager: create or update a space.
  Future<Result<VenueSpace, Failure>> upsertSpace(VenueSpace space);

  /// Admin/Manager: create/update opening hour.
  Future<Result<OpeningHour, Failure>> upsertOpeningHour(OpeningHour hour);

  /// Admin/Manager: create/update price.
  Future<Result<SpacePrice, Failure>> upsertSpacePrice(SpacePrice price);

  /// Admin/Manager: soft-toggle a space to active/inactive.
  Future<Result<VenueSpace, Failure>> setSpaceActive({
    required String spaceId,
    required bool isActive,
  });
}
