import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import '../models/circle_contact.dart';
import 'circle_repository.dart';

class CircleRepositoryImpl implements CircleRepository {
  final SupabaseService svc;
  CircleRepositoryImpl(this.svc);
  SupabaseClient get _db => svc.client;

  @override
  Future<Result<List<CircleContact>, Failure>> circleList() async {
    try {
      final rows = await _db.rpc('rpc_circle_list');
      if (rows is List) {
        final list = rows
            .cast<Map<String, dynamic>>()
            .map(CircleContact.fromJson)
            .toList();
        return Ok(list);
      }
      return Err(
        ServerFailure(message: 'rpc_circle_list returned unexpected shape'),
      );
    } catch (e) {
      return Err(svc.mapPostgrestError(e));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> circleView({
    int? limit,
    int? offset,
  }) async {
    try {
      final dynamic q = limit != null && offset != null
          ? _db.from('v_circle').select().range(offset, offset + limit - 1)
          : _db.from('v_circle').select();
      final rows = await q;
      return Ok(rows.cast<Map<String, dynamic>>());
    } catch (e) {
      return Err(svc.mapPostgrestError(e));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> circleFeed({
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final rows = await _db
          .from('v_feed_circle')
          .select()
          // no ordering assumptions; keep pagination simple
          .range(offset, offset + limit - 1);
      return Ok(rows.cast<Map<String, dynamic>>());
    } catch (e) {
      return Err(svc.mapPostgrestError(e));
    }
  }

  @override
  Stream<Result<List<Map<String, dynamic>>, Failure>> circleFeedStream({
    int limit = 30,
    int offset = 0,
  }) async* {
    // We don't know the primary key of v_feed_circle; streaming the view
    // directly would require that. Instead, listen to friend_edges changes
    // for the current user and refetch the feed when they occur.
    try {
      final uid = svc.authUserId();
      if (uid == null) {
        yield Err(const AuthFailure(message: 'Not authenticated'));
        return;
      }

      // Start with an initial fetch
      yield await circleFeed(limit: limit, offset: offset);

      // Note: .or() is not available on stream builder in newer Supabase versions
      // We'll stream all friend_edges changes for now (RLS will filter to user's edges)
      final edgesStream = _db.from('friend_edges').stream(primaryKey: ['id']);

      await for (final _ in edgesStream) {
        yield await circleFeed(limit: limit, offset: offset);
      }
    } catch (e) {
      yield Err(svc.mapPostgrestError(e));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>>
  friendRequestsInbox() async {
    try {
      final rows = await _db.rpc('rpc_friend_requests_inbox');
      if (rows is List) return Ok(rows.cast<Map<String, dynamic>>());
      return Err(ServerFailure(message: 'Unexpected inbox shape'));
    } catch (e) {
      return Err(svc.mapPostgrestError(e));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>>
  friendRequestsOutbox() async {
    try {
      final rows = await _db.rpc('rpc_friend_requests_outbox');
      if (rows is List) return Ok(rows.cast<Map<String, dynamic>>());
      return Err(ServerFailure(message: 'Unexpected outbox shape'));
    } catch (e) {
      return Err(svc.mapPostgrestError(e));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> squadCards({
    String? squadId,
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic q = _db.from('v_squad_card').select();
      if (squadId != null) {
        q = q.eq('id', squadId); // best-effort generic filter
      }
      if (limit != null && offset != null) {
        q = q.range(offset, offset + limit - 1);
      }
      final rows = await q;
      return Ok(rows.cast<Map<String, dynamic>>());
    } catch (e) {
      return Err(svc.mapPostgrestError(e));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> squadDetail(
    String squadId,
  ) async {
    try {
      final rows = await _db.from('v_squad_detail').select().eq('id', squadId);
      return Ok(rows.cast<Map<String, dynamic>>());
    } catch (e) {
      return Err(svc.mapPostgrestError(e));
    }
  }
}
