import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/receipts_transport.dart';
import 'package:dabbler/features/messaging/domain/receipt_summary.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_realtime_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

/// Where the user's delivered/seen acknowledgements go (KAN-580). Only the
/// real Worker backend with Realtime on sends anything; everything else is
/// [NoopReceiptsTransport] and messages stay at Sent. Tests override it.
final receiptsTransportProvider = Provider<ReceiptsTransport>((ref) {
  if (!ref.watch(messagingRealtimeEnabledProvider)) {
    return const NoopReceiptsTransport();
  }
  if (ref.watch(messagingBackendKindProvider) != MessagingBackendKind.worker) {
    return const NoopReceiptsTransport();
  }
  return WorkerReceiptsTransport(
    MessagingHttpClient(
      client: ref.watch(messagingHttpClientProvider),
      tokenSupplier: ref.watch(messagingTokenSupplierProvider),
      baseUrl: ref.watch(messagingBackendConfigProvider).baseUrl,
    ),
  );
});

/// One acker for the app run, so its "already acknowledged" marks outlive a
/// closed and reopened thread.
final receiptAckerProvider = Provider<ReceiptAcker>(
  (ref) => ReceiptAcker(ref.watch(receiptsTransportProvider)),
);

/// How often an open thread re-reads its delivered/seen counts (seconds);
/// receipts have no push channel.
const int receiptsRefreshSeconds = 20;

/// The shortest gap between two reads of the same seqs (seconds, KAN-929);
/// below [receiptsRefreshSeconds] so the poll always gets through.
const int receiptsMinRepeatSeconds = 5;

/// The delivered/seen counts of the caller's own messages in one open
/// conversation, keyed by seq (KAN-580). Empty until the Worker answers; an
/// old Worker, a fake backend or any failure leaves it empty and every
/// message at Sent. It never writes anything.
class ReceiptCountsNotifier extends StateNotifier<Map<int, ReceiptCounts>> {
  ReceiptCountsNotifier(
    this._transport,
    this._conversationId, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const <int, ReceiptCounts>{});

  /// The same seqs are not re-read sooner than this (KAN-929).
  static const Duration minRepeat = Duration(seconds: receiptsMinRepeatSeconds);

  final ReceiptsTransport _transport;
  final String _conversationId;
  final DateTime Function() _now;
  bool _busy = false;
  List<int>? _lastWanted;
  DateTime? _lastAt;

  /// Re-reads the counts for [seqs] (the caller's own message seqs, any
  /// order). Seqs every recipient has already seen are final and skipped.
  Future<void> refresh(Iterable<int> seqs) async {
    if (_busy || _conversationId.isEmpty) return;
    final open = (seqs.toSet().toList()..sort())
        .where((s) => !(state[s]?.seenByEveryone ?? false))
        .toList();
    if (open.isEmpty) return;
    final wanted = open.length > 100 ? open.sublist(open.length - 100) : open;
    final at = _now();
    if (_lastAt != null &&
        listEquals(wanted, _lastWanted) &&
        at.difference(_lastAt!) < minRepeat) {
      return;
    }
    _lastWanted = wanted;
    _lastAt = at;
    _busy = true;
    try {
      final fresh = await _transport.summaries(_conversationId, wanted);
      if (!mounted || fresh.isEmpty) return;
      // An unchanged answer leaves the state alone, so nothing rebuilds.
      final changed = fresh.entries.any((e) {
        final old = state[e.key];
        return old == null ||
            old.seen != e.value.seen ||
            old.delivered != e.value.delivered ||
            old.total != e.value.total;
      });
      if (changed) state = <int, ReceiptCounts>{...state, ...fresh};
    } finally {
      _busy = false;
    }
  }
}

final receiptCountsProvider = StateNotifierProvider.autoDispose
    .family<ReceiptCountsNotifier, Map<int, ReceiptCounts>, String>(
      (ref, conversationId) => ReceiptCountsNotifier(
        ref.watch(receiptsTransportProvider),
        conversationId,
      ),
    );

/// Who has received/seen one of the caller's messages, for the Message info
/// drawer. Null when the Worker cannot say.
final receiptRecipientsProvider = FutureProvider.autoDispose
    .family<List<RecipientReceipt>?, ({String conversationId, int seq})>(
      (ref, key) => ref
          .watch(receiptsTransportProvider)
          .recipients(key.conversationId, key.seq),
    );

/// How the Message info drawer turns a user id into a display name; an empty
/// string means unknown. Tests override it.
final receiptPersonNameProvider = Provider<Future<String> Function(String)>((
  ref,
) {
  final repo = ref.watch(profileRepositoryProvider);
  return (userId) async {
    final result = await repo.getProfile(userId);
    return result.fold((_) => '', (p) => p.displayName);
  };
});
