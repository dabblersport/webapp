import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

/// The three database steps that removing a sport from a profile needs.
///
/// Split out of `ManageSportsSheet` so the order can be tested with a fake.
abstract class SportRemovalSteps {
  /// Deletes the persona's sport row (`sport_profiles` or `organiser`) and
  /// returns the deleted rows, so they can be put back.
  Future<List<Map<String, dynamic>>> deleteSportRecord();

  /// Writes the profile's `interests` array.
  Future<void> updateInterests(List<String> interests);

  /// Re-inserts rows returned by [deleteSportRecord].
  Future<void> restoreSportRecord(List<Map<String, dynamic>> rows);
}

/// Removes a sport so the contributor trigger
/// (`trgfn_contributor_sports_check`) holds after every step: the sport row
/// goes first, then `interests`. Every `sport_profiles` row must have its
/// sport in `interests`, so the reverse order fails for contributors.
///
/// If the interests write fails it is retried once; if it fails again the
/// deleted row is restored, so no half change is left behind.
Future<Result<Unit, Failure>> removeSportInOrder(
  SportRemovalSteps steps,
  List<String> newInterests,
) async {
  final deleted = await Result.guard<List<Map<String, dynamic>>, Failure>(
    steps.deleteSportRecord,
    Failure.from,
  );
  if (deleted is Err<List<Map<String, dynamic>>, Failure>) {
    return Err<Unit, Failure>(deleted.error);
  }
  final rows = (deleted as Ok<List<Map<String, dynamic>>, Failure>).value;

  Future<Result<Unit, Failure>> writeInterests() =>
      Result.guard<Unit, Failure>(() async {
        await steps.updateInterests(newInterests);
        return const Unit();
      }, Failure.from);

  var written = await writeInterests();
  if (written.isSuccess) return written;
  written = await writeInterests();
  if (written.isSuccess) return written;

  if (rows.isNotEmpty) {
    await Result.guard<Unit, Failure>(() async {
      await steps.restoreSportRecord(rows);
      return const Unit();
    }, Failure.from);
  }
  return written;
}

/// Why a sport cannot be removed, or null when it can (KAN-1056).
enum SportRemovalBlock {
  /// It is the profile's only sport.
  lastSport,

  /// It is a contributor's primary sport (trigger rule): retrying never
  /// helps, the primary sport has to change first.
  primarySport,
}

/// Checks a removal of [sportId] before any database call is made.
SportRemovalBlock? sportRemovalBlock({
  required String sportId,
  required int selectedCount,
  required String profileType,
  required String? primarySport,
}) {
  if (selectedCount <= 1) return SportRemovalBlock.lastSport;
  if (profileType == 'contributor' && sportId == primarySport) {
    return SportRemovalBlock.primarySport;
  }
  return null;
}
