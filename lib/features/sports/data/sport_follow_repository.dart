import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/sports/data/my_sports_rpc.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';

/// What a sport-page write ended in (KAN-1060, on the KAN-1059 RPCs).
enum SportFollowOutcome {
  followed,
  unfollowed,

  /// Added to (or restored into) My sports; the sport is followed too.
  added,

  /// Removed from My sports (the card is hidden, its stats kept).
  removed,

  /// The level was saved.
  levelSet,

  /// Already in the wanted state; nothing was written.
  unchanged,

  /// Refused: it would leave the persona with no sport.
  blockedLast,

  /// Refused: the sport is the persona's Primary sport.
  blockedPrimary,

  /// Unfollow refused: the sport is still in My sports.
  blockedInMySports,

  /// The sport is unknown or inactive.
  invalid,
}

/// The [SportFollowOutcome] of an RPC [outcome] for a write whose success is
/// [done].
SportFollowOutcome sportFollowOutcomeOf(
  SportOutcome outcome,
  SportFollowOutcome done,
) => switch (outcome) {
  SportOutcome.done => done,
  SportOutcome.unchanged => SportFollowOutcome.unchanged,
  SportOutcome.blockedPrimary => SportFollowOutcome.blockedPrimary,
  SportOutcome.blockedInMySports => SportFollowOutcome.blockedInMySports,
  SportOutcome.blockedLast => SportFollowOutcome.blockedLast,
  SportOutcome.invalid => SportFollowOutcome.invalid,
};

/// Follow / My sports writes for the active persona. Every write is an
/// owner-checked RPC; the server enforces the guards (primary, last, still in
/// My sports), so a stale screen cannot break them. Nothing deletes a card.
abstract class SportFollowRepository {
  Future<Result<SportFollowOutcome, Failure>> follow(
    String profileId,
    SportInfo sport,
  );

  Future<Result<SportFollowOutcome, Failure>> unfollow(
    String profileId,
    SportInfo sport,
  );

  /// `rpc_add_my_sport`: adds (or restores) the card, and follows.
  Future<Result<SportFollowOutcome, Failure>> addToMySports(
    String profileId,
    SportInfo sport, {
    int? skillLevel,
  });

  /// `rpc_remove_my_sport`: hides the card.
  Future<Result<SportFollowOutcome, Failure>> removeFromMySports(
    String profileId,
    SportInfo sport,
  );

  /// `rpc_set_sport_level` on an active card.
  Future<Result<SportFollowOutcome, Failure>> setLevel(
    String profileId,
    SportInfo sport,
    int skillLevel,
  );
}

class SupabaseSportFollowRepository implements SportFollowRepository {
  SupabaseSportFollowRepository(SupabaseClient db) : _rpc = MySportsRpc(db);

  final MySportsRpc _rpc;

  Result<SportFollowOutcome, Failure> _map(
    Result<SportOutcome, Failure> r,
    SportFollowOutcome done,
  ) => r.map((SportOutcome o) => sportFollowOutcomeOf(o, done));

  @override
  Future<Result<SportFollowOutcome, Failure>> follow(
    String profileId,
    SportInfo sport,
  ) async =>
      _map(await _rpc.follow(profileId, sport.id), SportFollowOutcome.followed);

  @override
  Future<Result<SportFollowOutcome, Failure>> unfollow(
    String profileId,
    SportInfo sport,
  ) async => _map(
    await _rpc.unfollow(profileId, sport.id),
    SportFollowOutcome.unfollowed,
  );

  @override
  Future<Result<SportFollowOutcome, Failure>> addToMySports(
    String profileId,
    SportInfo sport, {
    int? skillLevel,
  }) async => _map(
    await _rpc.add(profileId, sport.id, skillLevel: skillLevel),
    SportFollowOutcome.added,
  );

  @override
  Future<Result<SportFollowOutcome, Failure>> removeFromMySports(
    String profileId,
    SportInfo sport,
  ) async =>
      _map(await _rpc.remove(profileId, sport.id), SportFollowOutcome.removed);

  @override
  Future<Result<SportFollowOutcome, Failure>> setLevel(
    String profileId,
    SportInfo sport,
    int skillLevel,
  ) async => _map(
    await _rpc.setLevel(profileId, sport.id, skillLevel),
    SportFollowOutcome.levelSet,
  );
}
