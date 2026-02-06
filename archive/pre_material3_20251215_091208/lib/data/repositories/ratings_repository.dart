import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/rating.dart';

abstract class RatingsRepository {
  /// Ratings authored by the current user.
  Future<Result<List<Rating>, Failure>> listGiven({
    DateTime? from,
    DateTime? to,
    int limit = 200,
  });

  /// Ratings where the current user is the target (about me).
  Future<Result<List<Rating>, Failure>> listAboutMe({
    DateTime? from,
    DateTime? to,
    int limit = 200,
  });

  /// Ratings attached to a specific game.
  Future<Result<List<Rating>, Failure>> listForGame(
    String gameId, {
    DateTime? from,
    DateTime? to,
    int limit = 200,
  });

  /// Ratings attached to a specific venue.
  Future<Result<List<Rating>, Failure>> listForVenue(
    String venueId, {
    DateTime? from,
    DateTime? to,
    int limit = 200,
  });

  /// Aggregates
  Future<Result<RatingAggregate?, Failure>> getUserAggregate(String userId);
  Future<Result<RatingAggregate?, Failure>> getGameAggregate(String gameId);
  Future<Result<RatingAggregate?, Failure>> getVenueAggregate(String venueId);
}
