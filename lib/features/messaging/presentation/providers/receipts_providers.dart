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

/// The delivered/seen counts of the caller's own messages in one open
/// conversation, keyed by seq (KAN-580). Empty until the Worker answers; an
/// old Worker, a fake backend or any failure leaves it empty and every
/// message at Sent. It never writes anything.
class ReceiptCountsNotifier extends StateNotifier<Map<int, ReceiptCounts>> {
  ReceiptCountsNotifier(this._transport, this._conversationId)
    : super(const <int, ReceiptCounts>{});

  final ReceiptsTransport _transport;
  final String _conversationId;
  bool _busy = false;

  /// Re-reads the counts for [seqs] (the caller's own message seqs, any
  /// order). Seqs every recipient has already seen are final and skipped.
  Future<void> refresh(Iterable<int> seqs) async {
    if (_busy || _conversationId.isEmpty) return;
    final open = (seqs.toSet().toList()..sort())
        .where((s) => !(state[s]?.seenByEveryone ?? false))
        .toList();
    if (open.isEmpty) return;
    final wanted = open.length > 100 ? open.sublist(open.length - 100) : open;
    _busy = true;
    try {
      final fresh = await _transport.summaries(_conversationId, wanted);
      if (!mounted || fresh.isEmpty) return;
      state = <int, ReceiptCounts>{...state, ...fresh};
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
