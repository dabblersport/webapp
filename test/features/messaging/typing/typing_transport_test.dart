import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/typing_transport.dart';

WorkerTypingTransport _transport(MockClient client) => WorkerTypingTransport(
  MessagingHttpClient(
    client: client,
    tokenSupplier: () async => 'token',
    baseUrl: 'https://worker.test',
  ),
);

void main() {
  const conversation = '11111111-1111-4111-8111-111111111111';

  test('posts the boolean to the typing route and nothing else', () async {
    final seen = <http.Request>[];
    final transport = _transport(
      MockClient((request) async {
        seen.add(request);
        return http.Response('', 204);
      }),
    );
    await transport.send(conversation, true);
    await transport.send(conversation, false);
    expect(seen, hasLength(2));
    expect(seen.first.method, 'POST');
    expect(seen.first.url.path, '/v1/conversations/$conversation/typing');
    expect(seen.first.body, '{"typing":true}');
    expect(seen.last.body, '{"typing":false}');
    expect(transport.unsupported, isFalse);
  });

  for (final status in <int>[404, 405, 501]) {
    test('a Worker without the route ($status): one request, then silence, '
        'no throw', () async {
      var calls = 0;
      final transport = _transport(
        MockClient((request) async {
          calls++;
          return http.Response('{"error":"not_found"}', status);
        }),
      );
      await transport.send(conversation, true);
      await transport.send(conversation, true);
      await transport.send(conversation, false);
      expect(calls, 1);
      expect(transport.unsupported, isTrue);
    });
  }

  test(
    'a refusal or a network failure is dropped and sending continues',
    () async {
      var calls = 0;
      final transport = _transport(
        MockClient((request) async {
          calls++;
          if (calls == 1) return http.Response('{"error":"forbidden"}', 403);
          if (calls == 2) throw http.ClientException('offline');
          return http.Response('', 204);
        }),
      );
      await transport.send(conversation, true);
      await transport.send(conversation, true);
      await transport.send(conversation, true);
      expect(calls, 3);
      expect(transport.unsupported, isFalse);
    },
  );
}
