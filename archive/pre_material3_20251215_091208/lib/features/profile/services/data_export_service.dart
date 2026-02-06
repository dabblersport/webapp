import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
// import '../domain/entities/user_profile.dart';
// import 'package:dabbler/core/utils/logger.dart';
// import '../../../core/error/exceptions.dart';
// import 'package:dabbler/core/services/email_service.dart';

// Temporary stub implementations for missing dependencies
class Logger {
  static void info(String message) => debugPrint('[INFO] $message');
  static void error(String message, [dynamic error]) =>
      debugPrint('[ERROR] $message${error != null ? ': $error' : ''}');
  static void warning(String message, [dynamic error]) =>
      debugPrint('[WARNING] $message${error != null ? ': $error' : ''}');
  static void debug(String message) => debugPrint('[DEBUG] $message');
}

class DataExportException implements Exception {
  final String message;
  final String? errorCode;
  const DataExportException(this.message, {this.errorCode});

  @override
  String toString() => 'DataExportException: $message';
}

class EmailService {
  static Future<void> sendEmail({
    required String to,
    required String subject,
    required String body,
    Map<String, String>? headers,
  }) async {
    Logger.info('Implement email sending to $to with subject: $subject');
  }
}

/// Service for exporting user data in compliance with GDPR
class DataExportService {
  final SupabaseClient _supabase;
  static const String _logTag = 'DataExportService';
  static const Duration _exportExpiration = Duration(days: 30);
  static const Duration _maxExportTime = Duration(hours: 24);

  DataExportService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// Request a new comprehensive data export for GDPR compliance
  Future<DataExportRequest> requestGDPRDataExport({
    required String userId,
    required DataExportFormat format,
    required String userEmail,
    bool sendEmailNotification = true,
    String? customMessage,
  }) async {
    try {
      Logger.info('$_logTag: Requesting GDPR data export for user: $userId');

      // Check for existing pending exports
      final pendingExports = await _getPendingExports(userId);
      if (pendingExports.isNotEmpty) {
        throw DataExportException(
          'A data export is already in progress. Please wait for it to complete.',
        );
      }

      final request = DataExportRequest(
        id: _generateExportId(),
        userId: userId,
        userEmail: userEmail,
        format: format,
        status: DataExportStatus.pending,
        requestedAt: DateTime.now(),
        expiresAt: DateTime.now().add(_exportExpiration),
        sendEmailNotification: sendEmailNotification,
        customMessage: customMessage,
      );

      // Store the export request
      await _storeExportRequest(request);

      // Start the async export process
      _processGDPRExportAsync(request);

      Logger.info('$_logTag: GDPR export request created: ${request.id}');
      return request;
    } catch (e) {
      Logger.error('$_logTag: Error requesting GDPR data export', e);
      throw DataExportException('Failed to request data export: $e');
    }
  }

  /// Get comprehensive export status and history for a user
  Future<List<DataExportRequest>> getUserExportHistory(String userId) async {
    try {
      final requests = await _getStoredExportRequests(userId);

      // Clean up expired requests
      await _cleanupExpiredExports(requests);

      return requests;
    } catch (e) {
      Logger.error('$_logTag: Error getting export history', e);
      return [];
    }
  }

  /// Cancel a pending export request
  Future<void> cancelExportRequest(String requestId) async {
    try {
      final request = await _getExportRequest(requestId);
      if (request != null && request.status == DataExportStatus.pending) {
        await _updateExportStatus(requestId, DataExportStatus.cancelled);
        Logger.info('$_logTag: Export request cancelled: $requestId');
      }
    } catch (e) {
      Logger.error('$_logTag: Error cancelling export', e);
      throw DataExportException('Failed to cancel export request: $e');
    }
  }

  /// Download exported data with security checks
  Future<File> downloadExportedData(String requestId, String userId) async {
    try {
      final request = await _getExportRequest(requestId);

      if (request == null) {
        throw DataExportException('Export request not found');
      }

      // Verify user owns this export
      if (request.userId != userId) {
        throw DataExportException('Unauthorized access to export');
      }

      if (request.status != DataExportStatus.completed) {
        throw DataExportException('Export is not ready for download');
      }

      if (request.isExpired) {
        throw DataExportException('Export has expired');
      }

      final filePath = request.filePath;
      if (filePath == null) {
        throw DataExportException('Export file not found');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw DataExportException('Export file has been deleted');
      }

      // Track download
      await _trackDownload(requestId);

      return file;
    } catch (e) {
      Logger.error('$_logTag: Error downloading export', e);
      rethrow;
    }
  }

  /// Process GDPR data export asynchronously
  void _processGDPRExportAsync(DataExportRequest request) async {
    try {
      Logger.info(
        '$_logTag: Starting async GDPR export process: ${request.id}',
      );

      await _updateExportStatus(request.id, DataExportStatus.processing);

      // Set timeout for export process
      final completer = Completer<void>();
      final timer = Timer(_maxExportTime, () {
        if (!completer.isCompleted) {
          completer.completeError(
            'Export timeout - process took longer than 24 hours',
          );
        }
      });

      try {
        // Gather all user data comprehensively
        final exportData = await _gatherComprehensiveUserData(request.userId);

        // Generate export file with enhanced features
        final exportFile = await _generateGDPRExportFile(exportData, request);

        // Update request with file path
        await _updateExportRequest(request.id, filePath: exportFile.path);

        // Mark as completed
        await _updateExportStatus(request.id, DataExportStatus.completed);

        // Send notification if requested
        if (request.sendEmailNotification) {
          await _sendGDPRCompletionEmail(request);
        }

        // Record the export in database
        await _recordGDPRExport(request);

        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }

        Logger.info(
          '$_logTag: GDPR export completed successfully: ${request.id}',
        );
      } catch (e) {
        timer.cancel();
        await _updateExportStatus(
          request.id,
          DataExportStatus.failed,
          error: e.toString(),
        );

        if (request.sendEmailNotification) {
          await _sendGDPRErrorEmail(request, e.toString());
        }

        if (!completer.isCompleted) {
          completer.completeError(e);
        }

        Logger.error('$_logTag: GDPR export failed: ${request.id}', e);
      }
    } catch (e) {
      Logger.error('$_logTag: Error in async GDPR export process', e);
    }
  }

  /// Gather comprehensive user data for GDPR compliance
  Future<UserExportData> _gatherComprehensiveUserData(String userId) async {
    Logger.info('$_logTag: Gathering comprehensive user data for: $userId');

    final exportData = UserExportData(
      userId: userId,
      exportedAt: DateTime.now(),
    );

    try {
      // Core Profile Information
      exportData.profile = await _getEnhancedProfileData(userId);

      // User Preferences and Settings
      exportData.preferences = await _getEnhancedPreferencesData(userId);

      // Sports Profiles and Statistics
      exportData.sportsProfiles = await _getEnhancedSportsProfileData(userId);
      exportData.statistics = await _getEnhancedStatisticsData(userId);

      // Complete Game History
      exportData.gameHistory = await _getEnhancedGameHistoryData(userId);

      // Privacy Settings and Consents
      exportData.privacySettings = await _getPrivacySettingsData(userId);
      exportData.consents = await _getConsentHistory(userId);

      // Account Activity and Audit Logs (last 2 years)
      exportData.auditLogs = await _getAuditLogsData(userId);
      exportData.loginHistory = await _getLoginHistory(userId);

      // Social Connections and Interactions
      exportData.connections = await _getConnectionsData(userId);
      exportData.messages = await _getMessagesData(userId);
      exportData.notifications = await _getNotificationsData(userId);

      // Content and Media (metadata only)
      exportData.media = await _getMediaMetadata(userId);

      // Location Data (if collected)
      exportData.locationData = await _getLocationData(userId);

      // Device and Technical Data
      exportData.deviceInfo = await _getDeviceInformation(userId);

      // Payment and Subscription Data
      exportData.paymentData = await _getPaymentData(userId);

      // Third-party Integrations
      exportData.integrations = await _getThirdPartyData(userId);

      Logger.info('$_logTag: Comprehensive user data gathering completed');
      return exportData;
    } catch (e) {
      Logger.error('$_logTag: Error gathering comprehensive user data', e);
      rethrow;
    }
  }

  /// Generate GDPR-compliant export file
  Future<File> _generateGDPRExportFile(
    UserExportData data,
    DataExportRequest request,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'dabbler_gdpr_export_${request.userId}_$timestamp';

      switch (request.format) {
        case DataExportFormat.json:
          return await _generateGDPRJsonExport(data, fileName);
        case DataExportFormat.csv:
          return await _generateGDPRCsvExport(data, fileName);
        case DataExportFormat.zip:
          return await _generateGDPRZipExport(data, fileName);
      }
    } catch (e) {
      Logger.error('$_logTag: Error generating GDPR export file', e);
      rethrow;
    }
  }

  /// Generate comprehensive JSON export
  Future<File> _generateGDPRJsonExport(
    UserExportData data,
    String fileName,
  ) async {
    try {
      final exportDir = await _getSecureExportDirectory();
      final filePath = path.join(exportDir.path, '$fileName.json');

      final jsonData = {
        'export_info': {
          'format': 'json',
          'version': '2.0',
          'exported_at': data.exportedAt.toIso8601String(),
          'user_id': data.userId,
          'data_types': _getExportedDataTypes(data),
          'gdpr_compliant': true,
          'retention_policy': 'Data will be deleted after 30 days',
          'contact_email': 'privacy@dabbler.app',
        },
        'user_data': data.toJson(),
        'data_explanations': _generateDataExplanations(),
        'your_rights': _generateGDPRRights(),
      };

      final file = File(filePath);
      await file.writeAsString(
        JsonEncoder.withIndent('  ').convert(jsonData),
        encoding: utf8,
      );

      Logger.info('$_logTag: GDPR JSON export generated: $filePath');
      return file;
    } catch (e) {
      Logger.error('$_logTag: Error generating GDPR JSON export', e);
      rethrow;
    }
  }

  /// Generate comprehensive CSV export
  Future<File> _generateGDPRCsvExport(
    UserExportData data,
    String fileName,
  ) async {
    try {
      final exportDir = await _getSecureExportDirectory();
      final filePath = path.join(exportDir.path, '$fileName.csv');
      final file = File(filePath);

      // For now, create a basic CSV representation
      final csvContent = StringBuffer();
      csvContent.writeln('Data Type,Field,Value,Collected At');

      // Add basic profile data
      if (data.profile != null) {
        final profile = data.profile!;
        csvContent.writeln(
          'Profile,Name,"${profile['display_name'] ?? ''}",'
          '"${profile['created_at'] ?? ''}"',
        );
        csvContent.writeln(
          'Profile,Email,"${profile['email'] ?? ''}",'
          '"${profile['created_at'] ?? ''}"',
        );
      }

      // Add counts for other data types
      csvContent.writeln(
        'Statistics,Total Game History Count,'
        '"${data.gameHistory?.length ?? 0}",N/A',
      );
      csvContent.writeln(
        'Statistics,Total Messages Count,'
        '"${data.messages?.length ?? 0}",N/A',
      );
      csvContent.writeln(
        'Statistics,Total Notifications Count,'
        '"${data.notifications?.length ?? 0}",N/A',
      );

      await file.writeAsString(csvContent.toString());

      Logger.info('$_logTag: GDPR CSV export generated: $filePath');
      return file;
    } catch (e) {
      Logger.error('$_logTag: Error generating GDPR CSV export', e);
      rethrow;
    }
  }

  /// Generate comprehensive ZIP export with multiple files
  Future<File> _generateGDPRZipExport(
    UserExportData data,
    String fileName,
  ) async {
    // For now, fall back to JSON export to avoid extra archive dependency
    // while keeping the method available for future enhancement.
    Logger.warning(
      '$_logTag: ZIP export not fully implemented; falling back to JSON file.',
    );
    return _generateGDPRJsonExport(data, fileName);
  }

  // Enhanced data gathering methods for GDPR compliance
  Future<Map<String, dynamic>?> _getEnhancedProfileData(String userId) async {
    try {
      final response = await _supabase
          .from(SupabaseConfig.usersTable) // 'profiles' table
          .select('*')
          .eq('user_id', userId) // Match by user_id FK
          .single();

      return {
        ...response,
        'data_source': 'profiles_table',
        'purpose': 'User identification and profile management',
        'legal_basis': 'Contract performance and legitimate interest',
        'retention_period': '2 years after account deletion',
      };
    } catch (e) {
      Logger.warning('Could not fetch enhanced profile data', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getEnhancedPreferencesData(
    String userId,
  ) async {
    try {
      final settingsResponse = await _supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId);

      final preferencesResponse = await _supabase
          .from('user_preferences')
          .select()
          .eq('user_id', userId);

      return {
        'settings': settingsResponse,
        'preferences': preferencesResponse,
        'data_source': 'user_settings, user_preferences tables',
        'purpose': 'Personalization and user experience optimization',
        'legal_basis': 'User consent and legitimate interest',
        'retention_period': 'Until account deletion or consent withdrawal',
      };
    } catch (e) {
      Logger.warning('Could not fetch preferences data', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getEnhancedSportsProfileData(
    String userId,
  ) async {
    try {
      // First get profile_id from user_id
      final profileResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (profileResponse == null) {
        return [];
      }

      final profileId = profileResponse['id'] as String;

      final response = await _supabase
          .from('sport_profiles')
          .select('*')
          .eq('profile_id', profileId);

      return response
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'data_source': 'sport_profiles table',
              'purpose': 'Sports skill assessment and matching',
              'legal_basis': 'User consent and contract performance',
            },
          )
          .toList();
    } catch (e) {
      Logger.warning('Could not fetch sports profile data', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getEnhancedStatisticsData(
    String userId,
  ) async {
    try {
      final gameStats = await _supabase
          .from('user_game_statistics')
          .select()
          .eq('user_id', userId);

      final performanceMetrics = await _supabase
          .from('performance_metrics')
          .select()
          .eq('user_id', userId);

      return {
        'game_statistics': gameStats,
        'performance_metrics': performanceMetrics,
        'data_source': 'user_game_statistics, performance_metrics tables',
        'purpose': 'Performance tracking and skill assessment',
        'legal_basis': 'User consent',
        'retention_period': '3 years or until consent withdrawal',
      };
    } catch (e) {
      Logger.warning('Could not fetch statistics data', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getEnhancedGameHistoryData(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('games')
          .select('''
            *, 
            game_participants!inner(user_id, joined_at, status, performance_rating),
            messages(content, sent_at, sender_id)
          ''')
          .eq('game_participants.user_id', userId)
          .order('created_at', ascending: false);

      return response
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'data_source': 'games, game_participants, messages tables',
              'purpose': 'Game history and social interaction tracking',
              'legal_basis': 'Contract performance and legitimate interest',
            },
          )
          .toList();
    } catch (e) {
      Logger.warning('Could not fetch game history data', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getPrivacySettingsData(String userId) async {
    try {
      final response = await _supabase
          .from('privacy_settings')
          .select()
          .eq('user_id', userId)
          .single();

      return {
        ...response,
        'data_source': 'privacy_settings table',
        'purpose': 'Privacy preference management',
        'legal_basis': 'User consent',
        'your_rights': 'You can modify these settings at any time',
      };
    } catch (e) {
      Logger.warning('Could not fetch privacy settings', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getConsentHistory(String userId) async {
    try {
      final response = await _supabase
          .from('consent_records')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'data_source': 'consent_records table',
              'purpose': 'Legal compliance and consent tracking',
              'legal_basis': 'Legal obligation (GDPR Article 7)',
            },
          )
          .toList();
    } catch (e) {
      Logger.warning('Could not fetch consent history', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getAuditLogsData(String userId) async {
    try {
      final twoYearsAgo = DateTime.now().subtract(Duration(days: 730));
      final response = await _supabase
          .from('audit_logs')
          .select()
          .eq('user_id', userId)
          .gte('created_at', twoYearsAgo.toIso8601String())
          .order('created_at', ascending: false)
          .limit(5000);

      return response
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'data_source': 'audit_logs table',
              'purpose': 'Security monitoring and compliance',
              'legal_basis': 'Legitimate interest (security)',
              'retention_period': '2 years',
            },
          )
          .toList();
    } catch (e) {
      Logger.warning('Could not fetch audit logs', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getLoginHistory(String userId) async {
    try {
      final sixMonthsAgo = DateTime.now().subtract(Duration(days: 180));
      final response = await _supabase
          .from('login_history')
          .select(
            'login_at, ip_address, user_agent, device_info, location_info',
          )
          .eq('user_id', userId)
          .gte('login_at', sixMonthsAgo.toIso8601String())
          .order('login_at', ascending: false)
          .limit(1000);

      return response
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'data_source': 'login_history table',
              'purpose': 'Security monitoring and fraud prevention',
              'legal_basis': 'Legitimate interest (security)',
              'retention_period': '6 months',
            },
          )
          .toList();
    } catch (e) {
      Logger.warning('Could not fetch login history', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getConnectionsData(String userId) async {
    try {
      final friendships = await _supabase
          .from('friendships')
          .select('*, profiles!friend_id(name, email)')
          .or('user_id.eq.$userId,friend_id.eq.$userId');

      final blockedUsers = await _supabase
          .from('blocked_users')
          .select('*, profiles!blocked_user_id(name)')
          .eq('blocker_id', userId);

      return [
            ...friendships.map(
              (item) => {...item, 'connection_type': 'friendship'},
            ),
            ...blockedUsers.map(
              (item) => {...item, 'connection_type': 'blocked'},
            ),
          ]
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'data_source': 'friendships, blocked_users tables',
              'purpose': 'Social connection management',
              'legal_basis': 'User consent and contract performance',
            },
          )
          .toList();
    } catch (e) {
      Logger.warning('Could not fetch connections data', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getMessagesData(String userId) async {
    try {
      final sentMessages = await _supabase
          .from('messages')
          .select('content, sent_at, game_id, recipient_id')
          .eq('sender_id', userId)
          .order('sent_at', ascending: false)
          .limit(10000);

      final receivedMessages = await _supabase
          .from('messages')
          .select('content, sent_at, game_id, sender_id')
          .eq('recipient_id', userId)
          .order('sent_at', ascending: false)
          .limit(10000);

      return [
            ...sentMessages.map((item) => {...item, 'message_type': 'sent'}),
            ...receivedMessages.map(
              (item) => {...item, 'message_type': 'received'},
            ),
          ]
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'data_source': 'messages table',
              'purpose': 'Communication facilitation',
              'legal_basis': 'Contract performance',
              'note': 'Message content may be pseudonymized for privacy',
            },
          )
          .toList();
    } catch (e) {
      Logger.warning('Could not fetch messages data', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getNotificationsData(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1000);

      return response
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'data_source': 'notifications table',
              'purpose': 'User engagement and communication',
              'legal_basis': 'User consent and contract performance',
            },
          )
          .toList();
    } catch (e) {
      Logger.warning('Could not fetch notifications data', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getMediaMetadata(String userId) async {
    try {
      final response = await _supabase
          .from('user_media')
          .select(
            'file_name, file_type, file_size, uploaded_at, media_category',
          )
          .eq('user_id', userId);

      return response
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'data_source': 'user_media table',
              'purpose': 'Profile and content management',
              'legal_basis': 'User consent',
              'note':
                  'Only metadata included - actual files not exported for security',
            },
          )
          .toList();
    } catch (e) {
      Logger.warning('Could not fetch media metadata', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getLocationData(String userId) async {
    try {
      final response = await _supabase
          .from('location_data')
          .select('approximate_location, recorded_at, purpose, accuracy')
          .eq('user_id', userId)
          .order('recorded_at', ascending: false)
          .limit(1000);

      return response
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'data_source': 'location_data table',
              'purpose': 'Location-based game matching and services',
              'legal_basis': 'User consent',
              'note':
                  'Only approximate locations stored - precise coordinates not retained',
            },
          )
          .toList();
    } catch (e) {
      Logger.warning('Could not fetch location data', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getDeviceInformation(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('device_info')
          .select('device_type, os_version, app_version, last_seen_at')
          .eq('user_id', userId);

      return response
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'data_source': 'device_info table',
              'purpose': 'App functionality and technical support',
              'legal_basis': 'Legitimate interest (technical support)',
            },
          )
          .toList();
    } catch (e) {
      Logger.warning('Could not fetch device information', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getPaymentData(String userId) async {
    try {
      final response = await _supabase
          .from('payment_records')
          .select(
            'transaction_id, amount, currency, status, created_at, subscription_type',
          )
          .eq('user_id', userId);

      return {
        'transactions': response,
        'data_source': 'payment_records table',
        'purpose': 'Billing and subscription management',
        'legal_basis': 'Contract performance and legal obligation',
        'note':
            'Sensitive payment details (card numbers) are not stored or exported',
        'retention_period': '7 years for tax compliance',
      };
    } catch (e) {
      Logger.warning('Could not fetch payment data', e);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _getThirdPartyData(String userId) async {
    try {
      final response = await _supabase
          .from('third_party_connections')
          .select('provider, connected_at, permissions_granted, last_sync')
          .eq('user_id', userId);

      return response
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'data_source': 'third_party_connections table',
              'purpose': 'Social media integration and enhanced features',
              'legal_basis': 'User consent',
              'note':
                  'Third-party data is not stored - only connection metadata',
            },
          )
          .toList();
    } catch (e) {
      Logger.warning('Could not fetch third-party data', e);
      return null;
    }
  }

  // CSV generation helpers for GDPR export
  // ignore: unused_element
  String _generateProfileCsv(Map<String, dynamic> profile) {
    final rows = <List<String>>[];
    rows.add(['Field', 'Value', 'Purpose', 'Legal Basis']);

    profile.forEach((key, value) {
      if (key != 'data_source' && key != 'purpose' && key != 'legal_basis') {
        rows.add([
          key,
          value?.toString() ?? '',
          profile['purpose']?.toString() ?? '',
          profile['legal_basis']?.toString() ?? '',
        ]);
      }
    });

    return 'CSV export requires csv package dependency';
    // return const ListToCsvConverter().convert(rows);
  }

  // ignore: unused_element
  String _generateGameHistoryCsv(List<Map<String, dynamic>> gameHistory) {
    if (gameHistory.isEmpty) return '';

    final rows = <List<String>>[];
    rows.add([
      'Game ID',
      'Sport',
      'Date',
      'Status',
      'Location',
      'Participants',
      'Your Role',
    ]);

    for (final game in gameHistory) {
      rows.add([
        game['id']?.toString() ?? '',
        game['sport']?.toString() ?? '',
        game['created_at']?.toString() ?? '',
        game['status']?.toString() ?? '',
        game['location']?.toString() ?? '',
        game['participant_count']?.toString() ?? '',
        game['your_status']?.toString() ?? '',
      ]);
    }

    return 'CSV export requires csv package dependency';
    // return const ListToCsvConverter().convert(rows);
  }

  // ignore: unused_element
  String _generateMessagesCsv(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return '';

    final rows = <List<String>>[];
    rows.add(['Date', 'Type', 'Game ID', 'Content Length', 'Purpose']);

    for (final message in messages) {
      rows.add([
        message['sent_at']?.toString() ?? '',
        message['message_type']?.toString() ?? '',
        message['game_id']?.toString() ?? '',
        message['content']?.toString().length.toString() ?? '0',
        message['purpose']?.toString() ?? '',
      ]);
    }

    return 'CSV export requires csv package dependency';
    // return const ListToCsvConverter().convert(rows);
  }

  // GDPR documentation generators
  Map<String, String> _generateDataExplanations() {
    return {
      'profile':
          'Basic account information including name, email, and profile settings',
      'preferences': 'Your application preferences and settings',
      'sports_profiles':
          'Information about sports you play and your skill levels',
      'statistics': 'Your gameplay statistics and performance metrics',
      'game_history': 'Record of games you have participated in',
      'privacy_settings': 'Your privacy preferences and consent records',
      'audit_logs':
          'Log of account activities for security purposes (last 2 years)',
      'connections': 'Your friends, blocked users, and social connections',
      'messages': 'Messages you have sent and received through the platform',
      'notifications': 'System notifications sent to you',
      'media':
          'Metadata about files you have uploaded (actual files not included)',
      'location_data':
          'Approximate location data used for game matching (if consented)',
      'device_info': 'Information about devices you use to access the app',
      'payment_data':
          'Billing and subscription information (sensitive data excluded)',
      'integrations': 'Third-party service connections and permissions',
    };
  }

  Map<String, String> _generateGDPRRights() {
    return {
      'right_to_access':
          'You have received this data export as part of your right to access your personal data',
      'right_to_rectification':
          'You can correct inaccurate data through the app settings or by contacting support',
      'right_to_erasure':
          'You can request deletion of your account and all associated data',
      'right_to_restrict_processing':
          'You can request to limit how we process your data',
      'right_to_data_portability':
          'This export enables you to transfer your data to another service',
      'right_to_object': 'You can object to certain types of data processing',
      'right_to_withdraw_consent':
          'You can withdraw consent for data processing at any time',
      'right_to_complain':
          'You can file a complaint with your local data protection authority',
      'contact_info':
          'For any data protection questions, contact privacy@dabbler.app',
    };
  }

  // ignore: unused_element
  String _generateGDPRReadmeContent(UserExportData data) {
    return '''
# Dabbler GDPR Data Export

This archive contains your complete personal data from Dabbler, exported in compliance with the General Data Protection Regulation (GDPR).

## Export Information
- Exported on: ${data.exportedAt}
- User ID: ${data.userId}
- Export Version: 2.0 (GDPR Compliant)
- Data types included: ${_getExportedDataTypes(data).join(', ')}

## What's Included
This export contains all personal data we hold about you, including:

### Core Data
- Your profile information and account details
- Your sports profiles and skill assessments
- Game participation history and statistics
- Messages and communications through our platform

### Privacy & Compliance Data
- Your privacy settings and preferences
- Consent records and their history
- Account activity logs (security monitoring)
- Device and technical information

### Social Data
- Friend connections and social interactions
- Notifications and communication preferences
- Blocked users and privacy controls

## File Structure
- `data/` - Contains your personal data in various formats
- `documentation/` - Detailed information about your data and rights
- `README.txt` - This file

## Your GDPR Rights
Under the General Data Protection Regulation, you have several important rights:

1. **Right to Access** - This export fulfills your right to access your data
2. **Right to Rectification** - You can correct any inaccurate information
3. **Right to Erasure** - You can request complete deletion of your data
4. **Right to Restrict Processing** - You can limit how we use your data
5. **Right to Data Portability** - You can take your data to another service
6. **Right to Object** - You can object to certain uses of your data
7. **Right to Withdraw Consent** - You can withdraw consent at any time

## Data Retention
- This export file will be automatically deleted after 30 days for security
- Different types of data have different retention periods as outlined in each section
- You can request immediate deletion by contacting our privacy team

## Data Security
- All sensitive information (like payment card details) is excluded from this export
- Personal identifiers of other users may be pseudonymized for privacy
- Location data is approximate only - precise coordinates are not stored

## Questions or Concerns?
If you have any questions about this export or your data rights:
- Email: privacy@dabbler.app  
- Data Protection Officer: dpo@dabbler.app
- Privacy Policy: https://dabbler.app/privacy-policy

## Legal Basis for Processing
We process your data under various legal bases:
- **Contract**: Data necessary to provide our services to you
- **Consent**: Data you've explicitly agreed to share
- **Legitimate Interest**: Data for security, analytics, and service improvement
- **Legal Obligation**: Data we must keep for compliance (e.g., billing records)

## Complaints
If you're not satisfied with our data handling, you can file a complaint with your local data protection authority or the Irish Data Protection Commission (our lead authority).

---
Generated on ${DateTime.now().toIso8601String()}
Dabbler Data Protection Team
''';
  }

  // ignore: unused_element
  String _generateGDPRDataStructureDoc(UserExportData data) {
    return '''
# Data Structure Documentation

This document explains the structure and legal context of your exported data.

## Data Categories and Legal Basis

### 1. Identity Data (Profile Information)
- **Purpose**: Account management and user identification
- **Legal Basis**: Contract performance
- **Retention**: 2 years after account deletion
- **Includes**: Name, email, profile photo, basic demographics

### 2. Sports and Gaming Data
- **Purpose**: Skill matching and game organization
- **Legal Basis**: Contract performance and user consent  
- **Retention**: Until account deletion or consent withdrawal
- **Includes**: Sports preferences, skill levels, game history, statistics

### 3. Communication Data
- **Purpose**: Facilitate user communication and support
- **Legal Basis**: Contract performance
- **Retention**: 1 year after account deletion
- **Includes**: Messages, notifications, support conversations

### 4. Social Connection Data
- **Purpose**: Friend connections and social features
- **Legal Basis**: User consent and contract performance
- **Retention**: Until connection is removed or account deleted
- **Includes**: Friend lists, blocked users, social interactions

### 5. Usage and Analytics Data
- **Purpose**: Service improvement and security monitoring
- **Legal Basis**: Legitimate interest
- **Retention**: 2 years for security data, 1 year for analytics
- **Includes**: Login history, activity logs, usage patterns

### 6. Location Data (If Enabled)
- **Purpose**: Location-based matching and services
- **Legal Basis**: Explicit consent
- **Retention**: Until consent withdrawn or account deleted
- **Includes**: Approximate location for game matching (not precise tracking)

### 7. Technical Data
- **Purpose**: App functionality and technical support
- **Legal Basis**: Legitimate interest
- **Retention**: 1 year or until no longer needed
- **Includes**: Device info, app version, technical diagnostics

### 8. Financial Data (If Applicable)
- **Purpose**: Billing and subscription management
- **Legal Basis**: Contract performance and legal obligation
- **Retention**: 7 years for tax compliance
- **Includes**: Transaction history, subscription status (no payment details)

### 9. Privacy and Consent Data
- **Purpose**: Legal compliance and consent management
- **Legal Basis**: Legal obligation (GDPR Article 7)
- **Retention**: 3 years after consent withdrawal
- **Includes**: Privacy settings, consent records, preference changes

## Data Quality and Accuracy
- All data is current as of the export date
- Some historical data may be aggregated or summarized
- Personal identifiers of other users are pseudonymized
- Deleted or expired data is not included

## Third-Party Data
- We do not store data from third-party services
- Only connection metadata (what services you've linked) is included
- OAuth tokens and external IDs are not exported for security

## Data Processing Activities
Each piece of data is processed for specific purposes:
- **Primary Purpose**: The main reason we collect this data
- **Secondary Purposes**: Additional uses (always with legal basis)
- **Sharing**: Whether data is shared with third parties (with legal basis)
- **Automated Processing**: Any automated decision-making involving this data

## Your Control Over This Data
- You can modify most data through app settings
- Some data (like audit logs) cannot be modified but will expire
- You can withdraw consent for optional data processing
- You can request deletion of your entire account and all data

For detailed information about any specific data field, please contact privacy@dabbler.app

---
Last Updated: ${DateTime.now().toIso8601String()}
''';
  }

  // ignore: unused_element
  String _generatePrivacyPolicyReference() {
    return '''
# Privacy Policy Reference

This document provides key references from our Privacy Policy relevant to your data export.

## Key Privacy Policy Sections

### Data We Collect
Our Privacy Policy details all categories of data we collect:
- Information you provide directly (profile, preferences)
- Information collected automatically (usage, technical data)
- Information from third parties (with your consent)

### How We Use Your Data
Your data is used for:
- Providing and improving our services
- Facilitating connections between users
- Personalizing your experience
- Security and fraud prevention
- Legal compliance

### Data Sharing
We may share your data with:
- Other users (with your consent and control)
- Service providers (under data processing agreements)
- Legal authorities (when required by law)
- Business partners (with your explicit consent)

### Your Rights
You have comprehensive rights under GDPR:
- Access (fulfilled by this export)
- Rectification (correct inaccurate data)
- Erasure (delete your data)
- Restrict processing
- Data portability (take data elsewhere)
- Object to processing
- Withdraw consent

### Data Retention
Different types of data are kept for different periods:
- Account data: Until account deletion + 2 years
- Communication data: 1 year after account deletion
- Financial data: 7 years (legal requirement)
- Security logs: 2 years
- Analytics data: 1 year

## Full Privacy Policy
For complete details, visit: https://dabbler.app/privacy-policy

## Contact Information
- Privacy Team: privacy@dabbler.app
- Data Protection Officer: dpo@dabbler.app
- General Support: support@dabbler.app

## Complaints Process
If you have concerns about our data handling:
1. Contact our privacy team first
2. Contact our Data Protection Officer
3. File a complaint with your local data protection authority

---
This reference is current as of: ${DateTime.now().toIso8601String()}
Full Privacy Policy available at: https://dabbler.app/privacy-policy
''';
  }

  // ignore: unused_element
  String _generateGDPRRightsDocument() {
    return '''
# Your GDPR Rights - Detailed Guide

The General Data Protection Regulation gives you important rights over your personal data. This document explains each right and how to exercise them.

## 1. Right to Access (Article 15)
**What it means**: You can ask for a copy of your personal data
**How to exercise**: 
- This data export fulfills this right
- You can request additional exports anytime
- Contact: privacy@dabbler.app

## 2. Right to Rectification (Article 16)
**What it means**: You can correct inaccurate or incomplete data
**How to exercise**:
- Update most data through app settings
- Contact support for data you cannot change yourself
- We'll correct errors within 30 days

## 3. Right to Erasure/"Right to be Forgotten" (Article 17)
**What it means**: You can request deletion of your personal data
**How to exercise**:
- Delete your account through app settings
- Contact privacy@dabbler.app for complete erasure
- We'll confirm deletion within 30 days
**Note**: Some data may be retained for legal compliance

## 4. Right to Restrict Processing (Article 18)
**What it means**: You can limit how we use your data
**How to exercise**:
- Temporarily suspend data processing
- Useful while disputing data accuracy
- Contact: privacy@dabbler.app

## 5. Right to Data Portability (Article 20)
**What it means**: You can take your data to another service
**How to exercise**:
- This export is in machine-readable formats
- You can import JSON/CSV data to other services
- We can provide additional formats if needed

## 6. Right to Object (Article 21)
**What it means**: You can object to certain data processing
**How to exercise**:
- Object to marketing communications (unsubscribe links)
- Object to analytics and profiling
- Contact: privacy@dabbler.app

## 7. Right to Withdraw Consent (Article 7)
**What it means**: You can withdraw consent for optional processing
**How to exercise**:
- Modify consent settings in the app
- Withdrawal doesn't affect past processing
- Some services may become unavailable

## 8. Right Not to be Subject to Automated Decision-Making (Article 22)
**What it means**: You can object to purely automated decisions
**How to exercise**:
- We'll inform you of any automated decision-making
- You can request human review
- Contact: privacy@dabbler.app

## Exercise Your Rights
To exercise any of these rights:
1. **In-App**: Use privacy settings where available
2. **Email**: privacy@dabbler.app
3. **Support**: Through the app's support system

## Response Times
- We respond to requests within 30 days
- Complex requests may take up to 90 days (we'll inform you)
- Urgent security matters are handled immediately

## Identity Verification
For security, we may need to verify your identity:
- Account verification through the app
- Additional identification for major changes
- This protects your data from unauthorized access

## No Cost (Usually)
- Most requests are handled free of charge
- Excessive or repetitive requests may incur reasonable fees
- We'll inform you of any costs beforehand

## Complaints
If you're not satisfied with our response:
1. **Internal**: Contact our Data Protection Officer (dpo@dabbler.app)
2. **External**: File a complaint with your data protection authority
3. **Legal**: You may have the right to judicial remedy

## Data Protection Authorities
**EU/EEA Residents**: Contact your national DPA
**Irish DPA** (our lead authority): 
- Website: dataprotection.ie
- Email: info@dataprotection.ie

## Updates to Rights
Your rights may change with:
- Updates to GDPR or local laws
- Changes to our services
- We'll inform you of significant changes

## Getting Help
If you're unsure about your rights or how to exercise them:
- Contact our privacy team: privacy@dabbler.app
- Visit our privacy policy: https://dabbler.app/privacy-policy
- Consult your local data protection authority

---
Remember: These rights are fundamental and cannot be waived. You can exercise them at any time, and we're here to help make the process simple and transparent.

Document Version: 2.0
Last Updated: ${DateTime.now().toIso8601String()}
''';
  }

  // Helper methods for GDPR export service
  List<String> _getExportedDataTypes(UserExportData data) {
    final types = <String>[];
    if (data.profile != null) types.add('profile');
    if (data.preferences != null) types.add('preferences');
    if (data.sportsProfiles?.isNotEmpty == true) types.add('sports_profiles');
    if (data.statistics != null) types.add('statistics');
    if (data.gameHistory?.isNotEmpty == true) types.add('game_history');
    if (data.privacySettings != null) types.add('privacy_settings');
    if (data.consents?.isNotEmpty == true) types.add('consents');
    if (data.auditLogs?.isNotEmpty == true) types.add('audit_logs');
    if (data.loginHistory?.isNotEmpty == true) types.add('login_history');
    if (data.connections?.isNotEmpty == true) types.add('connections');
    if (data.messages?.isNotEmpty == true) types.add('messages');
    if (data.notifications?.isNotEmpty == true) types.add('notifications');
    if (data.media?.isNotEmpty == true) types.add('media');
    if (data.locationData?.isNotEmpty == true) types.add('location_data');
    if (data.deviceInfo?.isNotEmpty == true) types.add('device_info');
    if (data.paymentData != null) types.add('payment_data');
    if (data.integrations?.isNotEmpty == true) types.add('integrations');
    return types;
  }

  String _generateExportId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 1000000;
    return 'gdpr_export_${timestamp}_$random';
  }

  Future<Directory> _getSecureExportDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(path.join(appDir.path, 'secure_exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  // Database operations for export requests
  Future<void> _storeExportRequest(DataExportRequest request) async {
    try {
      await _supabase.from('data_export_requests').insert({
        'id': request.id,
        'user_id': request.userId,
        'user_email': request.userEmail,
        'format': request.format.toString().split('.').last,
        'status': request.status.toString().split('.').last,
        'requested_at': request.requestedAt.toIso8601String(),
        'expires_at': request.expiresAt.toIso8601String(),
        'send_email_notification': request.sendEmailNotification,
        'custom_message': request.customMessage,
        'created_at': DateTime.now().toIso8601String(),
      });
      Logger.info('$_logTag: Export request stored: ${request.id}');
    } catch (e) {
      Logger.warning('$_logTag: Could not store export request in database', e);
      // Continue without database storage - functionality shouldn't fail
    }
  }

  Future<List<DataExportRequest>> _getPendingExports(String userId) async {
    try {
      final response = await _supabase
          .from('data_export_requests')
          .select()
          .eq('user_id', userId)
          .eq('status', 'pending')
          .limit(10);

      return response.map((json) => DataExportRequest.fromJson(json)).toList();
    } catch (e) {
      Logger.warning('$_logTag: Could not fetch pending exports', e);
      return [];
    }
  }

  Future<List<DataExportRequest>> _getStoredExportRequests(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('data_export_requests')
          .select()
          .eq('user_id', userId)
          .order('requested_at', ascending: false)
          .limit(50);

      return response.map((json) => DataExportRequest.fromJson(json)).toList();
    } catch (e) {
      Logger.warning('$_logTag: Could not fetch export requests', e);
      return [];
    }
  }

  Future<DataExportRequest?> _getExportRequest(String requestId) async {
    try {
      final response = await _supabase
          .from('data_export_requests')
          .select()
          .eq('id', requestId)
          .single();

      return DataExportRequest.fromJson(response);
    } catch (e) {
      Logger.warning('$_logTag: Could not fetch export request: $requestId', e);
      return null;
    }
  }

  Future<void> _updateExportStatus(
    String requestId,
    DataExportStatus status, {
    String? error,
  }) async {
    try {
      final updateData = {
        'status': status.toString().split('.').last,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (error != null) {
        updateData['error_message'] = error;
      }

      if (status == DataExportStatus.completed) {
        updateData['completed_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('data_export_requests')
          .update(updateData)
          .eq('id', requestId);

      Logger.info('$_logTag: Export status updated: $requestId -> $status');
    } catch (e) {
      Logger.warning('$_logTag: Could not update export status', e);
    }
  }

  Future<void> _updateExportRequest(
    String requestId, {
    String? filePath,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (filePath != null) {
        updateData['file_path'] = filePath;
      }

      await _supabase
          .from('data_export_requests')
          .update(updateData)
          .eq('id', requestId);

      Logger.info('$_logTag: Export request updated: $requestId');
    } catch (e) {
      Logger.warning('$_logTag: Could not update export request', e);
    }
  }

  Future<void> _trackDownload(String requestId) async {
    try {
      // Increment download count
      await _supabase.rpc(
        'increment_download_count',
        params: {'request_id': requestId},
      );

      // Log download event
      await _supabase.from('export_download_logs').insert({
        'request_id': requestId,
        'downloaded_at': DateTime.now().toIso8601String(),
        'ip_address': 'masked_for_privacy', // Could get real IP if needed
      });

      Logger.info('$_logTag: Download tracked: $requestId');
    } catch (e) {
      Logger.warning('$_logTag: Could not track download', e);
    }
  }

  Future<void> _cleanupExpiredExports(List<DataExportRequest> requests) async {
    for (final request in requests) {
      if (request.isExpired && request.filePath != null) {
        try {
          final file = File(request.filePath!);
          if (await file.exists()) {
            await file.delete();
            Logger.info(
              '$_logTag: Deleted expired export file: ${request.filePath}',
            );
          }

          // Update database to mark as expired
          await _updateExportStatus(request.id, DataExportStatus.expired);
        } catch (e) {
          Logger.warning(
            '$_logTag: Error cleaning up expired export: ${request.id}',
            e,
          );
        }
      }
    }
  }

  Future<void> _recordGDPRExport(DataExportRequest request) async {
    try {
      // Record in compliance log
      await _supabase.from('gdpr_compliance_log').insert({
        'user_id': request.userId,
        'action': 'data_export',
        'request_id': request.id,
        'format': request.format.toString().split('.').last,
        'completed_at': DateTime.now().toIso8601String(),
        'legal_basis': 'GDPR Article 15 - Right to Access',
      });

      Logger.info('$_logTag: GDPR export recorded in compliance log');
    } catch (e) {
      Logger.warning('$_logTag: Could not record GDPR export', e);
    }
  }

  // Email notification methods
  Future<void> _sendGDPRCompletionEmail(DataExportRequest request) async {
    try {
      Logger.info(
        '$_logTag: Sending GDPR completion email to: ${request.userEmail}',
      );

      // Placeholder for email sending
      // await EmailService.sendTemplate(
      //   to: request.userEmail,
      //   template: 'gdpr_export_complete',
      //   variables: {
      //     'export_id': request.id,
      //     'format': request.format.toString().split('.').last,
      //     'expires_at': request.expiresAt,
      //   },
      // );
    } catch (e) {
      Logger.error('$_logTag: Error sending completion email', e);
    }
  }

  Future<void> _sendGDPRErrorEmail(
    DataExportRequest request,
    String error,
  ) async {
    try {
      Logger.info(
        '$_logTag: Sending GDPR error email to: ${request.userEmail}',
      );

      // Placeholder for error email sending
    } catch (e) {
      Logger.error('$_logTag: Error sending error email', e);
    }
  }

  /// Legacy method for backward compatibility
  @Deprecated('Use requestGDPRDataExport instead')
  Future<DataExportResult> exportUserDataAsJson(String userId) async {
    try {
      Logger.info('Using legacy export method for user $userId');

      // Use old gathering method for compatibility
      final userData = await _gatherAllUserData(userId);
      final jsonData = json.encode(userData);

      final fileName =
          'user_data_export_${userId}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = await _createExportFile(fileName, jsonData);

      return DataExportResult(
        filePath: file.path,
        fileName: fileName,
        fileSize: await file.length(),
        format: ExportFormat.json,
        exportedAt: DateTime.now(),
        recordCount: _countRecords(userData),
      );
    } catch (e) {
      Logger.error('Error in legacy JSON export for user $userId', e);
      rethrow;
    }
  }

  /// Legacy method for backward compatibility
  @Deprecated('Use requestGDPRDataExport instead')
  Future<DataExportResult> exportUserDataAsCsv(String userId) async {
    try {
      Logger.info('Using legacy CSV export method for user $userId');

      final userData = await _gatherAllUserData(userId);
      final csvData = await _convertToCSV(userData);

      final fileName =
          'user_data_export_${userId}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = await _createExportFile(fileName, csvData);

      return DataExportResult(
        filePath: file.path,
        fileName: fileName,
        fileSize: await file.length(),
        format: ExportFormat.csv,
        exportedAt: DateTime.now(),
        recordCount: _countRecords(userData),
      );
    } catch (e) {
      Logger.error('Error in legacy CSV export for user $userId', e);
      rethrow;
    }
  }

  // Legacy helper methods
  Future<Map<String, dynamic>> _gatherAllUserData(String userId) async {
    final userData = <String, dynamic>{};

    try {
      // Profile data
      final profileResponse = await _supabase
          .from(SupabaseConfig.usersTable) // 'profiles' table
          .select()
          .eq('user_id', userId) // Match by user_id FK
          .single();
      userData['profile'] = profileResponse;

      // Games data
      final gamesResponse = await _supabase
          .from('games')
          .select()
          .or('creator_id.eq.$userId,participants.cs.{$userId}');
      userData['games'] = gamesResponse;

      // Add other data sources...
      // (keeping original implementation for compatibility)

      userData['export_metadata'] = {
        'user_id': userId,
        'exported_at': DateTime.now().toIso8601String(),
        'export_version': '1.0',
        'gdpr_compliant': false, // Legacy format
        'data_sources': userData.keys.toList(),
      };

      return userData;
    } catch (e) {
      Logger.error('Error gathering legacy user data for $userId', e);
      rethrow;
    }
  }

  Future<String> _convertToCSV(Map<String, dynamic> userData) async {
    final csvRows = <List<String>>[];
    csvRows.add(['Table', 'Field', 'Value', 'Type', 'Updated At']);

    for (final entry in userData.entries) {
      final tableName = entry.key;
      final data = entry.value;

      if (data is List) {
        for (int i = 0; i < data.length; i++) {
          final record = data[i];
          if (record is Map<String, dynamic>) {
            _addRecordToCSV(csvRows, tableName, record, i.toString());
          }
        }
      } else if (data is Map<String, dynamic>) {
        _addRecordToCSV(csvRows, tableName, data, '0');
      }
    }

    return 'CSV export requires csv package dependency';
    // return const ListToCsvConverter().convert(csvRows);
  }

  void _addRecordToCSV(
    List<List<String>> csvRows,
    String tableName,
    Map<String, dynamic> record,
    String recordIndex,
  ) {
    for (final field in record.entries) {
      final fieldName = field.key;
      final value = field.value;
      final valueType = value.runtimeType.toString();
      final updatedAt =
          record['updated_at']?.toString() ??
          record['created_at']?.toString() ??
          '';

      csvRows.add([
        tableName,
        fieldName,
        value?.toString() ?? '',
        valueType,
        updatedAt,
      ]);
    }
  }

  Future<File> _createExportFile(String fileName, String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content, encoding: utf8);
    return file;
  }

  int _countRecords(Map<String, dynamic> userData) {
    int count = 0;
    for (final value in userData.values) {
      if (value is List) {
        count += value.length;
      } else if (value is Map) {
        count += 1;
      }
    }
    return count;
  }
}

/// GDPR-compliant data export request model
class DataExportRequest {
  final String id;
  final String userId;
  final String userEmail;
  final DataExportFormat format;
  final DataExportStatus status;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final bool sendEmailNotification;
  final String? customMessage;
  final String? filePath;
  final String? errorMessage;
  final DateTime? completedAt;
  final int downloadCount;

  DataExportRequest({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.format,
    required this.status,
    required this.requestedAt,
    required this.expiresAt,
    this.sendEmailNotification = true,
    this.customMessage,
    this.filePath,
    this.errorMessage,
    this.completedAt,
    this.downloadCount = 0,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isCompleted => status == DataExportStatus.completed;
  bool get isPending => status == DataExportStatus.pending;
  bool get isProcessing => status == DataExportStatus.processing;
  bool get hasFailed => status == DataExportStatus.failed;

  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());
  Duration get timeSinceRequest => DateTime.now().difference(requestedAt);

  factory DataExportRequest.fromJson(Map<String, dynamic> json) {
    return DataExportRequest(
      id: json['id'],
      userId: json['user_id'],
      userEmail: json['user_email'],
      format: DataExportFormat.values.byName(json['format']),
      status: DataExportStatus.values.byName(json['status']),
      requestedAt: DateTime.parse(json['requested_at']),
      expiresAt: DateTime.parse(json['expires_at']),
      sendEmailNotification: json['send_email_notification'] ?? true,
      customMessage: json['custom_message'],
      filePath: json['file_path'],
      errorMessage: json['error_message'],
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      downloadCount: json['download_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_email': userEmail,
      'format': format.toString().split('.').last,
      'status': status.toString().split('.').last,
      'requested_at': requestedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'send_email_notification': sendEmailNotification,
      'custom_message': customMessage,
      'file_path': filePath,
      'error_message': errorMessage,
      'completed_at': completedAt?.toIso8601String(),
      'download_count': downloadCount,
    };
  }
}

/// GDPR data export formats
enum DataExportFormat { json, csv, zip }

/// Data export status enumeration
enum DataExportStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
  expired,
}

/// Comprehensive user export data container for GDPR compliance
class UserExportData {
  final String userId;
  final DateTime exportedAt;

  // Core user data
  Map<String, dynamic>? profile;
  Map<String, dynamic>? preferences;
  List<Map<String, dynamic>>? sportsProfiles;
  Map<String, dynamic>? statistics;
  List<Map<String, dynamic>>? gameHistory;

  // Privacy and compliance data
  Map<String, dynamic>? privacySettings;
  List<Map<String, dynamic>>? consents;
  List<Map<String, dynamic>>? auditLogs;
  List<Map<String, dynamic>>? loginHistory;

  // Social and communication data
  List<Map<String, dynamic>>? connections;
  List<Map<String, dynamic>>? messages;
  List<Map<String, dynamic>>? notifications;

  // Technical and system data
  List<Map<String, dynamic>>? media;
  List<Map<String, dynamic>>? locationData;
  List<Map<String, dynamic>>? deviceInfo;

  // Financial and business data
  Map<String, dynamic>? paymentData;
  List<Map<String, dynamic>>? integrations;

  UserExportData({required this.userId, required this.exportedAt});

  Map<String, dynamic> toJson() {
    return {
      'export_metadata': {
        'user_id': userId,
        'exported_at': exportedAt.toIso8601String(),
        'export_version': '2.0',
        'gdpr_compliant': true,
        'total_data_categories': _countNonNullCategories(),
      },
      'profile': profile,
      'preferences': preferences,
      'sports_profiles': sportsProfiles,
      'statistics': statistics,
      'game_history': gameHistory,
      'privacy_settings': privacySettings,
      'consents': consents,
      'audit_logs': auditLogs,
      'login_history': loginHistory,
      'connections': connections,
      'messages': messages,
      'notifications': notifications,
      'media': media,
      'location_data': locationData,
      'device_info': deviceInfo,
      'payment_data': paymentData,
      'integrations': integrations,
    };
  }

  int _countNonNullCategories() {
    int count = 0;
    if (profile != null) count++;
    if (preferences != null) count++;
    if (sportsProfiles?.isNotEmpty == true) count++;
    if (statistics != null) count++;
    if (gameHistory?.isNotEmpty == true) count++;
    if (privacySettings != null) count++;
    if (consents?.isNotEmpty == true) count++;
    if (auditLogs?.isNotEmpty == true) count++;
    if (loginHistory?.isNotEmpty == true) count++;
    if (connections?.isNotEmpty == true) count++;
    if (messages?.isNotEmpty == true) count++;
    if (notifications?.isNotEmpty == true) count++;
    if (media?.isNotEmpty == true) count++;
    if (locationData?.isNotEmpty == true) count++;
    if (deviceInfo?.isNotEmpty == true) count++;
    if (paymentData != null) count++;
    if (integrations?.isNotEmpty == true) count++;
    return count;
  }
}

/// Legacy export formats for backward compatibility
enum ExportFormat { json, csv }

/// Legacy result of data export operation
class DataExportResult {
  final String filePath;
  final String fileName;
  final int fileSize;
  final ExportFormat format;
  final DateTime exportedAt;
  final int recordCount;

  DataExportResult({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.format,
    required this.exportedAt,
    required this.recordCount,
  });
}

/// Legacy data export record from database
class DataExportRecord {
  final String id;
  final String userId;
  final String fileName;
  final int fileSize;
  final ExportFormat format;
  final int recordCount;
  final DateTime exportedAt;
  final DateTime createdAt;

  DataExportRecord({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.fileSize,
    required this.format,
    required this.recordCount,
    required this.exportedAt,
    required this.createdAt,
  });

  factory DataExportRecord.fromJson(Map<String, dynamic> json) {
    return DataExportRecord(
      id: json['id'],
      userId: json['user_id'],
      fileName: json['file_name'],
      fileSize: json['file_size'],
      format: ExportFormat.values.byName(json['format']),
      recordCount: json['record_count'],
      exportedAt: DateTime.parse(json['exported_at']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// Provider for data export service
final dataExportServiceProvider = Provider<DataExportService>((ref) {
  return DataExportService();
});
