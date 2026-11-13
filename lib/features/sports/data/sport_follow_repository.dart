import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';

/// What a Follow / Unfollow ended in (KAN-622, decisions of KAN-590/591).
enum SportFollowOutcome {
  followed,
  unfollowed,

  /// Already in the wanted state; nothing was written.
  unchanged,

  /// Unfollow refused: it would leave the persona with no Following sport.
  blockedLast,

  /// Unfollow refused: the sport is one the persona Practices (has a sport
  /// profile for).
  blockedPracticing,

  /// Unfollow refused: the sport is the persona's Primary sport.
  blockedPrimary,
}

/// Follow / Unfollow on the active persona's Following (`profiles.interests`).
///
/// Following is only that array. This never creates or deletes a sport
/// profile and never touches Practicing or Primary: a refused unfollow writes
/// nothing at all. The guards read the database fresh, so a stale screen
/// cannot unfollow a protected sport.
abstract class SportFollowRepository {
  Future<Result<SportFollowOutcome, Failure>> follow(
    String profileId,
    SportInfo sport,
  );

  Future<Result<SportFollowOutcome, Failure>> unfollow(
    String profileId,
    SportInfo sport,
  );
}

class SupabaseSportFollowRepository implements SportFollowRepository {
  const SupabaseSportFollowRepository(this._db);

  final SupabaseClient _db;

  Future<Map<String, dynamic>> _profile(String profileId) async {
    final Map<String, dynamic> row = await _db
        .from(SupabaseConfig.usersTable)
        .select('interests, preferred_sport, primary_sport, persona_type')
        .eq('id', profileId)
        .single();
    return row;
  }

  static List<String> _interests(Map<String, dynamic> row) => [
    for (final Object? v in (row['interests'] as List?) ?? const <Object?>[])
      if (v is String && v.isNotEmpty) v,
  ];

  Future<void> _write(String profileId, List<String> interests) => _db
      .from(SupabaseConfig.usersTable)
      .update(<String, dynamic>{'interests': interests})
      .eq('id', profileId);

  @override
  Future<Result<SportFollowOutcome, Failure>> follow(
    String profileId,
    SportInfo sport,
  ) => guardWithTimeout(() async {
    final List<String> current = _interests(await _profile(profileId));
    if (current.contains(sport.id)) return SportFollowOutcome.unchanged;
    await _write(profileId, <String>[...current, sport.id]);
    return SportFollowOutcome.followed;
  });

  @override
  Future<Result<SportFollowOutcome, Failure>> unfollow(
    String profileId,
    SportInfo sport,
  ) => guardWithTimeout(() async {
    final Map<String, dynamic> row = await _profile(profileId);
    final List<String> current = _interests(row);
    if (!current.contains(sport.id)) return SportFollowOutcome.unchanged;

    if (row['primary_sport'] == sport.id ||
        row['preferred_sport'] == sport.id) {
      return SportFollowOutcome.blockedPrimary;
    }
    if (await _practices(profileId, row['persona_type'] as String?, sport)) {
      return SportFollowOutcome.blockedPracticing;
    }
    if (current.length <= 1) return SportFollowOutcome.blockedLast;

    await _write(profileId, <String>[
      for (final String id in current)
        if (id != sport.id) id,
    ]);
    return SportFollowOutcome.unfollowed;
  });

  /// Whether the persona has a sport profile (player) or organiser record for
  /// the sport: the two places Practicing lives.
  Future<bool> _practices(
    String profileId,
    String? personaType,
    SportInfo sport,
  ) async {
    final bool organiser =
        personaType == 'organiser' || personaType == 'business';
    final List<dynamic> rows = await _db
        .from(
          organiser
              ? SupabaseConfig.organiserTable
              : SupabaseConfig.sportProfilesTable,
        )
        .select(organiser ? 'sport' : 'sport, sport_id')
        .eq('profile_id', profileId);
    final String? key = sport.sportKey?.toLowerCase();
    return rows.any((Object? r) {
      if (r is! Map) return false;
      if (r['sport_id'] == sport.id) return true;
      return key != null && (r['sport'] as String?)?.toLowerCase() == key;
    });
  }
}
