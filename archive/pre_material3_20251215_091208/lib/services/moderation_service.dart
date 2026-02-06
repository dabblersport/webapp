import 'package:dabbler/core/utils/logger.dart';
import 'package:riverpod/riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
// ENUMS
// =============================================================================

/// Moderation target types matching Postgres enum `mod_target`
enum ModTarget {
  user,
  profile,
  post,
  comment,
  game,
  squad,
  venue,
  message,
  other;

  String toPostgresString() {
    return name;
  }

  static ModTarget fromPostgresString(String value) {
    return ModTarget.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ModTarget.other,
    );
  }
}

/// Report reason types matching Postgres enum `report_reason`
enum ReportReason {
  spam,
  abuse,
  hate,
  harassment,
  nudity,
  illegal,
  danger,
  scam,
  impersonation,
  other;

  String toPostgresString() {
    return name;
  }

  static ReportReason fromPostgresString(String value) {
    return ReportReason.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReportReason.other,
    );
  }
}

/// Report status types matching Postgres enum `report_status`
enum ReportStatus {
  open,
  triage,
  escalated,
  resolved,
  dismissed,
  duplicate;

  String toPostgresString() {
    return name;
  }

  static ReportStatus fromPostgresString(String value) {
    return ReportStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReportStatus.open,
    );
  }
}

/// Moderation action types matching Postgres enum `mod_action`
enum ModAction {
  warn,
  freeze,
  unfreeze,
  shadowban,
  unshadowban,
  takedown,
  restore,
  restrict,
  ban,
  unban;

  String toPostgresString() {
    return name;
  }

  static ModAction fromPostgresString(String value) {
    return ModAction.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ModAction.warn,
    );
  }
}

// =============================================================================
// MODEL CLASSES
// =============================================================================

/// Model for moderation reports matching `public.moderation_reports` table
class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.reporterUserId,
    required this.targetType,
    required this.targetId,
    this.targetUserId,
    required this.reason,
    this.details,
    required this.status,
    this.duplicateOf,
    this.contentSnapshot,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.resolution,
  });

  final String id;
  final String reporterUserId;
  final ModTarget targetType;
  final String targetId;
  final String? targetUserId;
  final ReportReason reason;
  final String? details;
  final ReportStatus status;
  final String? duplicateOf;
  final Map<String, dynamic>? contentSnapshot;
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? resolution;

  factory ModerationReport.fromJson(Map<String, dynamic> json) {
    return ModerationReport(
      id: json['id'] as String,
      reporterUserId: json['reporter_user_id'] as String,
      targetType: ModTarget.fromPostgresString(json['target_type'] as String),
      targetId: json['target_id'] as String,
      targetUserId: json['target_user_id'] as String?,
      reason: ReportReason.fromPostgresString(json['reason'] as String),
      details: json['details'] as String?,
      status: ReportStatus.fromPostgresString(json['status'] as String),
      duplicateOf: json['duplicate_of'] as String?,
      contentSnapshot: json['content_snapshot'] == null
          ? null
          : Map<String, dynamic>.from(json['content_snapshot'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] == null
          ? null
          : DateTime.parse(json['reviewed_at'] as String),
      resolution: json['resolution'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_user_id': reporterUserId,
      'target_type': targetType.toPostgresString(),
      'target_id': targetId,
      'target_user_id': targetUserId,
      'reason': reason.toPostgresString(),
      'details': details,
      'status': status.toPostgresString(),
      'duplicate_of': duplicateOf,
      'content_snapshot': contentSnapshot,
      'created_at': createdAt.toIso8601String(),
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'resolution': resolution,
    };
  }
}

/// Model for moderation actions matching `public.moderation_actions` table
class ModerationActionModel {
  const ModerationActionModel({
    required this.id,
    required this.action,
    this.actorUserId,
    required this.targetType,
    required this.targetId,
    this.targetUserId,
    this.reason,
    required this.createdAt,
    this.expiresAt,
    this.meta,
  });

  final String id;
  final ModAction action;
  final String? actorUserId;
  final ModTarget targetType;
  final String targetId;
  final String? targetUserId;
  final String? reason;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? meta;

  factory ModerationActionModel.fromJson(Map<String, dynamic> json) {
    return ModerationActionModel(
      id: json['id'] as String,
      action: ModAction.fromPostgresString(json['action'] as String),
      actorUserId: json['actor_user_id'] as String?,
      targetType: ModTarget.fromPostgresString(json['target_type'] as String),
      targetId: json['target_id'] as String,
      targetUserId: json['target_user_id'] as String?,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      meta: json['meta'] == null
          ? null
          : Map<String, dynamic>.from(json['meta'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.toPostgresString(),
      'actor_user_id': actorUserId,
      'target_type': targetType.toPostgresString(),
      'target_id': targetId,
      'target_user_id': targetUserId,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'meta': meta,
    };
  }
}

/// Result from `check_and_bump_cooldown` RPC
class CooldownResult {
  const CooldownResult({
    required this.allowed,
    required this.remaining,
    required this.resetAt,
  });

  final bool allowed;
  final int remaining;
  final DateTime resetAt;

  factory CooldownResult.fromJson(Map<String, dynamic> json) {
    return CooldownResult(
      allowed: json['allowed'] as bool,
      remaining: json['remaining'] as int,
      resetAt: DateTime.parse(json['reset_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowed': allowed,
      'remaining': remaining,
      'reset_at': resetAt.toIso8601String(),
    };
  }
}

/// Summary for moderation queue from `v_mod_queue_open` view
class ModerationReportSummary {
  const ModerationReportSummary({
    required this.reportId,
    required this.status,
    required this.reason,
    required this.createdAt,
    required this.targetType,
    required this.targetId,
    this.targetUserId,
    this.reporterUsername,
    this.targetUsername,
    this.details,
  });

  final String reportId;
  final ReportStatus status;
  final ReportReason reason;
  final DateTime createdAt;
  final ModTarget targetType;
  final String targetId;
  final String? targetUserId;
  final String? reporterUsername;
  final String? targetUsername;
  final String? details;

  factory ModerationReportSummary.fromJson(Map<String, dynamic> json) {
    return ModerationReportSummary(
      reportId: json['report_id'] as String,
      status: ReportStatus.fromPostgresString(json['status'] as String),
      reason: ReportReason.fromPostgresString(json['reason'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      targetType: ModTarget.fromPostgresString(json['target_type'] as String),
      targetId: json['target_id'] as String,
      targetUserId: json['target_user_id'] as String?,
      reporterUsername: json['reporter_username'] as String?,
      targetUsername: json['target_username'] as String?,
      details: json['details'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'report_id': reportId,
      'status': status.toPostgresString(),
      'reason': reason.toPostgresString(),
      'created_at': createdAt.toIso8601String(),
      'target_type': targetType.toPostgresString(),
      'target_id': targetId,
      'target_user_id': targetUserId,
      'reporter_username': reporterUsername,
      'target_username': targetUsername,
      'details': details,
    };
  }
}

/// Safety overview from `v_safety_overview` view
class SafetyOverview {
  const SafetyOverview({
    required this.reportsOpen,
    required this.activeEnforcements,
    required this.takedownsActive,
    required this.audits24h,
    required this.asOf,
  });

  final int reportsOpen;
  final int activeEnforcements;
  final int takedownsActive;
  final int audits24h;
  final DateTime asOf;

  factory SafetyOverview.fromJson(Map<String, dynamic> json) {
    return SafetyOverview(
      reportsOpen: json['reports_open'] as int,
      activeEnforcements: json['active_enforcements'] as int,
      takedownsActive: json['takedowns_active'] as int,
      audits24h: json['audits_24h'] as int,
      asOf: DateTime.parse(json['as_of'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reports_open': reportsOpen,
      'active_enforcements': activeEnforcements,
      'takedowns_active': takedownsActive,
      'audits_24h': audits24h,
      'as_of': asOf.toIso8601String(),
    };
  }
}

/// Audit event from `public.audit_events` table
class AuditEvent {
  const AuditEvent({
    required this.id,
    this.actorUserId,
    required this.action,
    required this.targetType,
    this.targetId,
    this.targetUserId,
    this.meta,
    required this.createdAt,
  });

  final String id;
  final String? actorUserId;
  final String action;
  final ModTarget targetType;
  final String? targetId;
  final String? targetUserId;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    return AuditEvent(
      id: json['id'] as String,
      actorUserId: json['actor_user_id'] as String?,
      action: json['action'] as String,
      targetType: ModTarget.fromPostgresString(json['target_type'] as String),
      targetId: json['target_id'] as String?,
      targetUserId: json['target_user_id'] as String?,
      meta: json['meta'] == null
          ? null
          : Map<String, dynamic>.from(json['meta'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actor_user_id': actorUserId,
      'action': action,
      'target_type': targetType.toPostgresString(),
      'target_id': targetId,
      'target_user_id': targetUserId,
      'meta': meta,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// =============================================================================
// EXCEPTION CLASS
// =============================================================================

class ModerationServiceException implements Exception {
  ModerationServiceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ModerationServiceException: $message';
}

// =============================================================================
// SERVICE CLASS
// =============================================================================

class ModerationService {
  ModerationService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _logTag = 'ModerationService';

  // =============================================================================
  // USER-FACING METHODS
  // =============================================================================

  /// Submit a content report via `report_content` RPC
  Future<ModerationReport> submitReport({
    required ModTarget target,
    required String targetId,
    required ReportReason reason,
    String? details,
    Map<String, dynamic>? snapshot,
  }) async {
    try {
      Logger.debug(
        '$_logTag: Submitting report for target=$target targetId=$targetId reason=$reason',
      );

      final response = await _supabase.rpc(
        'report_content',
        params: {
          'p_target_type': target.toPostgresString(),
          'p_target_id': targetId,
          'p_reason': reason.toPostgresString(),
          if (details != null) 'p_details': details,
          if (snapshot != null) 'p_snapshot': snapshot,
        },
      );

      final data = Map<String, dynamic>.from(response as Map<dynamic, dynamic>);

      Logger.debug('$_logTag: Report submitted successfully');
      return ModerationReport.fromJson(data);
    } on PostgrestException catch (e) {
      Logger.error(
        '$_logTag: Failed to submit report for target=$target targetId=$targetId',
        e,
      );
      throw ModerationServiceException(
        'Failed to submit report: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error submitting report for target=$target targetId=$targetId',
        e,
      );
      throw ModerationServiceException('Failed to submit report', cause: e);
    }
  }

  /// Check and bump cooldown via `check_and_bump_cooldown` RPC
  Future<CooldownResult> checkAndBumpCooldown(
    String key, {
    required int windowSeconds,
    required int limitCount,
  }) async {
    try {
      Logger.debug(
        '$_logTag: Checking cooldown for key=$key windowSeconds=$windowSeconds limitCount=$limitCount',
      );

      final response = await _supabase.rpc(
        'check_and_bump_cooldown',
        params: {
          'p_key': key,
          'p_window_seconds': windowSeconds,
          'p_limit_count': limitCount,
        },
      );

      // RPC returns a table, so we get the first row
      final rows = response as List;
      if (rows.isEmpty) {
        throw ModerationServiceException('Cooldown check returned no results');
      }

      final data = Map<String, dynamic>.from(rows[0] as Map<dynamic, dynamic>);

      Logger.debug(
        '$_logTag: Cooldown check completed - allowed=${data['allowed']} remaining=${data['remaining']}',
      );

      return CooldownResult.fromJson(data);
    } on PostgrestException catch (e) {
      Logger.error('$_logTag: Failed to check cooldown for key=$key', e);
      throw ModerationServiceException(
        'Failed to check cooldown: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error checking cooldown for key=$key',
        e,
      );
      throw ModerationServiceException('Failed to check cooldown', cause: e);
    }
  }

  /// Check if content hits blocklist via `content_hits_blocklist` RPC
  Future<int> contentHitsBlocklist(String text, {String locale = 'any'}) async {
    try {
      Logger.debug(
        '$_logTag: Checking blocklist for text length=${text.length} locale=$locale',
      );

      final response = await _supabase.rpc(
        'content_hits_blocklist',
        params: {'p_text': text, 'p_locale': locale},
      );

      final hits = response as int;

      Logger.debug('$_logTag: Blocklist check completed - hits=$hits');
      return hits;
    } on PostgrestException catch (e) {
      Logger.error('$_logTag: Failed to check blocklist for text', e);
      throw ModerationServiceException(
        'Failed to check blocklist: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error('$_logTag: Unexpected error checking blocklist', e);
      throw ModerationServiceException('Failed to check blocklist', cause: e);
    }
  }

  /// Check if user is frozen via `is_user_frozen` RPC
  Future<bool> isUserFrozen(String userId) async {
    try {
      Logger.debug('$_logTag: Checking if user is frozen userId=$userId');

      final response = await _supabase.rpc(
        'is_user_frozen',
        params: {'p_user_id': userId},
      );

      final frozen = response as bool;

      Logger.debug('$_logTag: User frozen check completed - frozen=$frozen');
      return frozen;
    } on PostgrestException catch (e) {
      Logger.error(
        '$_logTag: Failed to check if user is frozen userId=$userId',
        e,
      );
      throw ModerationServiceException(
        'Failed to check user frozen status: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error checking user frozen status userId=$userId',
        e,
      );
      throw ModerationServiceException(
        'Failed to check user frozen status',
        cause: e,
      );
    }
  }

  /// Check if user is shadowbanned via `is_user_shadowbanned` RPC
  Future<bool> isUserShadowbanned(String userId) async {
    try {
      Logger.debug('$_logTag: Checking if user is shadowbanned userId=$userId');

      final response = await _supabase.rpc(
        'is_user_shadowbanned',
        params: {'p_user_id': userId},
      );

      final shadowbanned = response as bool;

      Logger.debug(
        '$_logTag: User shadowban check completed - shadowbanned=$shadowbanned',
      );
      return shadowbanned;
    } on PostgrestException catch (e) {
      Logger.error(
        '$_logTag: Failed to check if user is shadowbanned userId=$userId',
        e,
      );
      throw ModerationServiceException(
        'Failed to check user shadowban status: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error checking user shadowban status userId=$userId',
        e,
      );
      throw ModerationServiceException(
        'Failed to check user shadowban status',
        cause: e,
      );
    }
  }

  /// Check if profile is frozen via `is_profile_frozen` RPC
  Future<bool> isProfileFrozen(String profileId) async {
    try {
      Logger.debug(
        '$_logTag: Checking if profile is frozen profileId=$profileId',
      );

      final response = await _supabase.rpc(
        'is_profile_frozen',
        params: {'p_profile_id': profileId},
      );

      final frozen = response as bool;

      Logger.debug('$_logTag: Profile frozen check completed - frozen=$frozen');
      return frozen;
    } on PostgrestException catch (e) {
      Logger.error(
        '$_logTag: Failed to check if profile is frozen profileId=$profileId',
        e,
      );
      throw ModerationServiceException(
        'Failed to check profile frozen status: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error checking profile frozen status profileId=$profileId',
        e,
      );
      throw ModerationServiceException(
        'Failed to check profile frozen status',
        cause: e,
      );
    }
  }

  /// Check if content is takedown via `is_takedown` RPC
  Future<bool> isContentTakedown(ModTarget target, String targetId) async {
    try {
      Logger.debug(
        '$_logTag: Checking if content is takedown target=$target targetId=$targetId',
      );

      final response = await _supabase.rpc(
        'is_takedown',
        params: {
          'p_target_type': target.toPostgresString(),
          'p_target_id': targetId,
        },
      );

      final takedown = response as bool;

      Logger.debug('$_logTag: Takedown check completed - takedown=$takedown');
      return takedown;
    } on PostgrestException catch (e) {
      Logger.error(
        '$_logTag: Failed to check if content is takedown target=$target targetId=$targetId',
        e,
      );
      throw ModerationServiceException(
        'Failed to check takedown status: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error checking takedown status target=$target targetId=$targetId',
        e,
      );
      throw ModerationServiceException(
        'Failed to check takedown status',
        cause: e,
      );
    }
  }

  // =============================================================================
  // ADMIN-ONLY METHODS
  // =============================================================================

  /// Admin: Resolve a report via `admin_resolve_report` RPC
  Future<ModerationReport> adminResolveReport({
    required String reportId,
    required ReportStatus status,
    String? resolution,
    String? duplicateOf,
  }) async {
    try {
      Logger.debug(
        '$_logTag: Admin resolving report reportId=$reportId status=$status',
      );

      final response = await _supabase.rpc(
        'admin_resolve_report',
        params: {
          'p_report_id': reportId,
          'p_status': status.toPostgresString(),
          if (resolution != null) 'p_resolution': resolution,
          if (duplicateOf != null) 'p_duplicate_of': duplicateOf,
        },
      );

      final data = Map<String, dynamic>.from(response as Map<dynamic, dynamic>);

      Logger.debug('$_logTag: Report resolved successfully');
      return ModerationReport.fromJson(data);
    } on PostgrestException catch (e) {
      Logger.error('$_logTag: Failed to resolve report reportId=$reportId', e);
      throw ModerationServiceException(
        'Failed to resolve report: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error resolving report reportId=$reportId',
        e,
      );
      throw ModerationServiceException('Failed to resolve report', cause: e);
    }
  }

  /// Admin: Take moderation action via `admin_take_action` RPC
  Future<ModerationActionModel> adminTakeAction({
    required ModAction action,
    required ModTarget targetType,
    required String targetId,
    String? targetUserId,
    String? reason,
    DateTime? expiresAt,
    Map<String, dynamic>? meta,
  }) async {
    try {
      Logger.debug(
        '$_logTag: Admin taking action action=$action targetType=$targetType targetId=$targetId',
      );

      final response = await _supabase.rpc(
        'admin_take_action',
        params: {
          'p_action': action.toPostgresString(),
          'p_target_type': targetType.toPostgresString(),
          'p_target_id': targetId,
          if (targetUserId != null) 'p_target_user_id': targetUserId,
          if (reason != null) 'p_reason': reason,
          if (expiresAt != null) 'p_expires_at': expiresAt.toIso8601String(),
          if (meta != null) 'p_meta': meta,
        },
      );

      final data = Map<String, dynamic>.from(response as Map<dynamic, dynamic>);

      Logger.debug('$_logTag: Action taken successfully');
      return ModerationActionModel.fromJson(data);
    } on PostgrestException catch (e) {
      Logger.error(
        '$_logTag: Failed to take action action=$action targetType=$targetType targetId=$targetId',
        e,
      );
      throw ModerationServiceException(
        'Failed to take action: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error taking action action=$action targetType=$targetType targetId=$targetId',
        e,
      );
      throw ModerationServiceException('Failed to take action', cause: e);
    }
  }

  /// Admin: Fetch open moderation queue from `v_mod_queue_open` view
  Future<List<ModerationReportSummary>> fetchOpenModQueue() async {
    try {
      Logger.debug('$_logTag: Fetching open moderation queue');

      final response = await _supabase
          .from('v_mod_queue_open')
          .select()
          .order('created_at', ascending: false);

      final rows = (response as List)
          .map(
            (dynamic item) =>
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .map(ModerationReportSummary.fromJson)
          .toList();

      Logger.debug(
        '$_logTag: Fetched ${rows.length} reports from moderation queue',
      );
      return rows;
    } on PostgrestException catch (e) {
      Logger.error('$_logTag: Failed to fetch open moderation queue', e);
      throw ModerationServiceException(
        'Failed to fetch moderation queue: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error fetching open moderation queue',
        e,
      );
      throw ModerationServiceException(
        'Failed to fetch moderation queue',
        cause: e,
      );
    }
  }

  /// Admin: Fetch safety overview from `v_safety_overview` view
  Future<SafetyOverview> fetchSafetyOverview() async {
    try {
      Logger.debug('$_logTag: Fetching safety overview');

      final response = await _supabase
          .from('v_safety_overview')
          .select()
          .limit(1)
          .maybeSingle();

      if (response == null) {
        throw ModerationServiceException('Safety overview not found');
      }

      final data = Map<String, dynamic>.from(response as Map<dynamic, dynamic>);

      Logger.debug('$_logTag: Safety overview fetched successfully');
      return SafetyOverview.fromJson(data);
    } on PostgrestException catch (e) {
      Logger.error('$_logTag: Failed to fetch safety overview', e);
      throw ModerationServiceException(
        'Failed to fetch safety overview: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error('$_logTag: Unexpected error fetching safety overview', e);
      throw ModerationServiceException(
        'Failed to fetch safety overview',
        cause: e,
      );
    }
  }

  /// Admin: Log audit event via `audit_log` RPC (SECURITY DEFINER function)
  Future<String> auditLog({
    required String action,
    ModTarget targetType = ModTarget.other,
    String? targetId,
    String? targetUserId,
    Map<String, dynamic>? meta,
  }) async {
    try {
      Logger.debug(
        '$_logTag: Logging audit event action=$action targetType=$targetType targetId=$targetId',
      );

      final response = await _supabase.rpc(
        'audit_log',
        params: {
          'p_action': action,
          'p_target_type': targetType.toPostgresString(),
          if (targetId != null) 'p_target_id': targetId,
          if (targetUserId != null) 'p_target_user_id': targetUserId,
          if (meta != null) 'p_meta': meta,
        },
      );

      final auditId = response as String;

      Logger.debug(
        '$_logTag: Audit event logged successfully auditId=$auditId',
      );
      return auditId;
    } on PostgrestException catch (e) {
      Logger.error('$_logTag: Failed to log audit event action=$action', e);
      throw ModerationServiceException(
        'Failed to log audit event: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error(
        '$_logTag: Unexpected error logging audit event action=$action',
        e,
      );
      throw ModerationServiceException('Failed to log audit event', cause: e);
    }
  }

  /// Admin: Fetch audit events from `public.audit_events` table
  Future<List<AuditEvent>> fetchAuditEvents({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      Logger.debug(
        '$_logTag: Fetching audit events limit=$limit offset=$offset',
      );

      final response = await _supabase
          .from('audit_events')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final rows = (response as List)
          .map(
            (dynamic item) =>
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .map(AuditEvent.fromJson)
          .toList();

      Logger.debug('$_logTag: Fetched ${rows.length} audit events');
      return rows;
    } on PostgrestException catch (e) {
      Logger.error('$_logTag: Failed to fetch audit events', e);
      throw ModerationServiceException(
        'Failed to fetch audit events: ${e.message}',
        cause: e,
      );
    } catch (e) {
      Logger.error('$_logTag: Unexpected error fetching audit events', e);
      throw ModerationServiceException(
        'Failed to fetch audit events',
        cause: e,
      );
    }
  }
}

// =============================================================================
// RIVERPOD PROVIDER
// =============================================================================

/// Provides an instance of [ModerationService] backed by the global Supabase client
final moderationServiceProvider = Provider<ModerationService>((ref) {
  final client = Supabase.instance.client;
  return ModerationService(supabase: client);
});
