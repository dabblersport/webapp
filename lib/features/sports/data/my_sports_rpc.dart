// KAN-1061: the client side of the KAN-1059 sports model. "Following" is the
// profile's `interests`; "My sports" are its active `sport_profiles` cards
// (`hidden_at IS NULL`). Every write goes through an owner-checked RPC that
// returns a text outcome; nothing deletes a card.

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What a sports RPC reported.
enum SportOutcome {
  /// The write landed (`followed`, `unfollowed`, `added`, `restored`,
  /// `removed`, `set`).
  done,

  /// Nothing to do (`unchanged`).
  unchanged,

  /// The sport is the profile's primary sport.
  blockedPrimary,

  /// The sport is still in My sports, so it cannot be unfollowed.
  blockedInMySports,

  /// It is the profile's last sport.
  blockedLast,

  /// The sport is unknown or inactive (`invalid_sport`), or the outcome is
  /// not one this client knows.
  invalid,
}

/// Maps an RPC's text result to a [SportOutcome].
SportOutcome sportOutcomeFrom(Object? raw) => switch (raw) {
  'followed' ||
  'unfollowed' ||
  'added' ||
  'restored' ||
  'removed' ||
  'set' => SportOutcome.done,
  'unchanged' => SportOutcome.unchanged,
  'blocked_primary' => SportOutcome.blockedPrimary,
  'blocked_in_my_sports' => SportOutcome.blockedInMySports,
  'blocked_last' => SportOutcome.blockedLast,
  _ => SportOutcome.invalid,
};

/// Calls the KAN-1059 sports RPCs for one profile.
class MySportsRpc {
  const MySportsRpc(this._db);

  final SupabaseClient _db;

  Future<Result<SportOutcome, Failure>> _call(
    String fn,
    Map<String, dynamic> params,
  ) => Result.guard(
    () async => sportOutcomeFrom(await _db.rpc(fn, params: params)),
    Failure.from,
  );

  Map<String, dynamic> _p(String profileId, String sportId) => {
    'p_profile_id': profileId,
    'p_sport_id': sportId,
  };

  Future<Result<SportOutcome, Failure>> follow(String profileId, String id) =>
      _call(SupabaseConfig.rpcFollowSportFn, _p(profileId, id));

  Future<Result<SportOutcome, Failure>> unfollow(String profileId, String id) =>
      _call(SupabaseConfig.rpcUnfollowSportFn, _p(profileId, id));

  Future<Result<SportOutcome, Failure>> add(
    String profileId,
    String id, {
    int? skillLevel,
  }) => _call(SupabaseConfig.rpcAddMySportFn, {
    ..._p(profileId, id),
    if (skillLevel != null) 'p_skill_level': skillLevel,
  });

  Future<Result<SportOutcome, Failure>> remove(String profileId, String id) =>
      _call(SupabaseConfig.rpcRemoveMySportFn, _p(profileId, id));

  Future<Result<SportOutcome, Failure>> setLevel(
    String profileId,
    String id,
    int skillLevel,
  ) => _call(SupabaseConfig.rpcSetSportLevelFn, {
    ..._p(profileId, id),
    'p_skill_level': skillLevel,
  });

  /// The id of the sport whose `sport_key` is [key], or null.
  Future<Result<String?, Failure>> sportIdForKey(String key) =>
      Result.guard(() async {
        final Map<String, dynamic>? row = await _db
            .from(SupabaseConfig.sportsTable)
            .select('id')
            .eq('sport_key', key.toLowerCase())
            .maybeSingle();
        return row?['id'] as String?;
      }, Failure.from);
}
