import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Where the wake channel is (KAN-544). `closed` covers a channel error, a
/// timeout and a close: the chat then polls at its normal cadence.
enum WakeChannelStatus { connecting, subscribed, closed }

/// A Realtime wake-up: a HINT that a conversation has something new. It never
/// carries message text. [seq] is the new message's sequence number, or null
/// for a `sync` wake (several things changed; fetch to find out).
class MessagingWake {
  const MessagingWake({required this.conversationId, this.seq});

  final String conversationId;
  final int? seq;
}

/// One private Realtime channel for the signed-in user (`user:<uid>`).
abstract class WakeChannel {
  /// Broadcast stream of wakes.
  Stream<MessagingWake> get wakes;

  /// Broadcast stream of status changes (not replayed).
  Stream<WakeChannelStatus> get statuses;

  /// The current status.
  WakeChannelStatus get status;

  /// Removes the channel. Safe to call twice.
  Future<void> close();
}

/// Builds the channel of one user.
typedef WakeChannelFactory = WakeChannel Function(String userId);

/// Reads one broadcast payload into a wake, or null when it is not one. The
/// platform delivers `{event, payload: {...}, type}`; the keys we sent
/// (`type`, `conversation_id`, `seq`, plus the platform's `id`) are inside
/// `payload`. Nothing here ever reads, keeps or logs anything else.
MessagingWake? parseWake(Map<String, dynamic> raw) {
  final inner = raw['payload'];
  final body = inner is Map ? Map<String, dynamic>.from(inner) : raw;
  final conversationId = body['conversation_id'];
  if (conversationId is! String || conversationId.isEmpty) return null;
  final type = body['type'];
  if (type == 'sync') return MessagingWake(conversationId: conversationId);
  if (type != 'msg') return null;
  final seq = body['seq'];
  if (seq is! num || seq < 1) return null;
  return MessagingWake(conversationId: conversationId, seq: seq.toInt());
}

/// The Supabase channel `user:<uid>`, private, listening for broadcast event
/// `msg`. The Supabase client already calls `realtime.setAuth` on every token
/// refresh and sign-in (supabase 2.10.2, `_handleTokenChanged`), so this class
/// does not repeat it. No other table or channel is touched.
class SupabaseWakeChannel implements WakeChannel {
  SupabaseWakeChannel(this._client, String userId) {
    _channel = _client.channel(
      'user:$userId',
      opts: const RealtimeChannelConfig(private: true),
    );
    _channel
        .onBroadcast(event: 'msg', callback: _onBroadcast)
        .subscribe(_onStatus);
  }

  final SupabaseClient _client;
  late final RealtimeChannel _channel;
  final _wakes = StreamController<MessagingWake>.broadcast();
  final _statuses = StreamController<WakeChannelStatus>.broadcast();
  var _status = WakeChannelStatus.connecting;
  var _closed = false;

  @override
  Stream<MessagingWake> get wakes => _wakes.stream;

  @override
  Stream<WakeChannelStatus> get statuses => _statuses.stream;

  @override
  WakeChannelStatus get status => _status;

  void _onBroadcast(Map<String, dynamic> payload) {
    if (_closed) return;
    final wake = parseWake(payload);
    if (wake != null) _wakes.add(wake);
  }

  void _onStatus(RealtimeSubscribeStatus status, Object? error) {
    if (_closed) return;
    _status = status == RealtimeSubscribeStatus.subscribed
        ? WakeChannelStatus.subscribed
        : WakeChannelStatus.closed;
    _statuses.add(_status);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _status = WakeChannelStatus.closed;
    await _client.removeChannel(_channel);
    await _wakes.close();
    await _statuses.close();
  }
}
