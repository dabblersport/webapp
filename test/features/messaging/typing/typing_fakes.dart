import 'dart:async';

import 'package:dabbler/features/messaging/data/typing_transport.dart';
import 'package:dabbler/features/messaging/domain/typing.dart';

import '../realtime/fake_wake_channel.dart';

/// A [FakeWakeChannel] that also carries typing signals (KAN-579).
class FakeTypingChannel extends FakeWakeChannel {
  FakeTypingChannel(super.userId, {super.status});

  final _typing = StreamController<TypingSignal>.broadcast(sync: true);

  @override
  Stream<TypingSignal> get typing => _typing.stream;

  void emitTyping(TypingSignal signal) => _typing.add(signal);
}

/// What the server does with a typing call, as a model: only a CURRENT member
/// may signal, and the signal reaches the other current members' channels. The
/// real rules live in `msg_typing` (SQL, authored not applied) and
/// `workers/messaging/src/typing.ts` (tested in the Worker's own suite); this
/// stands in for them so two clients can be exercised without a network.
class TypingRelay {
  /// conversation id -> its current members.
  final Map<String, Set<String>> members = <String, Set<String>>{};
  final Map<String, FakeTypingChannel> channels = <String, FakeTypingChannel>{};

  /// Every call that reached the "server", for assertions.
  final List<({String from, String conversation, bool on})> calls = [];

  /// User ids that are offline: their calls never arrive.
  final Set<String> offline = <String>{};

  TypingTransport transportFor(String sender) => _RelayTransport(this, sender);

  Future<void> _send(String sender, String conversation, bool on) async {
    if (offline.contains(sender)) return;
    calls.add((from: sender, conversation: conversation, on: on));
    final current = members[conversation] ?? const <String>{};
    if (!current.contains(sender)) return; // removed / never a member
    for (final m in current) {
      if (m == sender) continue;
      channels[m]?.emitTyping(
        TypingSignal(conversationId: conversation, userId: sender, on: on),
      );
    }
  }
}

class _RelayTransport implements TypingTransport {
  _RelayTransport(this._relay, this._sender);

  final TypingRelay _relay;
  final String _sender;

  @override
  Future<void> send(String conversationId, bool typing) =>
      _relay._send(_sender, conversationId, typing);
}

/// Records what a client sends; nothing else.
class RecordingTypingTransport implements TypingTransport {
  final List<({String conversation, bool typing})> sent = [];

  @override
  Future<void> send(String conversationId, bool typing) async {
    sent.add((conversation: conversationId, typing: typing));
  }
}
