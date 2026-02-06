import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'analytics_constants.dart';

/// Local storage manager for analytics events
class AnalyticsStorage {
  static const String _eventsKey = 'analytics_events';
  static const String _sessionKey = 'analytics_session';
  static const String _userPropertiesKey = 'analytics_user_properties';
  static const String _deviceIdKey = 'analytics_device_id';

  /// Store an analytics event locally
  static Future<void> storeEvent(AnalyticsEvent event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingEvents = await getStoredEvents();

      existingEvents.add(event);

      // Limit stored events to prevent excessive memory usage
      if (existingEvents.length > AnalyticsConfig.maxLocalEvents) {
        existingEvents.removeRange(
          0,
          existingEvents.length - AnalyticsConfig.maxLocalEvents,
        );
      }

      final eventsJson = existingEvents.map((e) => e.toJson()).toList();
      await prefs.setString(_eventsKey, jsonEncode(eventsJson));
    } catch (e) {}
  }

  /// Retrieve stored analytics events
  static Future<List<AnalyticsEvent>> getStoredEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsString = prefs.getString(_eventsKey);

      if (eventsString == null) return [];

      final eventsJson = jsonDecode(eventsString) as List;
      return eventsJson.map((json) => AnalyticsEvent.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Clear stored events after successful upload
  static Future<void> clearEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_eventsKey);
    } catch (e) {}
  }

  /// Remove specific events (e.g., after partial upload)
  static Future<void> removeEvents(List<AnalyticsEvent> eventsToRemove) async {
    try {
      final allEvents = await getStoredEvents();
      final remainingEvents = allEvents.where((event) {
        return !eventsToRemove.any(
          (remove) =>
              remove.timestamp == event.timestamp && remove.name == event.name,
        );
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      final eventsJson = remainingEvents.map((e) => e.toJson()).toList();
      await prefs.setString(_eventsKey, jsonEncode(eventsJson));
    } catch (e) {}
  }

  /// Store current session
  static Future<void> storeSession(AnalyticsSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    } catch (e) {}
  }

  /// Retrieve current session
  static Future<AnalyticsSession?> getStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionString = prefs.getString(_sessionKey);

      if (sessionString == null) return null;

      final sessionJson = jsonDecode(sessionString);
      return AnalyticsSession(
        sessionId: sessionJson['session_id'],
        startTime: DateTime.parse(sessionJson['start_time']),
        userId: sessionJson['user_id'],
        properties: Map<String, dynamic>.from(sessionJson['properties'] ?? {}),
      );
    } catch (e) {
      return null;
    }
  }

  /// Store user properties
  static Future<void> storeUserProperties(
    Map<String, dynamic> properties,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userPropertiesKey, jsonEncode(properties));
    } catch (e) {}
  }

  /// Retrieve user properties
  static Future<Map<String, dynamic>> getUserProperties() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final propertiesString = prefs.getString(_userPropertiesKey);

      if (propertiesString == null) return {};

      return Map<String, dynamic>.from(jsonDecode(propertiesString));
    } catch (e) {
      return {};
    }
  }

  /// Get or generate device ID
  static Future<String> getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_deviceIdKey);

      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString(_deviceIdKey, deviceId);
      }

      return deviceId;
    } catch (e) {
      return const Uuid().v4();
    }
  }

  /// Clear all analytics data
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_eventsKey);
      await prefs.remove(_sessionKey);
      await prefs.remove(_userPropertiesKey);
      // Keep device ID for continuity
    } catch (e) {}
  }

  /// Get storage statistics
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final events = await getStoredEvents();
      final userProperties = await getUserProperties();
      final session = await getStoredSession();

      return {
        'stored_events_count': events.length,
        'user_properties_count': userProperties.length,
        'has_active_session': session != null && !session.isExpired,
        'oldest_event_timestamp': events.isNotEmpty
            ? events.first.timestamp.toIso8601String()
            : null,
        'newest_event_timestamp': events.isNotEmpty
            ? events.last.timestamp.toIso8601String()
            : null,
      };
    } catch (e) {
      return {};
    }
  }
}

/// Session manager for analytics
class AnalyticsSessionManager {
  static AnalyticsSession? _currentSession;
  static Timer? _sessionTimer;

  /// Start a new session
  static Future<AnalyticsSession> startSession({String? userId}) async {
    await endCurrentSession();

    final sessionId = const Uuid().v4();
    final deviceId = await AnalyticsStorage.getDeviceId();

    _currentSession = AnalyticsSession(
      sessionId: sessionId,
      startTime: DateTime.now(),
      userId: userId,
      properties: {'device_id': deviceId, 'platform': 'flutter'},
    );

    await AnalyticsStorage.storeSession(_currentSession!);
    _startSessionTimer();

    return _currentSession!;
  }

  /// Resume existing session or start new one
  static Future<AnalyticsSession> getOrCreateSession({String? userId}) async {
    // Try to restore existing session
    final storedSession = await AnalyticsStorage.getStoredSession();

    if (storedSession != null && !storedSession.isExpired) {
      _currentSession = storedSession;
      _currentSession!.updateActivity();
      await AnalyticsStorage.storeSession(_currentSession!);
      _startSessionTimer();
      return _currentSession!;
    }

    // Start new session if none exists or expired
    return await startSession(userId: userId);
  }

  /// Update session activity
  static Future<void> updateActivity() async {
    if (_currentSession != null) {
      _currentSession!.updateActivity();
      await AnalyticsStorage.storeSession(_currentSession!);
    }
  }

  /// End current session
  static Future<void> endCurrentSession() async {
    if (_currentSession != null) {
      // Store final session data
      await AnalyticsStorage.storeSession(_currentSession!);

      // Track session end event
      final sessionEvent = AnalyticsEvent(
        name: 'session_ended',
        parameters: {
          'session_duration_seconds': _currentSession!.duration.inSeconds,
          'session_id': _currentSession!.sessionId,
        },
        priority: AnalyticsEventPriority.medium,
      );

      await AnalyticsStorage.storeEvent(sessionEvent);
    }

    _currentSession = null;
    _sessionTimer?.cancel();
  }

  /// Get current session
  static AnalyticsSession? get currentSession => _currentSession;

  /// Check if session is active
  static bool get hasActiveSession =>
      _currentSession != null && !_currentSession!.isExpired;

  /// Start session timeout timer
  static void _startSessionTimer() {
    _sessionTimer?.cancel();

    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (_currentSession?.isExpired == true) {
        await endCurrentSession();
      }
    });
  }

  /// Get session statistics
  static Map<String, dynamic> getSessionStats() {
    if (_currentSession == null) {
      return {'has_session': false};
    }

    return {
      'has_session': true,
      'session_id': _currentSession!.sessionId,
      'session_duration_seconds': _currentSession!.duration.inSeconds,
      'is_expired': _currentSession!.isExpired,
      'user_id': _currentSession!.userId,
    };
  }
}

/// Event queue manager for batching and uploading
class AnalyticsEventQueue {
  static Timer? _uploadTimer;
  static bool _isUploading = false;

  /// Initialize the event queue system
  static void initialize() {
    _startUploadTimer();
  }

  /// Add event to queue
  static Future<void> addEvent(AnalyticsEvent event) async {
    await AnalyticsStorage.storeEvent(event);

    // Immediately upload critical events
    if (event.priority == AnalyticsEventPriority.critical) {
      _uploadEvents();
    }
  }

  /// Start periodic upload timer
  static void _startUploadTimer() {
    _uploadTimer?.cancel();

    _uploadTimer = Timer.periodic(
      Duration(seconds: AnalyticsConfig.uploadIntervalSeconds),
      (_) => _uploadEvents(),
    );
  }

  /// Upload queued events
  static Future<void> _uploadEvents() async {
    if (_isUploading) return;

    try {
      _isUploading = true;
      final events = await AnalyticsStorage.getStoredEvents();

      if (events.isEmpty) return;

      // Group events by priority
      final criticalEvents = events
          .where((e) => e.priority == AnalyticsEventPriority.critical)
          .toList();
      final highPriorityEvents = events
          .where((e) => e.priority == AnalyticsEventPriority.high)
          .toList();
      final mediumPriorityEvents = events
          .where((e) => e.priority == AnalyticsEventPriority.medium)
          .toList();
      final lowPriorityEvents = events
          .where((e) => e.priority == AnalyticsEventPriority.low)
          .toList();

      // Upload in priority order
      await _uploadEventBatch(criticalEvents);
      await _uploadEventBatch(highPriorityEvents);

      // Apply sampling for performance metrics
      final sampledMediumEvents = _sampleEvents(mediumPriorityEvents);
      final sampledLowEvents = _sampleEvents(lowPriorityEvents);

      await _uploadEventBatch(sampledMediumEvents);
      await _uploadEventBatch(sampledLowEvents);

      // Clear uploaded events
      await AnalyticsStorage.clearEvents();
    } finally {
      _isUploading = false;
    }
  }

  /// Upload a batch of events
  static Future<void> _uploadEventBatch(List<AnalyticsEvent> events) async {
    if (events.isEmpty) return;

    // Split into smaller batches
    for (int i = 0; i < events.length; i += AnalyticsConfig.eventBatchSize) {
      final end = math.min(i + AnalyticsConfig.eventBatchSize, events.length);
      final batch = events.sublist(i, end);

      // Simulate API call
      // In a real implementation, you would send this to your analytics service

      // Add delay to simulate network call
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Apply sampling to events to reduce volume
  static List<AnalyticsEvent> _sampleEvents(List<AnalyticsEvent> events) {
    if (AnalyticsConfig.performanceSampleRate >= 1.0) {
      return events;
    }

    final random = math.Random();
    return events.where((_) {
      return random.nextDouble() < AnalyticsConfig.performanceSampleRate;
    }).toList();
  }

  /// Force immediate upload
  static Future<void> forceUpload() async {
    if (!_isUploading) {
      await _uploadEvents();
    }
  }

  /// Stop the upload timer
  static void dispose() {
    _uploadTimer?.cancel();
    _isUploading = false;
  }

  /// Get queue statistics
  static Future<Map<String, dynamic>> getQueueStats() async {
    final events = await AnalyticsStorage.getStoredEvents();

    final priorityCounts = <String, int>{};
    for (final priority in AnalyticsEventPriority.values) {
      priorityCounts[priority.name] = events
          .where((e) => e.priority == priority)
          .length;
    }

    return {
      'total_queued_events': events.length,
      'priority_breakdown': priorityCounts,
      'is_uploading': _isUploading,
      'oldest_event_age_seconds': events.isNotEmpty
          ? DateTime.now().difference(events.first.timestamp).inSeconds
          : 0,
    };
  }
}
