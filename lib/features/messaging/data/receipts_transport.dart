import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/domain/receipt_summary.dart';

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

  /// Delivered/seen counts for the caller's own messages [seqs]
  /// (`GET /conversations/{id}/receipts?seqs=`). Empty when the backend has
  /// no receipts or answers 404 (the Worker returns 404 for any seq the
  /// caller did not send); the messages then stay at Sent.
  Future<Map<int, ReceiptCounts>> summaries(
    String conversationId,
    List<int> seqs,
  );

  /// Who has received/seen the caller's message [seq]
  /// (`GET /conversations/{id}/receipts/{seq}`); null when unavailable.
  Future<List<RecipientReceipt>?> recipients(String conversationId, int seq);
}

/// One recipient's state for one message (the Message info drawer).
class RecipientReceipt {
  const RecipientReceipt({
    required this.userId,
    required this.level,
    this.updatedAt,
  });

  final String userId;
  final ReceiptLevel level;

  /// When this person's watermark last moved; null if it never has.
  final DateTime? updatedAt;
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

  @override
  Future<Map<int, ReceiptCounts>> summaries(
    String conversationId,
    List<int> seqs,
  ) async => const <int, ReceiptCounts>{};

  @override
  Future<List<RecipientReceipt>?> recipients(
    String conversationId,
    int seq,
  ) async => null;
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

  @override
  Future<Map<int, ReceiptCounts>> summaries(
    String conversationId,
    List<int> seqs,
  ) async {
    if (_unsupported || seqs.isEmpty) return const <int, ReceiptCounts>{};
    try {
      final response = await _http.send(
        'GET',
        '/conversations/${Uri.encodeComponent(conversationId)}/receipts',
        query: <String, String>{'seqs': seqs.take(100).join(',')},
      );
      if (_isUnsupported(response.status)) {
        _unsupported = true;
        return const <int, ReceiptCounts>{};
      }
      final body = response.body;
      final rows = body is Map ? body['summaries'] : null;
      if (response.status != 200 || rows is! List) {
        return const <int, ReceiptCounts>{};
      }
      final out = <int, ReceiptCounts>{};
      for (final r in rows) {
        if (r is! Map) continue;
        final seq = r['seq'];
        final total = r['recipients'];
        final delivered = r['delivered_count'];
        final seen = r['seen_count'];
        if (seq is int && total is int && delivered is int && seen is int) {
          out[seq] = ReceiptCounts(
            seen: seen,
            delivered: delivered,
            total: total,
          );
        }
      }
      return out;
    } catch (_) {
      return const <int, ReceiptCounts>{};
    }
  }

  @override
  Future<List<RecipientReceipt>?> recipients(
    String conversationId,
    int seq,
  ) async {
    if (_unsupported) return null;
    try {
      final response = await _http.send(
        'GET',
        '/conversations/${Uri.encodeComponent(conversationId)}/receipts/$seq',
      );
      final body = response.body;
      final rows = body is Map ? body['recipients'] : null;
      if (response.status != 200 || rows is! List) return null;
      final out = <RecipientReceipt>[];
      for (final r in rows) {
        if (r is! Map) continue;
        final id = r['user_id'];
        final level = switch (r['state']) {
          'seen' => ReceiptLevel.seen,
          'delivered' => ReceiptLevel.delivered,
          'sent' => ReceiptLevel.sent,
          _ => null,
        };
        final at = r['updated_at'];
        if (id is String && level != null) {
          out.add(
            RecipientReceipt(
              userId: id,
              level: level,
              updatedAt: at is String ? DateTime.tryParse(at) : null,
            ),
          );
        }
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  static bool _isUnsupported(int status) =>
      status == 404 || status == 405 || status == 501;
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
