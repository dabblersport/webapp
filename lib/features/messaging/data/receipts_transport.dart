import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:dabbler/features/messaging/data/messaging_http_client.dart';

/// Which watermark an acknowledgement advances (KAN-580).
enum ReceiptState {
  delivered,
  seen;

  String get wire => name;
}

/// Tells the backend how far the signed-in user has received or seen a
/// conversation. Fire-and-forget: a lost acknowledgement is repaired by the
/// next, higher one, so a failure is swallowed.
abstract class ReceiptsTransport {
  Future<void> ack(String conversationId, ReceiptState state, int throughSeq);
}

/// No receipts: the fake backend, a build without a base URL, Realtime off.
/// Messages then stay at Sent.
class NoopReceiptsTransport implements ReceiptsTransport {
  const NoopReceiptsTransport();

  @override
  Future<void> ack(
    String conversationId,
    ReceiptState state,
    int throughSeq,
  ) async {}
}

/// `POST /v1/conversations/{id}/receipts {state, through_seq}` on the
/// messaging Worker (`workers/messaging/src/receipts.ts`).
class WorkerReceiptsTransport implements ReceiptsTransport {
  WorkerReceiptsTransport(this._http);

  final MessagingHttpClient _http;

  bool _unsupported = false;

  /// Set when the Worker answers 404, 405 or 501: a Worker deployed before
  /// KAN-580. Nothing is acknowledged again until the app restarts, so a
  /// backend without receipts costs one request (same latch as KAN-579).
  @visibleForTesting
  bool get unsupported => _unsupported;

  @override
  Future<void> ack(
    String conversationId,
    ReceiptState state,
    int throughSeq,
  ) async {
    if (_unsupported || throughSeq <= 0) return;
    try {
      final response = await _http.send(
        'POST',
        '/conversations/${Uri.encodeComponent(conversationId)}/receipts',
        jsonBody: <String, Object>{
          'state': state.wire,
          'through_seq': throughSeq,
        },
      );
      if (response.status == 404 ||
          response.status == 405 ||
          response.status == 501) {
        _unsupported = true;
      }
    } catch (_) {
      // Repaired by the next acknowledgement.
    }
  }
}

/// Decides what is worth sending. Per conversation it remembers the highest
/// seq already acknowledged for each state and sends only a higher one, so
/// re-renders, retries and a reopened thread do not repeat requests. Seen
/// implies delivered, so a seen ack also raises the delivered mark.
class ReceiptAcker {
  ReceiptAcker(this._transport);

  final ReceiptsTransport _transport;
  final Map<String, int> _delivered = <String, int>{};
  final Map<String, int> _seen = <String, int>{};

  /// Messages up to [throughSeq] arrived on this device.
  Future<void> delivered(String conversationId, int throughSeq) async {
    if (throughSeq <= (_delivered[conversationId] ?? 0)) return;
    _delivered[conversationId] = throughSeq;
    await _transport.ack(conversationId, ReceiptState.delivered, throughSeq);
  }

  /// Messages up to [throughSeq] were visible to the user.
  Future<void> seen(String conversationId, int throughSeq) async {
    if (throughSeq <= (_seen[conversationId] ?? 0)) return;
    _seen[conversationId] = throughSeq;
    if (throughSeq > (_delivered[conversationId] ?? 0)) {
      _delivered[conversationId] = throughSeq;
    }
    await _transport.ack(conversationId, ReceiptState.seen, throughSeq);
  }
}
