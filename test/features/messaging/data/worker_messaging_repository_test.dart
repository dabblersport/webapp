import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/worker_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/message_page.dart';
import 'package:dabbler/features/messaging/domain/models/report_category.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

// Clearly-fake fixture; nothing here touches the network (MockClient).
const _base = 'https://worker.example.invalid';

const _conversation = {
  'id': 'c1',
  'kind': 'game',
  'game_id': 'g1',
  'writable': true,
  'muted': false,
  'last_seq': 3,
};
const _message = {
  'id': 'm1',
  'conversation_id': 'c1',
  'seq': 4,
  'kind': 'text',
  'body': 'hi',
  'created_at': '2026-10-01T10:00:00Z',
};
const _page = {
  'messages': [_message],
  'has_older': false,
  'has_newer': false,
  'page_size': 30,
};

/// Each operation: its call, its contract method/path, success status/body.
class _Op {
  const _Op(
    this.name,
    this.method,
    this.path,
    this.status,
    this.body,
    this.run,
  );
  final String name;
  final String method;
  final String path;
  final int status;
  final Object? body;
  final Future<Result<Object?, Failure>> Function(WorkerMessagingRepository r)
  run;
}

final _ops = <_Op>[
  _Op(
    'getGameConversation',
    'GET',
    '/v1/games/g1/conversation',
    200,
    _conversation,
    (r) => r.getGameConversation('g1'),
  ),
  _Op(
    'listMessages',
    'GET',
    '/v1/conversations/c1/messages',
    200,
    _page,
    (r) => r.listMessages(conversationId: 'c1'),
  ),
  _Op(
    'sendTextMessage',
    'POST',
    '/v1/conversations/c1/messages',
    201,
    _message,
    (r) => r.sendTextMessage(
      conversationId: 'c1',
      body: 'hi',
      idempotencyKey: _key,
    ),
  ),
  _Op(
    'reportMessage',
    'POST',
    '/v1/messages/m1/report',
    202,
    null,
    (r) => r.reportMessage(messageId: 'm1', reason: ReportCategory.spam),
  ),
  _Op(
    'muteConversation',
    'PUT',
    '/v1/conversations/c1/mute',
    204,
    null,
    (r) => r.muteConversation('c1'),
  ),
  _Op(
    'unmuteConversation',
    'DELETE',
    '/v1/conversations/c1/mute',
    204,
    null,
    (r) => r.unmuteConversation('c1'),
  ),
];

const _key = '3f1c2a9e-8b7d-4c6e-9a5f-0d1e2b3c4d5e';
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

typedef _Handler = Future<http.Response> Function(http.Request req);

class _Harness {
  _Harness(_Handler handler, {String? token = 'tok-1'}) : _tok = token {
    repo = WorkerMessagingRepository(
      http: MessagingHttpClient(
        client: MockClient((req) {
          requests.add(req);
          return handler(req);
        }),
        tokenSupplier: () async => _tok,
        baseUrl: _base,
        timeout: const Duration(milliseconds: 200),
      ),
      rpc: (fn, params) async {
        rpcCalls.add((fn, params));
        return rpcResult();
      },
    );
  }

  String? _tok;
  set token(String? t) => _tok = t;
  final requests = <http.Request>[];
  final rpcCalls = <(String, Map<String, dynamic>)>[];
  Object? Function() rpcResult = () => const <Object>[];
  late final WorkerMessagingRepository repo;
}

http.Response _json(int status, Object? body) => http.Response(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

MessagingFailure _failure(Result<Object?, Failure> r) {
  expect(r.isFailure, isTrue, reason: 'expected a failure, got $r');
  return r.requireError as MessagingFailure;
}

void main() {
  for (final op in _ops) {
    group(op.name, () {
      test(
        'success: method, path, base URL and bearer match the contract',
        () async {
          final h = _Harness((_) async => _json(op.status, op.body));
          final r = await op.run(h.repo);
          expect(r.isSuccess, isTrue, reason: '$r');
          final req = h.requests.single;
          expect(req.method, op.method);
          expect(req.url.path, op.path);
          expect('${req.url.scheme}://${req.url.host}', _base);
          expect(req.headers['Authorization'], 'Bearer tok-1');
          expect(req.url.queryParameters.containsKey('user_id'), isFalse);
        },
      );

      for (final reason in MessagingReason.values.where(
        (r) => r.isServerReason,
      )) {
        test('typed reason ${reason.wireName}', () async {
          final status = switch (reason.category) {
            FailureCode.conflict => 409,
            FailureCode.rateLimited => 429,
            FailureCode.notFound => 404,
            FailureCode.validation => 400,
            _ => 403,
          };
          final h = _Harness(
            (_) async => _json(status, {
              'error': {'reason': reason.wireName, 'retry_after_seconds': 5},
            }),
          );
          final f = _failure(await op.run(h.repo));
          expect(f.reason, reason);
          expect(f.httpStatus, status);
        });
      }

      test('401 -> unknown', () async {
        final h = _Harness((_) async => _json(401, {'error': {}}));
        final f = _failure(await op.run(h.repo));
        expect(f.reason, MessagingReason.unknown);
        expect(f.category, FailureCode.unauthorized);
      });

      test('5xx -> unknown', () async {
        final h = _Harness((_) async => _json(503, null));
        final f = _failure(await op.run(h.repo));
        expect(f.reason, MessagingReason.unknown);
        expect(f.category, FailureCode.server);
      });

      test('403 without a reason -> notInPilot, status kept', () async {
        final h = _Harness((_) async => _json(403, {'error': {}}));
        final f = _failure(await op.run(h.repo));
        expect(f.reason, MessagingReason.notInPilot);
        expect(f.httpStatus, 403);
      });

      test('network failure -> offline', () async {
        final h = _Harness((_) async => throw http.ClientException('down'));
        expect(_failure(await op.run(h.repo)).reason, MessagingReason.offline);
      });

      test('timeout -> offline', () async {
        final h = _Harness((_) => Completer<http.Response>().future);
        expect(_failure(await op.run(h.repo)).reason, MessagingReason.offline);
      });

      test('non-JSON body -> Failure, no throw', () async {
        final h = _Harness((_) async => http.Response('<html>', 502));
        expect(_failure(await op.run(h.repo)).reason, MessagingReason.unknown);
      });
    });
  }

  group('malformed success payloads -> Failure', () {
    for (final op in _ops.where((o) => o.body != null)) {
      test(op.name, () async {
        final h = _Harness((_) async => _json(op.status, {'id': 7}));
        expect(_failure(await op.run(h.repo)).reason, MessagingReason.unknown);
      });
    }
  });

  group('sendTextMessage', () {
    test('Idempotency-Key header present, UUID-shaped, body JSON', () async {
      final h = _Harness((_) async => _json(201, _message));
      await h.repo.sendTextMessage(
        conversationId: 'c1',
        body: 'hi',
        idempotencyKey: _key,
      );
      final req = h.requests.single;
      expect(req.headers['Idempotency-Key'], _key);
      expect(_uuid.hasMatch(req.headers['Idempotency-Key']!), isTrue);
      expect(jsonDecode(req.body), {'body': 'hi'});
    });

    test('200 duplicate returns the message', () async {
      final h = _Harness((_) async => _json(200, _message));
      final r = await h.repo.sendTextMessage(
        conversationId: 'c1',
        body: 'hi',
        idempotencyKey: _key,
      );
      expect(r.requireValue.id, 'm1');
    });
  });

  test('listMessages sends cursor, direction and limit', () async {
    final h = _Harness((_) async => _json(200, _page));
    await h.repo.listMessages(
      conversationId: 'c1',
      cursor: 9,
      direction: MessageDirection.newer,
      limit: 20,
    );
    expect(h.requests.single.url.queryParameters, {
      'cursor': '9',
      'direction': 'newer',
      'limit': '20',
    });
  });

  test('reportMessage body carries only the reason', () async {
    final h = _Harness((_) async => _json(202, null));
    await h.repo.reportMessage(messageId: 'm1', reason: ReportCategory.scam);
    expect(jsonDecode(h.requests.single.body), {'reason': 'scam'});
  });

  test('a changed token is used on the next call', () async {
    final h = _Harness((_) async => _json(204, null));
    await h.repo.muteConversation('c1');
    h.token = 'tok-2';
    await h.repo.muteConversation('c1');
    expect(h.requests[0].headers['Authorization'], 'Bearer tok-1');
    expect(h.requests[1].headers['Authorization'], 'Bearer tok-2');
  });

  test('no session -> no Authorization header (server answers 401)', () async {
    final h = _Harness((_) async => _json(401, null), token: null);
    final f = _failure(await h.repo.muteConversation('c1'));
    expect(h.requests.single.headers.containsKey('Authorization'), isFalse);
    expect(f.reason, MessagingReason.unknown);
  });

  test('base URL trailing slash is normalised', () {
    final c = MessagingHttpClient(
      client: MockClient((_) async => _json(204, null)),
      tokenSupplier: () async => null,
      baseUrl: '$_base/',
    );
    expect(c.uri('/x').toString(), '$_base/v1/x');
  });

  group('listMyConversations', () {
    const row = {'conversation_id': 'c1', 'game_id': 'g1', 'state': 'send'};

    test('calls the RPC constant with p_limit and parses rows', () async {
      final h = _Harness((_) async => _json(500, null));
      h.rpcResult = () => [row];
      final r = await h.repo.listMyConversations(limit: 20);
      expect(h.rpcCalls.single.$1, SupabaseConfig.msgMyConversationsRpc);
      expect(h.rpcCalls.single.$2, {'p_limit': 20});
      expect(r.requireValue.single.conversationId, 'c1');
      expect(h.requests, isEmpty);
    });

    test('no limit -> no p_limit', () async {
      final h = _Harness((_) async => _json(500, null));
      await h.repo.listMyConversations();
      expect(h.rpcCalls.single.$2, isEmpty);
    });

    test('malformed rows -> Failure', () async {
      final h = _Harness((_) async => _json(500, null));
      h.rpcResult = () => [
        {'conversation_id': 7},
      ];
      expect((await h.repo.listMyConversations()).isFailure, isTrue);
      h.rpcResult = () => 'nope';
      expect((await h.repo.listMyConversations()).isFailure, isTrue);
    });

    test('RPC throws -> Failure; ClientException -> offline', () async {
      final h = _Harness((_) async => _json(500, null));
      h.rpcResult = () => throw StateError('boom');
      expect(
        _failure(await h.repo.listMyConversations()).reason,
        MessagingReason.unknown,
      );
      h.rpcResult = () => throw http.ClientException('down');
      expect(
        _failure(await h.repo.listMyConversations()).reason,
        MessagingReason.offline,
      );
    });
  });
}
