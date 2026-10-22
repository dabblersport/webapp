import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/receipts_transport.dart';
import 'package:dabbler/features/messaging/domain/receipt_summary.dart';

WorkerReceiptsTransport _transport(MockClient client) =>
    WorkerReceiptsTransport(
      MessagingHttpClient(
        client: client,
        tokenSupplier: () async => 'token',
        baseUrl: 'https://worker.test',
      ),
    );

class _Recorder implements ReceiptsTransport {
  final calls = <String>[];
  bool ok = true;

  @override
  Future<bool> ack(String c, ReceiptState s, int seq) async {
    calls.add('$c:${s.wire}:$seq');
    return ok;
  }

  @override
  Future<Map<int, ReceiptCounts>> summaries(String c, List<int> s) async =>
      const {};

  @override
  Future<List<RecipientReceipt>?> recipients(String c, int s) async => null;
}

void main() {
  const conversation = '11111111-1111-4111-8111-111111111111';

  test('posts state and through_seq to the receipts route', () async {
    final seen = <http.Request>[];
    final transport = _transport(
      MockClient((r) async {
        seen.add(r);
        return http.Response('{"advanced":true}', 200);
      }),
    );
    await transport.ack(conversation, ReceiptState.seen, 7);
    expect(seen.single.method, 'POST');
    expect(seen.single.url.path, '/v1/conversations/$conversation/receipts');
    expect(seen.single.body, '{"state":"seen","through_seq":7}');
  });

  for (final status in <int>[404, 405, 501]) {
    test('Worker without the route ($status): one request, then silence', () {
      var calls = 0;
      final transport = _transport(
        MockClient((r) async {
          calls++;
          return http.Response('', status);
        }),
      );
      return () async {
        await transport.ack(conversation, ReceiptState.delivered, 1);
        await transport.ack(conversation, ReceiptState.delivered, 2);
        await transport.ack(conversation, ReceiptState.seen, 2);
        expect(calls, 1);
        expect(transport.unsupported, isTrue);
      }();
    });
  }

  test('a failure is swallowed and acking continues', () async {
    var calls = 0;
    final transport = _transport(
      MockClient((r) async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return http.Response('', 500);
      }),
    );
    await transport.ack(conversation, ReceiptState.delivered, 1);
    await transport.ack(conversation, ReceiptState.delivered, 2);
    expect(calls, 2);
    expect(transport.unsupported, isFalse);
  });

  test(
    'a typed not_found 404 (route exists) does not switch receipts off',
    () async {
      var calls = 0;
      final transport = _transport(
        MockClient((r) async {
          calls++;
          return http.Response('{"error":{"reason":"not_found"}}', 404);
        }),
      );
      await transport.summaries(conversation, [3]);
      expect(transport.unsupported, isFalse);
      await transport.ack(conversation, ReceiptState.seen, 3);
      expect(calls, 2); // the ack still goes out after the 404 summary
      expect(transport.unsupported, isFalse);
    },
  );

  test('a lost acknowledgement is retried, not skipped', () async {
    final rec = _Recorder()..ok = false;
    final acker = ReceiptAcker(rec);
    await acker.seen(conversation, 5);
    rec.ok = true;
    await acker.seen(conversation, 5);
    await acker.seen(conversation, 5);
    expect(rec.calls, ['$conversation:seen:5', '$conversation:seen:5']);
  });

  test('a non-positive seq sends nothing', () async {
    var calls = 0;
    final transport = _transport(
      MockClient((r) async {
        calls++;
        return http.Response('', 200);
      }),
    );
    await transport.ack(conversation, ReceiptState.seen, 0);
    expect(calls, 0);
  });

  test('acker sends only higher seqs; seen raises delivered', () async {
    final rec = _Recorder();
    final acker = ReceiptAcker(rec);
    await acker.delivered(conversation, 3);
    await acker.delivered(conversation, 3);
    await acker.delivered(conversation, 2);
    await acker.seen(conversation, 5);
    await acker.seen(conversation, 4);
    await acker.delivered(conversation, 5);
    await acker.delivered(conversation, 6);
    expect(rec.calls, [
      '$conversation:delivered:3',
      '$conversation:seen:5',
      '$conversation:delivered:6',
    ]);
  });

  test('noop transport never throws', () async {
    await const NoopReceiptsTransport().ack(conversation, ReceiptState.seen, 9);
  });

  group('reads', () {
    test('summaries: GET ?seqs= and parses the counts', () async {
      final seen = <http.Request>[];
      final transport = _transport(
        MockClient((r) async {
          seen.add(r);
          return http.Response(
            '{"summaries":[{"seq":3,"recipients":4,"delivered_count":3,"seen_count":2},{"seq":"x"}]}',
            200,
          );
        }),
      );
      final out = await transport.summaries(conversation, [3, 5]);
      expect(seen.single.method, 'GET');
      expect(seen.single.url.path, '/v1/conversations/$conversation/receipts');
      expect(seen.single.url.queryParameters['seqs'], '3,5');
      expect(out.keys, [3]);
      expect(out[3]!.seen, 2);
      expect(out[3]!.delivered, 3);
      expect(out[3]!.total, 4);
    });

    for (final status in <int>[404, 405, 501]) {
      test('summaries $status: empty, then no more requests', () async {
        var calls = 0;
        final transport = _transport(
          MockClient((r) async {
            calls++;
            return http.Response('', status);
          }),
        );
        expect(await transport.summaries(conversation, [1]), isEmpty);
        expect(await transport.summaries(conversation, [1]), isEmpty);
        expect(await transport.recipients(conversation, 1), isNull);
        expect(calls, 1);
      });
    }

    test(
      'summaries: a network error or bad body is empty, never thrown',
      () async {
        final t1 = _transport(MockClient((r) async => throw Exception('x')));
        expect(await t1.summaries(conversation, [1]), isEmpty);
        final t2 = _transport(
          MockClient((r) async => http.Response('[]', 200)),
        );
        expect(await t2.summaries(conversation, [1]), isEmpty);
      },
    );

    test('recipients: GET /receipts/{seq} parses people', () async {
      final seen = <http.Request>[];
      final transport = _transport(
        MockClient((r) async {
          seen.add(r);
          return http.Response(
            '{"recipients":[{"user_id":"u1","state":"seen","updated_at":"2026-10-20T10:00:00Z"},{"user_id":"u2","state":"sent","updated_at":null},{"user_id":"u3","state":"bogus"}]}',
            200,
          );
        }),
      );
      final out = (await transport.recipients(conversation, 7))!;
      expect(
        seen.single.url.path,
        '/v1/conversations/$conversation/receipts/7',
      );
      expect(out.map((r) => r.userId), ['u1', 'u2']);
      expect(out.first.level, ReceiptLevel.seen);
      expect(out.first.updatedAt, DateTime.utc(2026, 10, 20, 10));
      expect(out.last.updatedAt, isNull);
    });

    test(
      'recipients 404 (not the sender) is null and does not latch',
      () async {
        var calls = 0;
        final transport = _transport(
          MockClient((r) async {
            calls++;
            return http.Response('{"error":{"reason":"not_found"}}', 404);
          }),
        );
        expect(await transport.recipients(conversation, 7), isNull);
        expect(await transport.recipients(conversation, 8), isNull);
        expect(calls, 2);
        expect(transport.unsupported, isFalse);
      },
    );
  });
}
