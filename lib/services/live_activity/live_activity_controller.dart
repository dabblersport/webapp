// KAN-1005 (W3-N1): keeps this device's Live Activities in step with the
// server's sessions (rpc_live_activity_sessions) and registers their tokens.
// Every call is best-effort: a failure is returned, never thrown, and never
// blocks app start.

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/constants/timing/notification_timing.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/services/notifications/push_installation_id.dart';

import 'live_activity_service.dart';

typedef LiveActivityRpc =
    Future<dynamic> Function(String fn, Map<String, dynamic> params);

class LiveActivityController {
  LiveActivityController({
    required this.service,
    LiveActivityRpc? rpc,
    Future<String> Function()? installationId,
    Future<SharedPreferences> Function()? prefs,
    bool Function()? hasSession,
    DateTime Function()? now,
  }) : _rpc = rpc ?? _supabaseRpc,
       _installationId = installationId ?? PushInstallationId().read,
       _prefs = prefs ?? SharedPreferences.getInstance,
       _hasSession = hasSession ?? _supabaseHasSession,
       _now = now ?? DateTime.now;

  static Future<dynamic> _supabaseRpc(String fn, Map<String, dynamic> p) =>
      Supabase.instance.client.rpc(fn, params: p);

  static bool _supabaseHasSession() =>
      Supabase.instance.client.auth.currentSession != null;

  /// SharedPreferences key prefix of the dismissed sessions, per installation.
  static const String dismissedKeyPrefix = 'live_activity_dismissed:';

  final Future<SharedPreferences> Function() _prefs;
  final bool Function() _hasSession;
  final DateTime Function() _now;

  /// The last rpc_live_activity_sessions result (event_id -> session).
  List<LiveActivitySession> _lastSessions = const [];

  /// Registrations that failed, retried on the next sync.
  final Map<String, _PendingRegister> _pendingRegister = {};

  Future<Result<bool, Failure>>? _inFlight;
  DateTime? _lastSyncAt;

  final LiveActivityService service;
  final LiveActivityRpc _rpc;
  final Future<String> Function() _installationId;

  /// The highest state_version seen per session (the version rule).
  final Map<String, int> _versions = {};

  /// session_id -> activity_id of what this device shows.
  final Map<String, String> _activities = {};

  StreamSubscription<LiveActivityEvent>? _sub;
  String? _lastPushToStart;

  int? versionOf(String sessionId) => _versions[sessionId];

  /// session_id -> activity_id of what this device shows (read-only).
  Map<String, String> get activities => Map.unmodifiable(_activities);

  /// Listens to native events. Safe to call more than once.
  void start() {
    _sub ??= service.events.listen((e) => unawaited(_onEvent(e)));
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<Result<T, Failure>> _guard<T>(Future<T> Function() body) =>
      Result.guard(body, liveActivityFailure);

  Future<void> _onEvent(LiveActivityEvent e) async {
    switch (e) {
      case LiveActivityPushToStartToken(:final token):
        await registerPushToStart(token);
      case LiveActivityTokenChanged(:final activityId, :final token):
        final sessionId = await _resolveSession(e.sessionId, e.eventId);
        if (sessionId == null) return;
        _activities[sessionId] = activityId;
        await _register(sessionId, activityId, pushToken: token);
      case LiveActivityEndedOnDevice():
        final sessionId =
            await _resolveSession(e.sessionId, e.eventId) ??
            _sessionOfActivity(e.activityId);
        if (sessionId == null) return;
        _activities.remove(sessionId);
        _pendingRegister.remove(sessionId);
        if (e.userDismissed) await _addDismissed(sessionId);
      case LiveActivityTapped():
        break; // Routing is the native halves' deep link (KAN-1006/1007).
    }
  }

  String? _sessionOfActivity(String? activityId) {
    if (activityId == null) return null;
    for (final MapEntry(:key, :value) in _activities.entries) {
      if (value == activityId) return key;
    }
    return null;
  }

  String? _sessionForEvent(String eventId) {
    for (final s in _lastSessions) {
      if (s.eventId == eventId) return s.sessionId;
    }
    return null;
  }

  /// Maps a native event to a session: its session_id if sent, else its
  /// event_id in the last sessions result, else after one re-read.
  Future<String?> _resolveSession(String? sessionId, String? eventId) async {
    if (sessionId != null) return sessionId;
    if (eventId == null) return null;
    final known = _sessionForEvent(eventId);
    if (known != null) return known;
    final read = await _readSessions();
    if (read case Ok(:final value)) _lastSessions = value;
    return _sessionForEvent(eventId);
  }

  Future<Result<List<LiveActivitySession>, Failure>> _readSessions() =>
      _guard(() async {
        final id = await _installationId();
        return LiveActivitySession.parseList(
          await _rpc(SupabaseConfig.rpcLiveActivitySessions, {
            'p_installation_id': id,
          }),
        );
      });

  Future<String> _dismissedKey() async =>
      '$dismissedKeyPrefix${await _installationId()}';

  Future<Set<String>> _readDismissed() async {
    try {
      final prefs = await _prefs();
      return (prefs.getStringList(await _dismissedKey()) ?? const []).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _addDismissed(String sessionId) async {
    try {
      final prefs = await _prefs();
      final key = await _dismissedKey();
      final set = (prefs.getStringList(key) ?? const []).toSet()
        ..add(sessionId);
      await prefs.setStringList(key, set.toList());
    } catch (_) {
      // Best-effort: storage unavailable.
    }
  }

  /// Sends the iOS push-to-start token for this installation (once per value).
  Future<Result<Unit, Failure>> registerPushToStart(String token) async {
    if (token == _lastPushToStart) return const Ok(unit);
    final r = await _guard(() async {
      await _rpc(SupabaseConfig.rpcLiveActivityRegisterPushToStart, {
        'p_installation_id': await _installationId(),
        'p_token': token,
      });
      return unit;
    });
    if (r.isSuccess) _lastPushToStart = token;
    return r;
  }

  Future<Result<Unit, Failure>> _register(
    String sessionId,
    String activityId, {
    String? pushToken,
    int? androidNotificationId,
  }) async {
    final r = await _guard(() async {
      await _rpc(SupabaseConfig.rpcLiveActivityRegister, {
        'p_session_id': sessionId,
        'p_activity_id': activityId,
        'p_push_token': pushToken,
        'p_android_notification_id': androidNotificationId,
      });
      return unit;
    });
    if (r.isSuccess) {
      _pendingRegister.remove(sessionId);
    } else {
      _pendingRegister[sessionId] = _PendingRegister(
        activityId,
        pushToken,
        androidNotificationId,
      );
    }
    return r;
  }

  /// On app start, sign-in and resume: reads this installation's sessions,
  /// starts the ones that need a local start (unless the user dismissed
  /// them), applies newer content, ends the ones the server ended and retries
  /// failed registrations. Ok(false) when the device has no Live Activities
  /// or nobody is signed in. A call while one runs joins it.
  Future<Result<bool, Failure>> sync() {
    final running = _inFlight;
    if (running != null) return running;
    final f = _sync().whenComplete(() => _inFlight = null);
    _inFlight = f;
    return f;
  }

  /// [sync] on resume, at most once per
  /// [NotificationTiming.liveActivityResumeThrottle].
  Future<Result<bool, Failure>> resumeSync() {
    final last = _lastSyncAt;
    if (_inFlight == null &&
        last != null &&
        _now().difference(last) <
            NotificationTiming.liveActivityResumeThrottle) {
      return Future.value(const Ok(false));
    }
    return sync();
  }

  Future<Result<bool, Failure>> _sync() async {
    if (!_hasSession()) return const Ok(false);
    _lastSyncAt = _now();
    final caps = await service.capabilities();
    if (!caps.supported) return const Ok(false);

    final read = await _readSessions();
    if (read case Err(:final error)) return Err(error);
    final sessions = read.requireValue;
    _lastSessions = sessions;

    final active = await service.listActive();
    if (active case Ok(:final value)) {
      for (final a in value) {
        _activities[a.sessionId] = a.activityId;
        final known = _versions[a.sessionId];
        if (known == null || a.stateVersion > known) {
          _versions[a.sessionId] = a.stateVersion;
        }
      }
    }

    for (final MapEntry(:key, :value) in _pendingRegister.entries.toList()) {
      if (_activities[key] != value.activityId) {
        _pendingRegister.remove(key);
        continue;
      }
      await _register(
        key,
        value.activityId,
        pushToken: value.pushToken,
        androidNotificationId: value.androidNotificationId,
      );
    }

    final dismissed = await _readDismissed();
    for (final s in sessions) {
      await _apply(s, caps, dismissed);
    }
    return const Ok(true);
  }

  /// On sign-out: ends every local activity and forgets them. The dismissed
  /// set is kept.
  Future<void> signedOut() async {
    for (final MapEntry(:key, :value) in _activities.entries.toList()) {
      await service.end(sessionId: key, activityId: value);
    }
    _activities.clear();
    _versions.clear();
    _pendingRegister.clear();
    _lastSessions = const [];
    _lastSyncAt = null;
  }

  Future<void> _apply(
    LiveActivitySession s,
    LiveActivityCapabilities caps,
    Set<String> dismissed,
  ) async {
    final shown = _activities[s.sessionId];
    final content = s.content;

    if (s.isEnded) {
      if (shown != null) await endLocal(s.sessionId, content: content);
      return;
    }
    if (content == null) return;

    if (shown == null) {
      if (!s.needsLocalStart || !caps.canStart) return;
      if (dismissed.contains(s.sessionId)) return;
      final started = await service.start(
        sessionId: s.sessionId,
        content: content,
      );
      if (started case Ok(:final value)) {
        _activities[s.sessionId] = value.activityId;
        _versions[s.sessionId] = content.stateVersion;
        await _register(
          s.sessionId,
          value.activityId,
          pushToken: value.pushToken,
          androidNotificationId: value.androidNotificationId,
        );
      }
      return;
    }

    await applyContent(s.sessionId, content);
  }

  /// Applies [content] to the shown activity if it is newer (the version
  /// rule); Ok(false) when it was ignored or nothing is shown.
  Future<Result<bool, Failure>> applyContent(
    String sessionId,
    LiveActivityContent content,
  ) async {
    final activityId = _activities[sessionId];
    if (activityId == null) return const Ok(false);
    if (!content.isNewerThan(_versions[sessionId])) return const Ok(false);
    final r = await service.update(
      sessionId: sessionId,
      activityId: activityId,
      content: content,
    );
    return r.fold((f) => Err(f), (_) {
      _versions[sessionId] = content.stateVersion;
      return const Ok(true);
    });
  }

  /// Ends the shown activity for [sessionId] (the server ended it).
  Future<Result<Unit, Failure>> endLocal(
    String sessionId, {
    LiveActivityContent? content,
  }) async {
    final activityId = _activities.remove(sessionId);
    if (activityId == null) return const Ok(unit);
    if (content != null && content.isNewerThan(_versions[sessionId])) {
      _versions[sessionId] = content.stateVersion;
    }
    return service.end(
      sessionId: sessionId,
      activityId: activityId,
      content: content,
    );
  }

  /// Turns Live Activities off (or back on) for this installation. Turning
  /// them off also ends what is shown.
  Future<Result<Unit, Failure>> setOptedOut(bool optedOut) async {
    final r = await _guard(() async {
      await _rpc(SupabaseConfig.rpcLiveActivityOptOut, {
        'p_installation_id': await _installationId(),
        'p_opted_out': optedOut,
      });
      return unit;
    });
    if (r.isSuccess && optedOut) {
      for (final id in _activities.keys.toList()) {
        await endLocal(id);
      }
    }
    return r;
  }
}

class _PendingRegister {
  const _PendingRegister(
    this.activityId,
    this.pushToken,
    this.androidNotificationId,
  );
  final String activityId;
  final String? pushToken;
  final int? androidNotificationId;
}
