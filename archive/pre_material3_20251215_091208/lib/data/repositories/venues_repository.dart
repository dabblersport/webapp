import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/venue.dart';
import 'package:dabbler/data/models/venue_space.dart';

abstract class VenuesRepository {
  /// Public venues listing relying on the `venues_public_read` policy.
  Future<Result<List<Venue>, Failure>> listVenues({
    bool activeOnly = true,
    String? city,
    String? district,
    String? q,
  });

  /// Fetches a single venue using the `venues_public_read` policy.
  Future<Result<Venue, Failure>> getVenueById(String venueId);

  /// Lists spaces for a venue using the `spaces_public_read` policy.
  Future<Result<List<VenueSpace>, Failure>> listSpacesByVenue(
    String venueId, {
    bool activeOnly = true,
  });

  /// Fetches a single space using the `spaces_public_read` policy.
  Future<Result<VenueSpace, Failure>> getSpaceById(String spaceId);

  /// Approximates nearby venues via a bounding box using `venues_public_read`.
  Future<Result<List<Venue>, Failure>> nearbyVenues({
    required double lat,
    required double lng,
    double withinKm = 10,
    bool activeOnly = true,
  });

  /// Watches spaces for a venue; RLS ensures manage access server-side.
  Stream<Result<List<VenueSpace>, Failure>> watchSpacesByVenue(String venueId);
}
