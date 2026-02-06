import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/benefit.dart';

abstract class OrganiserBenefitsRepository {
  /// List benefits owned by the current user (RLS should scope correctly).
  Future<Result<List<Benefit>, Failure>> listMine({
    bool onlyActive = true,
    int limit = 50,
    int offset = 0,
  });

  /// List benefits for a venue (if RLS permits).
  Future<Result<List<Benefit>, Failure>> listForVenue(
    String venueId, {
    bool onlyActive = true,
    int limit = 50,
    int offset = 0,
  });

  /// Get a single benefit by id.
  Future<Result<Benefit?, Failure>> getById(String id);

  /// Create and return the created row (or at least its id).
  Future<Result<Benefit, Failure>> create({
    required String title,
    String? description,
    String? venueId,
    bool isActive = true,
    DateTime? startsAt,
    DateTime? endsAt,
    String? imageUrl,
  });

  /// Patch fields on a benefit.
  Future<Result<void, Failure>> update(
    String id, {
    String? title,
    String? description,
    String? venueId,
    bool? isActive,
    DateTime? startsAt,
    DateTime? endsAt,
    String? imageUrl,
  });

  /// Delete a benefit (RLS-protected).
  Future<Result<void, Failure>> delete(String id);
}
