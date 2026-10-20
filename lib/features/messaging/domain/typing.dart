import 'dart:async';

/// Ephemeral typing presence (KAN-579). Nothing here is stored, logged or
/// sent to a push service: a signal is ids and one boolean, it lives in memory
/// for [typingReceiverTtl] and is never part of a message.

/// How often (seconds) a typing client repeats "typing" while keys keep
/// arriving. Network cadences, not visual durations.
const int typingSendIntervalSeconds = 3;

/// No keystroke for this many seconds and the sender says it stopped.
const int typingIdleStopSeconds = 4;

/// A receiver forgets a typer this many seconds after the last "typing" it
/// heard, so a lost "stop" (airplane mode, a killed app) clears itself. It is
/// longer than the send interval plus the network, shorter than a stale label
/// would stay credible.
const int typingReceiverTtlSeconds = 6;

const Duration typingSendInterval = Duration(
  seconds: typingSendIntervalSeconds,
);
const Duration typingIdleStop = Duration(seconds: typingIdleStopSeconds);
const Duration typingReceiverTtl = Duration(seconds: typingReceiverTtlSeconds);

/// The least a timer is set for, so an entry due "now" still fires on a later
/// turn of the event loop.
const int typingMinTimerMs = 1;

/// The most names a label spells out before it counts the others.
const int typingNamedPeople = 2;

/// One typing signal: [userId] started ([on]) or stopped typing in
/// [conversationId]. Never carries text, a draft or a name.
class TypingSignal {
  const TypingSignal({
    required this.conversationId,
    required this.userId,
    required this.on,
  });

  final String conversationId;
  final String userId;
  final bool on;

  @override
  bool operator ==(Object other) =>
      other is TypingSignal &&
      other.conversationId == conversationId &&
      other.userId == userId &&
      other.on == on;

  @override
  int get hashCode => Object.hash(conversationId, userId, on);
}

/// Reads one broadcast payload into a signal, or null when it is not one. The
/// platform delivers `{event, payload: {...}, type}`; the keys the database
/// sent (`type`, `conversation_id`, `user_id`, `on`) are inside `payload`.
/// Anything else in the map is ignored and never kept.
TypingSignal? parseTypingSignal(Map<String, dynamic> raw) {
  final inner = raw['payload'];
  final body = inner is Map ? Map<String, dynamic>.from(inner) : raw;
  if (body['type'] != 'typing') return null;
  final conversationId = body['conversation_id'];
  final userId = body['user_id'];
  final on = body['on'];
  if (conversationId is! String || conversationId.isEmpty) return null;
  if (userId is! String || userId.isEmpty) return null;
  if (on is! bool) return null;
  return TypingSignal(conversationId: conversationId, userId: userId, on: on);
}

/// The sending side of typing for ONE open conversation: throttled, and it
/// always ends with a "stop". Pure Dart with an injected sender so tests need
/// no network and no clock.
///
/// * First non-blank text sends "typing" at once.
/// * More keys re-send at most every [typingSendInterval].
/// * No key for [typingIdleStop], an empty/blank draft, [stop] (send, blur,
///   background, leaving the chat) all send one "stop" if "typing" was sent.
class TypingPublisher {
  TypingPublisher({
    required Future<void> Function(bool typing) send,
    DateTime Function() now = DateTime.now,
    this.sendInterval = typingSendInterval,
    this.idleStop = typingIdleStop,
  }) : _send = send,
       _now = now;

  final Future<void> Function(bool typing) _send;
  final DateTime Function() _now;
  final Duration sendInterval;
  final Duration idleStop;

  Timer? _idle;
  DateTime? _lastSent;
  bool _active = false;
  bool _disposed = false;

  /// Whether the other side currently believes this client is typing.
  bool get active => _active;

  /// The draft changed to [text].
  void draftChanged(String text) {
    if (_disposed) return;
    if (text.trim().isEmpty) {
      stop();
      return;
    }
    final now = _now();
    final last = _lastSent;
    if (!_active || last == null || now.difference(last) >= sendInterval) {
      _active = true;
      _lastSent = now;
      _fire(true);
    }
    _idle?.cancel();
    _idle = Timer(idleStop, stop);
  }

  /// The draft is gone, sent, unfocused or the app left the foreground.
  void stop() {
    _idle?.cancel();
    _idle = null;
    if (!_active) return;
    _active = false;
    _lastSent = null;
    _fire(false);
  }

  /// Leaving the chat: one last "stop" if needed, then nothing more.
  void dispose() {
    if (_disposed) return;
    stop();
    _disposed = true;
  }

  void _fire(bool typing) {
    // The signal is a hint: a failure is swallowed, never retried, never logged.
    _send(typing).catchError((Object _) {});
  }
}

/// Who is typing in one conversation, in the order they started, each with the
/// time their entry expires. Pure; the caller supplies the time.
class TypingRoster {
  TypingRoster({this.ttl = typingReceiverTtl});

  final Duration ttl;
  final Map<String, DateTime> _until = <String, DateTime>{};

  /// Typer ids in the order they started, oldest first.
  List<String> get ids => List<String>.unmodifiable(_until.keys);

  bool get isEmpty => _until.isEmpty;

  /// The soonest expiry, or null when nobody is typing.
  DateTime? get nextExpiry => _until.isEmpty
      ? null
      : _until.values.reduce((a, b) => a.isBefore(b) ? a : b);

  /// Applies [signal] heard at [now]. Returns whether the visible list changed.
  bool apply(TypingSignal signal, DateTime now) {
    if (!signal.on) return _until.remove(signal.userId) != null;
    final isNew = !_until.containsKey(signal.userId);
    // Re-adding keeps the original position: the label does not reshuffle.
    _until[signal.userId] = now.add(ttl);
    return isNew;
  }

  /// Drops every entry whose time has come. Returns whether any went.
  bool expire(DateTime now) {
    final gone = _until.entries
        .where((e) => !e.value.isAfter(now))
        .map((e) => e.key)
        .toList();
    gone.forEach(_until.remove);
    return gone.isNotEmpty;
  }

  /// Forgets [userId] (their message arrived). Returns whether they were in.
  bool remove(String userId) => _until.remove(userId) != null;

  /// Forgets everyone (the connection dropped or the chat closed).
  bool clear() {
    final had = _until.isNotEmpty;
    _until.clear();
    return had;
  }
}
