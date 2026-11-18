// KAN-1000 (G-02, G-03): the post-activity calls. Results (KAN-996) and
// ratings (KAN-997) are server-only tables; every read and write is an RPC.
// Names come from profiles / venues, the dimension labels from their
// tables. A refusal keeps the server's message as Failure.code.

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/data/attendance_repository.dart'
    show attendanceFailure;
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class PostActivityRepository {
  /// The G-02 state with names filled in.
  Future<Result<RatingFlow, Failure>> flow(String eventId);

  /// Active dimensions, in their sort order.
  Future<Result<List<RatingDimension>, Failure>> dimensions();

  /// The G-03 tally; `not_eligible` for a non-attendee.
  Future<Result<ResultTally, Failure>> result(String eventId);

  /// Returns (submissions, eligible).
  Future<Result<(int, int), Failure>> submitScore(
    String eventId,
    Score score,
    String side,
  );

  Future<Result<void, Failure>> rate(
    String eventId,
    RatingSubject subject,
    String? targetUserId,
    Map<String, int> scores,
  );

  Future<Result<void, Failure>> submitFlow(String eventId);

  /// rpc_rating_dismiss: stops the prompts for this event.
  Future<Result<void, Failure>> dismiss(String eventId);

  Future<Result<void, Failure>> approve(String eventId);

  Future<Result<void, Failure>> setFinal(String eventId, Score score);
}

class SupabasePostActivityRepository implements PostActivityRepository {
  SupabasePostActivityRepository(this._client);

  final SupabaseClient _client;

  Future<Object?> _rpc(String fn, Map<String, dynamic> params) =>
      _client.rpc(fn, params: params);

  @override
  Future<Result<RatingFlow, Failure>> flow(String eventId) => guardWithTimeout(
    () async {
      final data = await _rpc(SupabaseConfig.rpcRatingGetFn, {
        'p_event_id': eventId,
      });
      final flow = RatingFlow.fromJson(Map<String, dynamic>.from(data as Map));
      final ids = <String>{
        for (final p in flow.players) p.id,
        ?flow.organiser?.id,
      };
      final people = <String, String>{};
      if (ids.isNotEmpty) {
        final rows = await _client
            .from(SupabaseConfig.usersTable)
            .select('user_id, display_name, username')
            .inFilter('user_id', ids.toList());
        for (final r in rows) {
          final n = (r['display_name'] ?? r['username']) as String?;
          if (n != null && n.isNotEmpty) {
            people.putIfAbsent('${r['user_id']}', () => n);
          }
        }
      }
      String? venueName;
      if (flow.venue != null) {
        final v = await _client
            .from(SupabaseConfig.venuesTable)
            .select('name_en, name_ar')
            .eq('id', flow.venue!.id)
            .maybeSingle();
        venueName = (v?['name_en'] ?? v?['name_ar']) as String?;
      }
      return flow.withNames(people, venueName);
    },
    mapError: attendanceFailure,
  );

  @override
  Future<Result<List<RatingDimension>, Failure>> dimensions() =>
      guardWithTimeout(() async {
        final people = await _client
            .from(SupabaseConfig.reputationDimensionsTable)
            .select('key, label_en, label_ar, applicable_to')
            .eq('is_active', true)
            .order('sort_order');
        final venue = await _client
            .from(SupabaseConfig.venueRatingDimensionsTable)
            .select('key, label_en, label_ar')
            .eq('is_active', true)
            .order('sort_order');
        RatingDimension dim(Map r, Set<RatingSubject> s) => RatingDimension(
          key: '${r['key']}',
          labelEn: '${r['label_en'] ?? r['key']}',
          labelAr: '${r['label_ar'] ?? ''}',
          subjects: s,
        );
        return [
          for (final r in people)
            dim(r, {
              for (final a in (r['applicable_to'] as List? ?? const []))
                if (a == 'rate_player')
                  RatingSubject.player
                else if (a == 'rate_organiser')
                  RatingSubject.organiser,
            }),
          for (final r in venue) dim(r, {RatingSubject.venue}),
        ];
      }, mapError: attendanceFailure);

  @override
  Future<Result<ResultTally, Failure>> result(String eventId) =>
      guardWithTimeout(() async {
        final data = await _rpc(SupabaseConfig.rpcResultGetFn, {
          'p_event_id': eventId,
        });
        return ResultTally.fromJson(Map<String, dynamic>.from(data as Map));
      }, mapError: attendanceFailure);

  @override
  Future<Result<(int, int), Failure>> submitScore(
    String eventId,
    Score score,
    String side,
  ) => guardWithTimeout(() async {
    final data = await _rpc(SupabaseConfig.rpcResultSubmitFn, {
      'p_event_id': eventId,
      'p_score_a': score.a,
      'p_score_b': score.b,
      'p_side': side,
    });
    final m = data as Map;
    return (
      (m['submissions'] as num?)?.toInt() ?? 0,
      (m['eligible'] as num?)?.toInt() ?? 0,
    );
  }, mapError: attendanceFailure);

  @override
  Future<Result<void, Failure>> rate(
    String eventId,
    RatingSubject subject,
    String? targetUserId,
    Map<String, int> scores,
  ) => guardWithTimeout(() async {
    switch (subject) {
      case RatingSubject.player:
        await _rpc(SupabaseConfig.rpcRatePlayerFn, {
          'p_event_id': eventId,
          'p_ratee_user_id': targetUserId,
          'p_scores': scores,
        });
      case RatingSubject.organiser:
        await _rpc(SupabaseConfig.rpcRateOrganiserFn, {
          'p_event_id': eventId,
          'p_scores': scores,
        });
      case RatingSubject.venue:
        await _rpc(SupabaseConfig.rpcRateVenueFn, {
          'p_event_id': eventId,
          'p_scores': scores,
        });
    }
  }, mapError: attendanceFailure);

  @override
  Future<Result<void, Failure>> submitFlow(String eventId) =>
      guardWithTimeout(() async {
        await _rpc(SupabaseConfig.rpcRatingSubmitFn, {'p_event_id': eventId});
      }, mapError: attendanceFailure);

  @override
  Future<Result<void, Failure>> dismiss(String eventId) =>
      guardWithTimeout(() async {
        await _rpc(SupabaseConfig.rpcRatingDismissFn, {'p_event_id': eventId});
      }, mapError: attendanceFailure);

  @override
  Future<Result<void, Failure>> approve(String eventId) =>
      guardWithTimeout(() async {
        await _rpc(SupabaseConfig.rpcResultApproveFn, {'p_event_id': eventId});
      }, mapError: attendanceFailure);

  @override
  Future<Result<void, Failure>> setFinal(String eventId, Score score) =>
      guardWithTimeout(() async {
        await _rpc(SupabaseConfig.rpcResultSetFinalFn, {
          'p_event_id': eventId,
          'p_score_a': score.a,
          'p_score_b': score.b,
        });
      }, mapError: attendanceFailure);
}

final postActivityRepositoryProvider = Provider<PostActivityRepository>(
  (ref) => SupabasePostActivityRepository(ref.watch(supabaseClientProvider)),
);
