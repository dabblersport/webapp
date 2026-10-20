import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/receipts_transport.dart';

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

  @override
  Future<void> ack(String c, ReceiptState s, int seq) async =>
      calls.add('$c:${s.wire}:$seq');
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
    await const NoopReceiptsTransport().ack(
      conversation,
      ReceiptState.seen,
      9,
    );
  });
}
