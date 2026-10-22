import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/messaging_wake_channel.dart';
import 'package:dabbler/features/messaging/data/typing_transport.dart';
import 'package:dabbler/features/messaging/domain/typing.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_realtime_providers.dart';

/// The clock the typing roster expires against. Overridable so a test moves
/// time by hand.
final typingClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Where the user's own typing state goes (KAN-579). Only the real Worker
/// backend with Realtime on sends anything; the fake, an unavailable backend
/// and a build with Realtime off use [NoopTypingTransport]. Tests override it.
final typingTransportProvider = Provider<TypingTransport>((ref) {
  if (!ref.watch(messagingRealtimeEnabledProvider)) {
    return const NoopTypingTransport();
  }
  if (ref.watch(messagingBackendKindProvider) != MessagingBackendKind.worker) {
    return const NoopTypingTransport();
  }
  return WorkerTypingTransport(
    MessagingHttpClient(
      client: ref.watch(messagingHttpClientProvider),
      tokenSupplier: ref.watch(messagingTokenSupplierProvider),
      baseUrl: ref.watch(messagingBackendConfigProvider).baseUrl,
    ),
  );
});

/// Who is typing in one conversation (arg: the conversation id): user ids in
/// the order they started, never the signed-in user. Fed by the user's private
/// Realtime channel; nothing is stored. An entry leaves when
///
/// * the typer sends "stop";
/// * [typingReceiverTtl] passes without another "typing" (stale: airplane
///   mode, a killed app, a lost stop);
/// * the channel leaves SUBSCRIBED (disconnect; on reconnect the list starts
///   empty and fills only from signals heard after it);
/// * [clearFor] is called because that person's message arrived.
final typingPresenceProvider = NotifierProvider.autoDispose
    .family<TypingPresence, List<String>, String>(TypingPresence.new);

class TypingPresence extends AutoDisposeFamilyNotifier<List<String>, String> {
  final TypingRoster _roster = TypingRoster();
  Timer? _expiry;

  @override
  List<String> build(String arg) {
    _roster.clear();
    _expiry?.cancel();
    ref.onDispose(() => _expiry?.cancel());
    final channel = ref.watch(messagingWakeChannelProvider);
    if (channel == null) return const <String>[];
    final self = ref.watch(messagingUserIdProvider).valueOrNull;
    final subscriptions = <StreamSubscription<Object?>>[
      channel.typing.listen((signal) => _onSignal(signal, self)),
      channel.statuses.listen((status) {
        if (status != WakeChannelStatus.subscribed) _clear();
      }),
    ];
    ref.onDispose(() {
      for (final s in subscriptions) {
        s.cancel();
      }
    });
    return const <String>[];
  }

  void _onSignal(TypingSignal signal, String? self) {
    if (signal.conversationId != arg) return;
    if (signal.userId == self) return; // never show the user to themselves
    final now = ref.read(typingClockProvider)();
    if (_roster.apply(signal, now)) _publish();
    _schedule();
  }

  /// A message from [userId] arrived: they are no longer "typing".
  void clearFor(String userId) {
    if (_roster.remove(userId)) {
      _publish();
      _schedule();
    }
  }

  void _clear() {
    if (_roster.clear()) _publish();
    _expiry?.cancel();
  }

  void _publish() => state = _roster.ids;

  void _schedule() {
    _expiry?.cancel();
    final next = _roster.nextExpiry;
    if (next == null) return;
    final now = ref.read(typingClockProvider)();
    var wait = next.difference(now);
    const floor = Duration(milliseconds: typingMinTimerMs);
    if (wait < floor) wait = floor;
    _expiry = Timer(wait, () {
      if (_roster.expire(ref.read(typingClockProvider)())) _publish();
      _schedule();
    });
  }
}
