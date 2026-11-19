// KAN-1005 (W3-N1): the Live Activity payload models, events and error codes.
// The wire format is CHANNEL_CONTRACT.md in this folder; the server side is
// supabase/migrations/20261118140810_kan1004b_live_activity_fixes.sql.

import 'package:flutter/services.dart' show PlatformException;

import 'package:dabbler/core/fp/failure.dart';

/// Whether this device can show Live Activities, and whether the user allows it.
enum LiveActivityPermission { granted, denied, unsupported }

/// What the native side reports from `getCapabilities`.
class LiveActivityCapabilities {
  const LiveActivityCapabilities({
    required this.supported,
    required this.permission,
    required this.pushToStart,
  });

  static const LiveActivityCapabilities unsupported = LiveActivityCapabilities(
    supported: false,
    permission: LiveActivityPermission.unsupported,
    pushToStart: false,
  );

  final bool supported;
  final LiveActivityPermission permission;

  /// iOS 17.2+ push-to-start is available.
  final bool pushToStart;

  bool get canStart =>
      supported && permission == LiveActivityPermission.granted;

  static LiveActivityCapabilities fromMap(Map<Object?, Object?>? m) {
    if (m == null) return unsupported;
    final supported = m['supported'] == true;
    final permission = switch (m['permission']) {
      'granted' => LiveActivityPermission.granted,
      'denied' => LiveActivityPermission.denied,
      _ => LiveActivityPermission.unsupported,
    };
    return LiveActivityCapabilities(
      supported: supported,
      permission: supported ? permission : LiveActivityPermission.unsupported,
      pushToStart: supported && m['push_to_start'] == true,
    );
  }
}

/// The platform-neutral content-state. [raw] is the exact map the server
/// sent (Unix-second dates, null keys omitted) and is what crosses the
/// channel; the typed getters are for Dart callers.
class LiveActivityContent {
  const LiveActivityContent(this.raw);

  final Map<String, Object?> raw;

  static LiveActivityContent? tryParse(Object? value) {
    if (value is! Map) return null;
    final m = Map<String, Object?>.from(value);
    if (m['state'] is! String || _int(m['state_version']) == null) return null;
    if (m['event_id'] is! String) return null;
    return LiveActivityContent(m);
  }

  String get state => raw['state']! as String;
  int get stateVersion => _int(raw['state_version'])!;
  String get eventId => raw['event_id']! as String;
  String? get eventType => raw['event_type'] as String?;
  String? get title => raw['title'] as String?;
  DateTime? get startAt => _date(raw['start_at']);
  DateTime? get endAt => _date(raw['end_at']);
  bool get checkedIn => raw['checked_in'] == true;

  /// KAN-1024: whether this user may check in now; null on an older payload.
  bool? get checkinOpen {
    final v = raw['checkin_open'];
    return v is bool ? v : null;
  }

  /// KAN-1024: when the check-in window closes, when known.
  DateTime? get checkinClosesAt => _date(raw['checkin_closes_at']);
  String? get role => raw['role'] as String?;
  String? get endReason => raw['end_reason'] as String?;

  /// Whether this is newer than [lastSeen]: the version rule. Anything not
  /// strictly higher is ignored.
  bool isNewerThan(int? lastSeen) =>
      lastSeen == null || stateVersion > lastSeen;

  /// The `attributes` passed on start (DabblerActivityAttributes on iOS).
  Map<String, Object?> get attributes => {
    'event_id': eventId,
    if (eventType != null) 'event_type': eventType,
    if (title != null) 'title': title,
  };

  static DateTime? _date(Object? v) {
    final s = _int(v);
    return s == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
  }
}

int? _int(Object? v) => switch (v) {
  final int i => i,
  final num n => n.toInt(),
  final String s => int.tryParse(s),
  _ => null,
};

/// One row of `rpc_live_activity_sessions`.
class LiveActivitySession {
  const LiveActivitySession({
    required this.sessionId,
    required this.eventId,
    required this.platform,
    required this.status,
    required this.needsLocalStart,
    required this.stateVersion,
    required this.activityId,
    required this.hasPushToken,
    required this.content,
  });

  final String sessionId;
  final String eventId;
  final String? platform;

  /// planned | active | stale | ended
  final String status;
  final bool needsLocalStart;
  final int stateVersion;
  final String? activityId;
  final bool hasPushToken;
  final LiveActivityContent? content;

  bool get isEnded => status == 'ended';

  static LiveActivitySession? tryParse(Object? value) {
    if (value is! Map) return null;
    final m = Map<String, Object?>.from(value);
    final id = m['session_id'];
    if (id is! String) return null;
    final status = (m['status'] as String?) ?? 'planned';
    return LiveActivitySession(
      sessionId: id,
      eventId: (m['event_id'] as String?) ?? '',
      platform: m['platform'] as String?,
      status: status,
      needsLocalStart:
          m['needs_local_start'] == true || status == 'needs_local_start',
      stateVersion: _int(m['state_version']) ?? 0,
      activityId: m['activity_id'] as String?,
      hasPushToken: m['has_push_token'] == true,
      content: LiveActivityContent.tryParse(m['content']),
    );
  }

  static List<LiveActivitySession> parseList(Object? value) {
    if (value is! List) return const [];
    return value
        .map(LiveActivitySession.tryParse)
        .whereType<LiveActivitySession>()
        .toList();
  }
}

/// What `start` returns.
class LiveActivityStarted {
  const LiveActivityStarted({
    required this.activityId,
    this.pushToken,
    this.androidNotificationId,
  });

  final String activityId;
  final String? pushToken;
  final int? androidNotificationId;

  static LiveActivityStarted? fromMap(Map<Object?, Object?>? m) {
    final id = m?['activity_id'];
    if (id is! String) return null;
    return LiveActivityStarted(
      activityId: id,
      pushToken: m!['push_token'] as String?,
      androidNotificationId: _int(m['android_notification_id']),
    );
  }
}

/// An activity the native side is showing now (`listActive`).
class LiveActivityActive {
  const LiveActivityActive({
    required this.sessionId,
    required this.activityId,
    required this.stateVersion,
  });

  final String sessionId;
  final String activityId;
  final int stateVersion;

  static LiveActivityActive? fromMap(Object? v) {
    if (v is! Map) return null;
    final s = v['session_id'], a = v['activity_id'];
    if (s is! String || a is! String) return null;
    return LiveActivityActive(
      sessionId: s,
      activityId: a,
      stateVersion: _int(v['state_version']) ?? 0,
    );
  }
}

/// Events from the EventChannel. Native identifies the activity by its
/// `event_id` (the attributes carry no session id); the controller maps it
/// to a session. `session_id` is used when native also sends it.
sealed class LiveActivityEvent {
  const LiveActivityEvent();

  static LiveActivityEvent? fromMap(Object? v) {
    if (v is! Map) return null;
    final event = v['event_id'] as String?;
    final session = v['session_id'] as String?;
    final activity = v['activity_id'] as String?;
    final hasKey = event != null || session != null;
    return switch (v['type']) {
      'push_to_start_token' when v['token'] is String =>
        LiveActivityPushToStartToken(v['token'] as String),
      'activity_token'
          when hasKey && activity != null && v['token'] is String =>
        LiveActivityTokenChanged(
          eventId: event,
          sessionId: session,
          activityId: activity,
          token: v['token'] as String,
        ),
      'activity_ended' when hasKey => LiveActivityEndedOnDevice(
        eventId: event,
        sessionId: session,
        activityId: activity,
        reason: v['reason'] as String?,
      ),
      'tap' when hasKey => LiveActivityTapped(
        eventId: event,
        sessionId: session,
        action: v['action'] as String?,
      ),
      _ => null,
    };
  }
}

class LiveActivityPushToStartToken extends LiveActivityEvent {
  const LiveActivityPushToStartToken(this.token);
  final String token;
}

class LiveActivityTokenChanged extends LiveActivityEvent {
  const LiveActivityTokenChanged({
    required this.eventId,
    required this.sessionId,
    required this.activityId,
    required this.token,
  });
  final String? eventId;
  final String? sessionId;
  final String activityId;
  final String token;
}

/// The user (or the system) dismissed the activity.
class LiveActivityEndedOnDevice extends LiveActivityEvent {
  const LiveActivityEndedOnDevice({
    required this.eventId,
    required this.sessionId,
    required this.activityId,
    required this.reason,
  });
  final String? eventId;
  final String? sessionId;
  final String? activityId;

  /// user_dismissed | system | expired
  final String? reason;

  bool get userDismissed => reason == 'user_dismissed';
}

class LiveActivityTapped extends LiveActivityEvent {
  const LiveActivityTapped({
    required this.eventId,
    required this.sessionId,
    required this.action,
  });
  final String? eventId;
  final String? sessionId;

  /// open | start | confirm_end (null = open)
  final String? action;
}

/// The channel's error codes (CHANNEL_CONTRACT.md, Errors).
abstract final class LiveActivityErrorCode {
  static const unsupported = 'unsupported';
  static const permissionDenied = 'permission_denied';
  static const notFound = 'not_found';
  static const invalidPayload = 'invalid_payload';
  static const limitReached = 'limit_reached';
  static const internal = 'internal';
}

/// Maps a channel error to a [Failure] whose `code` is the contract code.
Failure liveActivityFailure(Object error) {
  if (error is Failure) return error;
  if (error is PlatformException) {
    final category = switch (error.code) {
      LiveActivityErrorCode.permissionDenied => FailureCode.forbidden,
      LiveActivityErrorCode.notFound => FailureCode.notFound,
      LiveActivityErrorCode.invalidPayload => FailureCode.validation,
      LiveActivityErrorCode.limitReached => FailureCode.rateLimited,
      LiveActivityErrorCode.unsupported => FailureCode.cancelled,
      _ => FailureCode.unknown,
    };
    return Failure(
      category: category,
      message: error.message ?? error.code,
      code: error.code,
      cause: error,
    );
  }
  return Failure.from(error);
}

/// The failure every stub call returns.
const Failure liveActivityUnsupported = Failure(
  category: FailureCode.cancelled,
  message: 'Live Activities are not supported on this platform',
  code: LiveActivityErrorCode.unsupported,
);
