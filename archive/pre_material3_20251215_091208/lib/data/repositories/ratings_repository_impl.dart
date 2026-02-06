import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import '../models/rating.dart';
import 'base_repository.dart';
import 'ratings_repository.dart';

@immutable
class RatingsRepositoryImpl extends BaseRepository
    implements RatingsRepository {
  const RatingsRepositoryImpl(super.svc);

  SupabaseClient get _db => svc.client;
  String? get _uid => _db.auth.currentUser?.id;

  // --- lists ---------------------------------------------------------------

  @override
  Future<Result<List<Rating>, Failure>> listGiven({
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    return guard<List<Rating>>(() async {
      final uid = _uid;
      if (uid == null) throw const AuthFailure(message: 'Not signed in');

      dynamic q = _db.from('ratings').select().eq('rater_user_id', uid);

      if (from != null) q = q.gte('created_at', from.toUtc().toIso8601String());
      if (to != null) q = q.lte('created_at', to.toUtc().toIso8601String());

      q = q.order('created_at', ascending: false).limit(limit);

      // RLS: allowed when rater_user_id = auth.uid() (and for admins).
      final rows = await q;
      return rows.map((m) => Rating.fromMap(asMap(m))).toList();
    });
  }

  @override
  Future<Result<List<Rating>, Failure>> listAboutMe({
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    return guard<List<Rating>>(() async {
      final uid = _uid;
      if (uid == null) throw const AuthFailure(message: 'Not signed in');

      dynamic q = _db.from('ratings').select().eq('target_user_id', uid);

      if (from != null) q = q.gte('created_at', from.toUtc().toIso8601String());
      if (to != null) q = q.lte('created_at', to.toUtc().toIso8601String());

      q = q.order('created_at', ascending: false).limit(limit);

      // RLS: allowed when target_user_id = auth.uid() (and for admins).
      final rows = await q;
      return rows.map((m) => Rating.fromMap(asMap(m))).toList();
    });
  }

  @override
  Future<Result<List<Rating>, Failure>> listForGame(
    String gameId, {
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    return guard<List<Rating>>(() async {
      dynamic q = _db.from('ratings').select().eq('target_game_id', gameId);

      if (from != null) q = q.gte('created_at', from.toUtc().toIso8601String());
      if (to != null) q = q.lte('created_at', to.toUtc().toIso8601String());

      q = q.order('created_at', ascending: false).limit(limit);

      // RLS: allowed for the game's host via policy, or admin.
      final rows = await q;
      return rows.map((m) => Rating.fromMap(asMap(m))).toList();
    });
  }

  @override
  Future<Result<List<Rating>, Failure>> listForVenue(
    String venueId, {
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    return guard<List<Rating>>(() async {
      dynamic q = _db.from('ratings').select().eq('target_venue_id', venueId);

      if (from != null) q = q.gte('created_at', from.toUtc().toIso8601String());
      if (to != null) q = q.lte('created_at', to.toUtc().toIso8601String());

      q = q.order('created_at', ascending: false).limit(limit);

      // RLS: allowed for venue owners/managers via policy, or admin.
      final rows = await q;
      return rows.map((m) => Rating.fromMap(asMap(m))).toList();
    });
  }

  // --- aggregates ----------------------------------------------------------

  @override
  Future<Result<RatingAggregate?, Failure>> getUserAggregate(
    String userId,
  ) async {
    return guard<RatingAggregate?>(() async {
      final row = await _db
          .from('user_reputation_aggregate')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return RatingAggregate.fromMap(row);
    });
  }

  @override
  Future<Result<RatingAggregate?, Failure>> getGameAggregate(
    String gameId,
  ) async {
    return guard<RatingAggregate?>(() async {
      final row = await _db
          .from('game_rating_aggregate')
          .select()
          .eq('game_id', gameId)
          .maybeSingle();
      if (row == null) return null;
      return RatingAggregate.fromMap(row);
    });
  }

  @override
  Future<Result<RatingAggregate?, Failure>> getVenueAggregate(
    String venueId,
  ) async {
    return guard<RatingAggregate?>(() async {
      final row = await _db
          .from('venue_rating_aggregate')
          .select()
          .eq('venue_id', venueId)
          .maybeSingle();
      if (row == null) return null;
      return RatingAggregate.fromMap(row);
    });
  }
}
