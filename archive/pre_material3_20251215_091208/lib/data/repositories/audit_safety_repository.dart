import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/abuse_flag.dart';
import '../models/ban_term.dart';
import '../models/moderation_action.dart';
import '../models/moderation_ticket.dart';

abstract class AuditSafetyRepository {
  /// Submit a new report for the currently authenticated user.
  /// Returns the inserted AbuseFlag (if PostgREST returns it) or a minimal echo object.
  Future<Result<AbuseFlag, Failure>> submitPostReport({
    required String postId,
    String? reason,
    String? details,
  });

  /// Current user's reports (RLS: reporter or admin).
  Future<Result<List<AbuseFlag>, Failure>> getMyReports({int limit = 50});

  /// (Admin) List all recent reports. RLS will restrict non-admins automatically.
  Future<Result<List<AbuseFlag>, Failure>> getAllReports({
    int limit = 100,
    DateTime? since,
  });

  /// Watch current user's reports in realtime (ordered DESC).
  Stream<List<AbuseFlag>> watchMyReports({int limit = 50});

  /// List abuse flags with optional filtering (admin-focused).
  Future<Result<List<AbuseFlag>, Failure>> listFlags({
    String? status,
    String? subjectType,
    int limit = 50,
    DateTime? before,
  });

  /// List moderation tickets with optional filtering.
  Future<Result<List<ModerationTicket>, Failure>> listTickets({
    String? status,
    int limit = 50,
    DateTime? before,
  });

  /// List moderation actions with optional filtering.
  Future<Result<List<ModerationAction>, Failure>> listActions({
    String? subjectType,
    String? subjectId,
    int limit = 50,
    DateTime? before,
  });

  /// List ban terms, optionally filtered by enabled status.
  Future<Result<List<BanTerm>, Failure>> listBanTerms({bool? enabled});
}
