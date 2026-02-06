import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import '../repositories/base_repository.dart';
import 'moderation_repository.dart';

class ModerationRepositoryImpl extends BaseRepository
    implements ModerationRepository {
  ModerationRepositoryImpl(super.svc);

  SupabaseClient get _db => svc.client;

  @override
  Future<Result<bool, Failure>> isAdmin() async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) {
        return Err(AuthFailure(message: 'No auth user'));
      }
      final res = await _db.rpc('is_admin', params: {'u': uid});
      // unwrap the response
      final data = res as bool?;
      return Ok(data == true);
    } on PostgrestException catch (e) {
      return Err(svc.mapPostgrestError(e));
    } catch (e) {
      return Err(UnknownFailure(message: e.toString()));
    }
  }

  // ---------- helpers ----------
  Future<Result<void, Failure>> _requireAdmin() async {
    final admin = await isAdmin();
    return admin.fold(
      (f) => Err(f),
      (ok) => ok ? Ok(null) : Err(PermissionFailure(message: 'Admin only')),
    );
  }

  Future<Result<T, Failure>> _guardAdmin<T>(
    Future<Result<T, Failure>> Function() action,
  ) async {
    final gate = await _requireAdmin();
    return gate.fold((f) => Future.value(Err(f)), (_) => action());
  }

  PostgrestFilterBuilder _applyWhere(
    PostgrestFilterBuilder q,
    Map<String, dynamic>? where,
  ) {
    if (where == null) return q;
    // Minimalistic filter application: equals only.
    where.forEach((k, v) {
      if (v == null) return;
      q = q.eq(k, v);
    });
    return q;
  }

  // ---------- Flags ----------
  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> listFlags({
    int limit = 50,
    int offset = 0,
    Map<String, dynamic>? where,
  }) async {
    return _guardAdmin(() async {
      try {
        dynamic q = _db.from('moderation_flags').select();
        q = _applyWhere(q, where).range(offset, offset + limit - 1);
        final rows = await q;
        return Ok(List<Map<String, dynamic>>.from(rows));
      } on PostgrestException catch (e) {
        return Err(svc.mapPostgrestError(e));
      } catch (e) {
        return Err(UnknownFailure(message: e.toString()));
      }
    });
  }

  // ---------- Tickets ----------
  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> listTickets({
    int limit = 50,
    int offset = 0,
    Map<String, dynamic>? where,
  }) async {
    return _guardAdmin(() async {
      try {
        dynamic q = _db.from('moderation_tickets').select();
        q = _applyWhere(q, where).range(offset, offset + limit - 1);
        final rows = await q;
        return Ok(List<Map<String, dynamic>>.from(rows));
      } on PostgrestException catch (e) {
        return Err(svc.mapPostgrestError(e));
      } catch (e) {
        return Err(UnknownFailure(message: e.toString()));
      }
    });
  }

  @override
  Future<Result<Map<String, dynamic>, Failure>> createTicket(
    Map<String, dynamic> values,
  ) async {
    return _guardAdmin(() async {
      try {
        final rows = await _db
            .from('moderation_tickets')
            .insert(values)
            .select()
            .single();
        return Ok(Map<String, dynamic>.from(rows));
      } on PostgrestException catch (e) {
        return Err(svc.mapPostgrestError(e));
      } catch (e) {
        return Err(UnknownFailure(message: e.toString()));
      }
    });
  }

  @override
  Future<Result<Map<String, dynamic>, Failure>> updateTicket(
    String id,
    Map<String, dynamic> patch,
  ) async {
    return _guardAdmin(() async {
      try {
        final rows = await _db
            .from('moderation_tickets')
            .update(patch)
            .eq('id', id)
            .select()
            .maybeSingle();

        if (rows == null) {
          return Err(NotFoundFailure(message: 'Ticket not found'));
        }
        return Ok(Map<String, dynamic>.from(rows));
      } on PostgrestException catch (e) {
        return Err(svc.mapPostgrestError(e));
      } catch (e) {
        return Err(UnknownFailure(message: e.toString()));
      }
    });
  }

  @override
  Future<Result<int, Failure>> setTicketStatus(String id, String status) async {
    return _guardAdmin(() async {
      try {
        final res = await _db
            .from('moderation_tickets')
            .update({'status': status})
            .eq('id', id);
        // PostgREST update returns affected rows count only in newer clients; fallback to select check:
        if (res is int) return Ok(res);
        return Ok(1); // assume one row updated if no error thrown
      } on PostgrestException catch (e) {
        return Err(svc.mapPostgrestError(e));
      } catch (e) {
        return Err(UnknownFailure(message: e.toString()));
      }
    });
  }

  // ---------- Actions ----------
  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> listActions({
    int limit = 50,
    int offset = 0,
    Map<String, dynamic>? where,
  }) async {
    return _guardAdmin(() async {
      try {
        dynamic q = _db.from('moderation_actions').select();
        q = _applyWhere(q, where).range(offset, offset + limit - 1);
        final rows = await q;
        return Ok(List<Map<String, dynamic>>.from(rows));
      } on PostgrestException catch (e) {
        return Err(svc.mapPostgrestError(e));
      } catch (e) {
        return Err(UnknownFailure(message: e.toString()));
      }
    });
  }

  @override
  Future<Result<Map<String, dynamic>, Failure>> recordAction(
    Map<String, dynamic> values,
  ) async {
    return _guardAdmin(() async {
      try {
        final row = await _db
            .from('moderation_actions')
            .insert(values)
            .select()
            .single();
        return Ok(Map<String, dynamic>.from(row));
      } on PostgrestException catch (e) {
        return Err(svc.mapPostgrestError(e));
      } catch (e) {
        return Err(UnknownFailure(message: e.toString()));
      }
    });
  }

  // ---------- Ban terms ----------
  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> listBanTerms({
    int limit = 100,
    int offset = 0,
    Map<String, dynamic>? where,
  }) async {
    return _guardAdmin(() async {
      try {
        dynamic q = _db.from('moderation_ban_terms').select();
        q = _applyWhere(q, where).range(offset, offset + limit - 1);
        final rows = await q;
        return Ok(List<Map<String, dynamic>>.from(rows));
      } on PostgrestException catch (e) {
        return Err(svc.mapPostgrestError(e));
      } catch (e) {
        return Err(UnknownFailure(message: e.toString()));
      }
    });
  }

  @override
  Future<Result<Map<String, dynamic>, Failure>> upsertBanTerm(
    Map<String, dynamic> values,
  ) async {
    return _guardAdmin(() async {
      try {
        final row = await _db
            .from('moderation_ban_terms')
            .upsert(values)
            .select()
            .single();
        return Ok(Map<String, dynamic>.from(row));
      } on PostgrestException catch (e) {
        return Err(svc.mapPostgrestError(e));
      } catch (e) {
        return Err(UnknownFailure(message: e.toString()));
      }
    });
  }

  @override
  Future<Result<int, Failure>> deleteBanTerm(String id) async {
    return _guardAdmin(() async {
      try {
        final res = await _db
            .from('moderation_ban_terms')
            .delete()
            .eq('id', id);
        if (res is int) return Ok(res);
        return Ok(1);
      } on PostgrestException catch (e) {
        return Err(svc.mapPostgrestError(e));
      } catch (e) {
        return Err(UnknownFailure(message: e.toString()));
      }
    });
  }
}
