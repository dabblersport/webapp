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

      // Use the canonical report_content RPC → moderation_reports table
      final response = await _db.rpc(
        'report_content',
        params: {
          'p_target_type': 'post',
          'p_target_id': postId,
          'p_reason': reason ?? 'other',
          if (details != null && details.isNotEmpty) 'p_details': details,
        },
      );

      final data = Map<String, dynamic>.from(response as Map<dynamic, dynamic>);

      // Map moderation_reports row to AbuseFlag for backward compat
      return AbuseFlag(
        id: data['id'] as String,
        reporterUserId: data['reporter_user_id'] as String,
        postId: data['target_id'] as String,
        reason: data['reason'] as String? ?? reason,
        details: data['details'] as String?,
        status: data['status'] as String? ?? 'open',
        createdAt: DateTime.parse(data['created_at'] as String),
      );
    });
  }

  @override
  Future<Result<List<AbuseFlag>, Failure>> getMyReports({
    int limit = 50,
  }) async {
    return guard<List<AbuseFlag>>(() async {
      final uid = _uid;
      if (uid == null) throw AuthException('Not authenticated');

      final rows =
          await _db
                  .from('moderation_reports')
                  .select()
                  .eq('reporter_user_id', uid)
                  .order('created_at', ascending: false)
                  .limit(limit)
              as List;

      return rows.map((r) => _modReportToAbuseFlag(r)).toList();
    });
  }

  @override
  Future<Result<List<AbuseFlag>, Failure>> getAllReports({
    int limit = 100,
    DateTime? since,
  }) async {
    return guard<List<AbuseFlag>>(() async {
      var query = _db.from('moderation_reports').select();

      if (since != null) {
        query = query.gte('created_at', since.toIso8601String());
      }

      final rows =
          await query.order('created_at', ascending: false).limit(limit)
              as List;
      return rows.map((r) => _modReportToAbuseFlag(r)).toList();
    });
  }

  @override
  Stream<List<AbuseFlag>> watchMyReports({int limit = 50}) {
    final uid = _uid;
    if (uid == null) {
      return const Stream<List<AbuseFlag>>.empty();
    }

    return _db
        .from('moderation_reports')
        .stream(primaryKey: ['id'])
        .eq('reporter_user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) => rows
              .map<AbuseFlag>((r) => _modReportToAbuseFlag(asMap(r)))
              .toList(),
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
      var query = _db.from('moderation_reports').select();

      if (status != null) {
        query = query.eq('status', status);
      }

      if (subjectType != null) {
        query = query.eq('target_type', subjectType);
      }

      if (before != null) {
        query = query.lt('created_at', before.toIso8601String());
      }

      final rows =
          await query.order('created_at', ascending: false).limit(limit)
              as List;

      return rows.map((r) => _modReportToAbuseFlag(asMap(r))).toList();
    });
  }

  /// Map a moderation_reports row to AbuseFlag for backward compatibility
  static AbuseFlag _modReportToAbuseFlag(Map<String, dynamic> r) {
    return AbuseFlag(
      id: (r['id'] ?? '').toString(),
      reporterUserId: (r['reporter_user_id'] ?? '').toString(),
      postId: (r['target_id'] ?? '').toString(),
      reason: r['reason']?.toString(),
      details: r['details']?.toString(),
      status: r['status']?.toString(),
      createdAt: r['created_at'] != null
          ? DateTime.parse(r['created_at'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
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
