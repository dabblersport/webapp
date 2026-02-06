import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/slot.dart';

abstract class AvailabilityRepository {
  /// Read grid slots for a space within [from, to).
  /// When [onlyAvailable] is true, filter out held/booked/closed slots.
  Future<Result<List<Slot>, Failure>> listSlots({
    required String venueSpaceId,
    required DateTime from,
    required DateTime to,
    bool onlyAvailable = true,
    int limit = 500,
  });

  /// List my active holds (optionally limited by space and/or window).
  Future<Result<List<SlotHold>, Failure>> listMyHolds({
    String? venueSpaceId,
    DateTime? from,
    DateTime? to,
    int limit = 200,
  });

  /// Create a hold (soft-reservation). Server enforces conflicts and RLS.
  Future<Result<SlotHold, Failure>> createHold({
    required String venueSpaceId,
    required DateTime start,
    required DateTime end,
    String? note,
  });

  /// Release (delete) a hold I created.
  Future<Result<void, Failure>> releaseHold(String holdId);
}
