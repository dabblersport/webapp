import 'package:meta/meta.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import '../models/abuse_flag.dart';
import '../models/ban_term.dart';
import '../models/moderation_action.dart';
import '../models/moderation_ticket.dart';
import 'audit_safety_repository.dart';
import 'base_repository.dart';

@immutable
class AuditSafetyRepositoryImpl extends BaseRepository
    implements AuditSafetyRepository {
  const AuditSafetyRepositoryImpl(super.svc);

  SupabaseClient get _db => svc.client;

  String? get _uid => _db.auth.currentUser?.id;

  @override
  Future<Result<AbuseFlag, Failure>> submitPostReport({
    required String postId,
    String? reason,
    String? details,
  }) async {
    return guard<AbuseFlag>(() async {
      final uid = _uid;
      if (uid == null) throw AuthException('Not authenticated');

      // RLS: INSERT allowed when reporter_user_id = auth.uid()
      final payload = {
        'reporter_user_id': uid,
        'post_id': postId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      };

      final inserted = await _db
          .from('post_reports')
          .insert(payload)
          .select()
          .single();

      return AbuseFlag.fromMap(inserted);
    });
  }

  @override
  Future<Result<List<AbuseFlag>, Failure>> getMyReports({
    int limit = 50,
  }) async {
    return guard<List<AbuseFlag>>(() async {
      final uid = _uid;
      if (uid == null) throw AuthException('Not authenticated');

      // RLS: reporter_user_id = auth.uid() OR admin
      final rows =
          await _db
                  .from('post_reports')
                  .select()
                  .eq('reporter_user_id', uid)
                  .order('created_at', ascending: false)
                  .limit(limit)
              as List;

      return rows.map((r) => AbuseFlag.fromMap(r)).toList();
    });
  }

  @override
  Future<Result<List<AbuseFlag>, Failure>> getAllReports({
    int limit = 100,
    DateTime? since,
  }) async {
    return guard<List<AbuseFlag>>(() async {
      // If the caller isn't admin, RLS will naturally reduce the set to their own reports.
      var query = _db.from('post_reports').select();

      if (since != null) {
        query = query.gte('created_at', since.toIso8601String());
      }

      final rows =
          await query.order('created_at', ascending: false).limit(limit)
              as List;
      return rows.map((r) => AbuseFlag.fromMap(r)).toList();
    });
  }

  @override
  Stream<List<AbuseFlag>> watchMyReports({int limit = 50}) {
    final uid = _uid;
    if (uid == null) {
      return const Stream<List<AbuseFlag>>.empty();
    }

    // Realtime subscription scoped to the reporter via filter.
    return _db
        .from('post_reports')
        .stream(primaryKey: ['id'])
        .eq('reporter_user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) =>
              rows.map<AbuseFlag>((r) => AbuseFlag.fromMap(asMap(r))).toList(),
        );
  }

  @override
  Future<Result<List<AbuseFlag>, Failure>> listFlags({
    String? status,
    String? subjectType,
    int limit = 50,
    DateTime? before,
  }) async {
    return guard<List<AbuseFlag>>(() async {
      var query = _db.from('post_reports').select();

      if (status != null) {
        query = query.eq('status', status);
      }

      if (subjectType != null) {
        query = query.eq('subject_type', subjectType);
      }

      if (before != null) {
        query = query.lt('created_at', before.toIso8601String());
      }

      final rows =
          await query.order('created_at', ascending: false).limit(limit)
              as List;

      return rows.map((r) => AbuseFlag.fromMap(asMap(r))).toList();
    });
  }

  @override
  Future<Result<List<ModerationTicket>, Failure>> listTickets({
    String? status,
    int limit = 50,
    DateTime? before,
  }) async {
    return guard<List<ModerationTicket>>(() async {
      var query = _db.from('moderation_tickets').select();

      if (status != null) {
        query = query.eq('status', status);
      }

      if (before != null) {
        query = query.lt('created_at', before.toIso8601String());
      }

      final rows =
          await query.order('created_at', ascending: false).limit(limit)
              as List;

      return rows.map((r) => ModerationTicket.fromJson(asMap(r))).toList();
    });
  }

  @override
  Future<Result<List<ModerationAction>, Failure>> listActions({
    String? subjectType,
    String? subjectId,
    int limit = 50,
    DateTime? before,
  }) async {
    return guard<List<ModerationAction>>(() async {
      var query = _db.from('moderation_actions').select();

      if (subjectType != null) {
        query = query.eq('subject_type', subjectType);
      }

      if (subjectId != null) {
        query = query.eq('subject_id', subjectId);
      }

      if (before != null) {
        query = query.lt('created_at', before.toIso8601String());
      }

      final rows =
          await query.order('created_at', ascending: false).limit(limit)
              as List;

      return rows.map((r) => ModerationAction.fromJson(asMap(r))).toList();
    });
  }

  @override
  Future<Result<List<BanTerm>, Failure>> listBanTerms({bool? enabled}) async {
    return guard<List<BanTerm>>(() async {
      var query = _db.from('ban_terms').select();

      if (enabled != null) {
        query = query.eq('enabled', enabled);
      }

      final rows = await query.order('created_at', ascending: false) as List;

      return rows.map((r) => BanTerm.fromJson(asMap(r))).toList();
    });
  }
}
