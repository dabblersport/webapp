import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/utils/logger.dart';

/// Service for managing GDPR-compliant data retention policies
class DataRetentionService {
  final SupabaseClient _supabase;
  static const String _logTag = 'DataRetentionService';

  DataRetentionService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// Configure user data retention preferences
  Future<void> configureRetentionPolicy({
    required String userId,
    required Map<String, Duration> retentionPolicies,
    bool enableAutoCleanup = true,
    Duration? gracePeriod,
  }) async {
    try {
      Logger.info('$_logTag: Configuring retention policy for user: $userId');

      await _supabase.from('user_retention_policies').upsert({
        'user_id': userId,
        'policies': retentionPolicies.map(
          (key, value) => MapEntry(key, value.inDays),
        ),
        'auto_cleanup_enabled': enableAutoCleanup,
        'grace_period_days': gracePeriod?.inDays ?? 30,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Schedule cleanup tasks if enabled
      if (enableAutoCleanup) {
        await _scheduleCleanupTasks(userId, retentionPolicies);
      }

      Logger.info('$_logTag: Retention policy configured for user: $userId');
    } catch (e) {
      Logger.error('$_logTag: Error configuring retention policy', e);
      throw DataRetentionException('Failed to configure retention policy: $e');
    }
  }

  /// Get current retention policies for a user
  Future<UserRetentionPolicy?> getUserRetentionPolicy(String userId) async {
    try {
      final response = await _supabase
          .from('user_retention_policies')
          .select()
          .eq('user_id', userId)
          .single();

      return UserRetentionPolicy.fromJson(response);
    } catch (e) {
      Logger.warning(
        '$_logTag: Could not fetch retention policy for user: $userId',
        e,
      );
      return null;
    }
  }

  /// Schedule automatic data cleanup based on retention policies
  Future<void> _scheduleCleanupTasks(
    String userId,
    Map<String, Duration> policies,
  ) async {
    try {
      // Clear existing scheduled tasks
      await _supabase
          .from('scheduled_cleanup_tasks')
          .delete()
          .eq('user_id', userId);

      // Schedule new cleanup tasks
      for (final entry in policies.entries) {
        final dataType = entry.key;
        final retentionPeriod = entry.value;
        final cleanupDate = DateTime.now().add(retentionPeriod);

        await _supabase.from('scheduled_cleanup_tasks').insert({
          'user_id': userId,
          'data_type': dataType,
          'scheduled_cleanup_date': cleanupDate.toIso8601String(),
          'retention_period_days': retentionPeriod.inDays,
          'status': 'scheduled',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      Logger.info('$_logTag: Cleanup tasks scheduled for user: $userId');
    } catch (e) {
      Logger.error('$_logTag: Error scheduling cleanup tasks', e);
    }
  }

  /// Process scheduled data cleanup tasks
  Future<DataCleanupResult> processScheduledCleanups({
    int batchSize = 100,
    List<String>? dataTypes,
  }) async {
    try {
      Logger.info('$_logTag: Processing scheduled data cleanups');

      final result = DataCleanupResult();

      // Get due cleanup tasks
      var query = _supabase
          .from('scheduled_cleanup_tasks')
          .select()
          .eq('status', 'scheduled')
          .lte('scheduled_cleanup_date', DateTime.now().toIso8601String())
          .limit(batchSize);

      final tasks = await query;

      // Filter by data types if specified
      final filteredTasks = dataTypes != null
          ? tasks
                .where((task) => dataTypes.contains(task['data_type']))
                .toList()
          : tasks;

      for (final task in filteredTasks) {
        await _processCleanupTask(task, result);
      }

      Logger.info(
        '$_logTag: Processed ${result.totalTasksProcessed} cleanup tasks',
      );
      return result;
    } catch (e) {
      Logger.error('$_logTag: Error processing scheduled cleanups', e);
      throw DataRetentionException('Failed to process scheduled cleanups: $e');
    }
  }

  /// Process individual cleanup task
  Future<void> _processCleanupTask(
    Map<String, dynamic> task,
    DataCleanupResult result,
  ) async {
    try {
      final userId = task['user_id'] as String;
      final dataType = task['data_type'] as String;
      final taskId = task['id'] as String;

      result.totalTasksProcessed++;

      // Check if user has grace period active
      final gracePeriodActive = await _checkGracePeriod(userId, dataType);
      if (gracePeriodActive) {
        await _postponeCleanup(taskId, Duration(days: 7));
        result.tasksPostponed++;
        return;
      }

      // Send notification before cleanup
      await _sendCleanupNotification(userId, dataType, task);

      // Perform the actual data cleanup
      final deletedRecords = await _performDataCleanup(userId, dataType);
      result.recordsDeleted += deletedRecords;

      // Log the cleanup action
      await _logCleanupAction(userId, dataType, deletedRecords);

      // Mark task as completed
      await _supabase
          .from('scheduled_cleanup_tasks')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'records_deleted': deletedRecords,
          })
          .eq('id', taskId);

      result.tasksCompleted++;
      Logger.info(
        '$_logTag: Cleanup completed for user $userId, dataType $dataType: $deletedRecords records',
      );
    } catch (e) {
      Logger.error('$_logTag: Error processing cleanup task: ${task['id']}', e);
      result.tasksFailed++;

      // Mark task as failed
      await _supabase
          .from('scheduled_cleanup_tasks')
          .update({
            'status': 'failed',
            'error_message': e.toString(),
            'failed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', task['id']);
    }
  }

  /// Check if user has active grace period for data type
  Future<bool> _checkGracePeriod(String userId, String dataType) async {
    try {
      final response = await _supabase
          .from('grace_period_requests')
          .select()
          .eq('user_id', userId)
          .eq('data_type', dataType)
          .eq('status', 'active')
          .single();

      final expiresAt = DateTime.parse(response['expires_at']);
      return DateTime.now().isBefore(expiresAt);
    } catch (e) {
      return false; // No active grace period
    }
  }

  /// Postpone cleanup task
  Future<void> _postponeCleanup(String taskId, Duration delay) async {
    final newCleanupDate = DateTime.now().add(delay);

    await _supabase
        .from('scheduled_cleanup_tasks')
        .update({
          'scheduled_cleanup_date': newCleanupDate.toIso8601String(),
          'postponed_count': 1, // Could track multiple postponements
        })
        .eq('id', taskId);
  }

  /// Send notification before data cleanup
  Future<void> _sendCleanupNotification(
    String userId,
    String dataType,
    Map<String, dynamic> task,
  ) async {
    try {
      // Get user email from auth
      final user = _supabase.auth.currentUser;
      final userEmail = user?.email ?? 'unknown@email.com';

      // Get display name from profiles
      final userResponse = await _supabase
          .from(SupabaseConfig.usersTable)
          .select('display_name')
          .eq('user_id', userId)
          .single();

      final userName = userResponse['display_name'];

      // This would integrate with your email service (e.g., SendGrid, AWS SES, etc.)
      Logger.info(
        '$_logTag: Would send cleanup notification to $userEmail for $dataType data',
      );

      // Placeholder for actual email sending
    } catch (e) {
      Logger.warning('$_logTag: Could not send cleanup notification', e);
    }
  }

  /// Perform actual data cleanup for specific data type
  Future<int> _performDataCleanup(String userId, String dataType) async {
    int deletedRecords = 0;

    switch (dataType) {
      case 'profile_data':
        deletedRecords += await _cleanupProfileData(userId);
        break;
      case 'game_history':
        deletedRecords += await _cleanupGameHistory(userId);
        break;
      case 'messages':
        deletedRecords += await _cleanupMessages(userId);
        break;
      case 'audit_logs':
        deletedRecords += await _cleanupAuditLogs(userId);
        break;
      case 'login_history':
        deletedRecords += await _cleanupLoginHistory(userId);
        break;
      case 'media_files':
        deletedRecords += await _cleanupMediaFiles(userId);
        break;
      case 'location_data':
        deletedRecords += await _cleanupLocationData(userId);
        break;
      case 'analytics_data':
        deletedRecords += await _cleanupAnalyticsData(userId);
        break;
      default:
        Logger.warning('$_logTag: Unknown data type for cleanup: $dataType');
    }

    return deletedRecords;
  }

  /// Cleanup methods for specific data types
  Future<int> _cleanupProfileData(String userId) async {
    // Delete non-essential profile data while keeping core account info
    int deleted = 0;

    try {
      // Delete optional profile fields
      await _supabase
          .from(SupabaseConfig.usersTable) // 'profiles' table
          .update({'bio': null, 'avatar_url': null})
          .eq('user_id', userId); // Match by user_id FK

      deleted = 1; // One profile record updated
    } catch (e) {
      Logger.warning('$_logTag: Error cleaning up profile data', e);
    }

    return deleted;
  }

  Future<int> _cleanupGameHistory(String userId) async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: 365 * 2),
      ); // Keep 2 years

      final result = await _supabase
          .from('games')
          .delete()
          .eq('creator_id', userId)
          .lt('created_at', cutoffDate.toIso8601String());

      return result.length;
    } catch (e) {
      Logger.warning('$_logTag: Error cleaning up game history', e);
      return 0;
    }
  }

  Future<int> _cleanupMessages(String userId) async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: 365),
      ); // Keep 1 year

      final result = await _supabase
          .from('messages')
          .delete()
          .eq('sender_id', userId)
          .lt('created_at', cutoffDate.toIso8601String());

      return result.length;
    } catch (e) {
      Logger.warning('$_logTag: Error cleaning up messages', e);
      return 0;
    }
  }

  Future<int> _cleanupAuditLogs(String userId) async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: 365 * 2),
      ); // Keep 2 years for security

      final result = await _supabase
          .from('audit_logs')
          .delete()
          .eq('user_id', userId)
          .lt('created_at', cutoffDate.toIso8601String());

      return result.length;
    } catch (e) {
      Logger.warning('$_logTag: Error cleaning up audit logs', e);
      return 0;
    }
  }

  Future<int> _cleanupLoginHistory(String userId) async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: 180),
      ); // Keep 6 months

      final result = await _supabase
          .from('login_history')
          .delete()
          .eq('user_id', userId)
          .lt('login_at', cutoffDate.toIso8601String());

      return result.length;
    } catch (e) {
      Logger.warning('$_logTag: Error cleaning up login history', e);
      return 0;
    }
  }

  Future<int> _cleanupMediaFiles(String userId) async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: 365),
      ); // Keep 1 year

      // First get the files to delete from storage
      final mediaFiles = await _supabase
          .from('user_media')
          .select('file_path')
          .eq('user_id', userId)
          .lt('created_at', cutoffDate.toIso8601String());

      for (final file in mediaFiles) {
        Logger.info('$_logTag: Would delete media file: ${file['file_path']}');
      }

      // Delete from database
      final result = await _supabase
          .from('user_media')
          .delete()
          .eq('user_id', userId)
          .lt('created_at', cutoffDate.toIso8601String());

      return result.length;
    } catch (e) {
      Logger.warning('$_logTag: Error cleaning up media files', e);
      return 0;
    }
  }

  Future<int> _cleanupLocationData(String userId) async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: 90),
      ); // Keep 3 months

      final result = await _supabase
          .from('location_data')
          .delete()
          .eq('user_id', userId)
          .lt('recorded_at', cutoffDate.toIso8601String());

      return result.length;
    } catch (e) {
      Logger.warning('$_logTag: Error cleaning up location data', e);
      return 0;
    }
  }

  Future<int> _cleanupAnalyticsData(String userId) async {
    try {
      final cutoffDate = DateTime.now().subtract(
        Duration(days: 365),
      ); // Keep 1 year

      final result = await _supabase
          .from('user_analytics')
          .delete()
          .eq('user_id', userId)
          .lt('recorded_at', cutoffDate.toIso8601String());

      return result.length;
    } catch (e) {
      Logger.warning('$_logTag: Error cleaning up analytics data', e);
      return 0;
    }
  }

  /// Log cleanup action for audit purposes
  Future<void> _logCleanupAction(
    String userId,
    String dataType,
    int recordsDeleted,
  ) async {
    try {
      await _supabase.from('data_cleanup_audit').insert({
        'user_id': userId,
        'data_type': dataType,
        'records_deleted': recordsDeleted,
        'cleanup_reason': 'automated_retention_policy',
        'cleaned_up_at': DateTime.now().toIso8601String(),
        'legal_basis': 'GDPR Article 5(1)(e) - storage limitation principle',
      });
    } catch (e) {
      Logger.warning('$_logTag: Could not log cleanup action', e);
    }
  }

  /// Request grace period before data deletion
  Future<void> requestGracePeriod({
    required String userId,
    required String dataType,
    required Duration gracePeriod,
    String? reason,
  }) async {
    try {
      await _supabase.from('grace_period_requests').insert({
        'user_id': userId,
        'data_type': dataType,
        'requested_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(gracePeriod).toIso8601String(),
        'reason': reason ?? 'User requested grace period',
        'status': 'active',
      });

      Logger.info(
        '$_logTag: Grace period requested for user $userId, dataType $dataType',
      );
    } catch (e) {
      Logger.error('$_logTag: Error requesting grace period', e);
      throw DataRetentionException('Failed to request grace period: $e');
    }
  }

  /// Get default retention policies
  static Map<String, Duration> getDefaultRetentionPolicies() {
    return {
      'profile_data': Duration(days: 365 * 7), // 7 years
      'game_history': Duration(days: 365 * 3), // 3 years
      'messages': Duration(days: 365), // 1 year
      'audit_logs': Duration(days: 365 * 2), // 2 years (security requirement)
      'login_history': Duration(days: 180), // 6 months
      'media_files': Duration(days: 365), // 1 year
      'location_data': Duration(days: 90), // 3 months
      'analytics_data': Duration(days: 365), // 1 year
    };
  }

  /// Get upcoming cleanup tasks for a user
  Future<List<Map<String, dynamic>>> getUpcomingCleanups(String userId) async {
    try {
      final response = await _supabase
          .from('scheduled_cleanup_tasks')
          .select()
          .eq('user_id', userId)
          .eq('status', 'scheduled')
          .gte('scheduled_cleanup_date', DateTime.now().toIso8601String())
          .order('scheduled_cleanup_date');

      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      Logger.warning('$_logTag: Could not fetch upcoming cleanups', e);
      return [];
    }
  }
}

/// User retention policy model
class UserRetentionPolicy {
  final String userId;
  final Map<String, Duration> policies;
  final bool autoCleanupEnabled;
  final Duration gracePeriod;
  final DateTime updatedAt;

  UserRetentionPolicy({
    required this.userId,
    required this.policies,
    required this.autoCleanupEnabled,
    required this.gracePeriod,
    required this.updatedAt,
  });

  factory UserRetentionPolicy.fromJson(Map<String, dynamic> json) {
    final policiesMap = (json['policies'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, Duration(days: value as int)),
    );

    return UserRetentionPolicy(
      userId: json['user_id'],
      policies: policiesMap,
      autoCleanupEnabled: json['auto_cleanup_enabled'] ?? true,
      gracePeriod: Duration(days: json['grace_period_days'] ?? 30),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'policies': policies.map((key, value) => MapEntry(key, value.inDays)),
      'auto_cleanup_enabled': autoCleanupEnabled,
      'grace_period_days': gracePeriod.inDays,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Data cleanup result summary
class DataCleanupResult {
  int totalTasksProcessed = 0;
  int tasksCompleted = 0;
  int tasksFailed = 0;
  int tasksPostponed = 0;
  int recordsDeleted = 0;

  Map<String, dynamic> toJson() {
    return {
      'total_tasks_processed': totalTasksProcessed,
      'tasks_completed': tasksCompleted,
      'tasks_failed': tasksFailed,
      'tasks_postponed': tasksPostponed,
      'records_deleted': recordsDeleted,
    };
  }
}

/// Custom exception for data retention errors
class DataRetentionException implements Exception {
  final String message;
  final String? code;

  DataRetentionException(this.message, {this.code});

  @override
  String toString() =>
      'DataRetentionException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Provider for data retention service
final dataRetentionServiceProvider = Provider<DataRetentionService>((ref) {
  return DataRetentionService();
});
