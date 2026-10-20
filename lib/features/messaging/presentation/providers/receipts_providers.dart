import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/receipts_transport.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_realtime_providers.dart';

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
