import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/unavailable_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/worker_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/dm_failure.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

// KAN-562: the DM routes of the Worker (KAN-561, workers/messaging/src/dm.ts).
// Clearly-fake fixture; nothing here touches the network (MockClient).
const _base = 'https://worker.example.invalid';
const _other = '11111111-2222-4333-8444-555555555555';
const _conv = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

typedef _Handler = Future<http.Response> Function(http.Request req);

class _H {
  _H(_Handler handler) {
    repo = WorkerMessagingRepository(
      http: MessagingHttpClient(
        client: MockClient((req) {
          requests.add(req);
          return handler(req);
        }),
        tokenSupplier: () async => 'tok-1',
        baseUrl: _base,
        timeout: const Duration(milliseconds: 200),
      ),
      rpc: (fn, params) async => const <Object>[],
    );
  }
  final requests = <http.Request>[];
  late final WorkerMessagingRepository repo;
}

http.Response _json(int status, Object? body) => http.Response(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _reason(int status, String reason) => _json(status, {
  'error': {'reason': reason},
});

MessagingFailure _fail(Result<Object?, Failure> r) {
  expect(r.isFailure, isTrue, reason: '$r');
  return r.requireError as MessagingFailure;
}

typedef _Call =
    Future<Result<Object?, Failure>> Function(WorkerMessagingRepository r);

void main() {
  group('startDm', () {
    test(
      'POST /v1/dm with other_user_id and bearer -> conversation id',
      () async {
        final h = _H((_) async => _json(200, {'conversation_id': _conv}));
        final r = await h.repo.startDm(_other);
        expect(r.requireValue, _conv);
        final req = h.requests.single;
        expect(req.method, 'POST');
        expect(req.url.path, '/v1/dm');
        expect('${req.url.scheme}://${req.url.host}', _base);
        expect(req.headers['Authorization'], 'Bearer tok-1');
        expect(req.headers['Content-Type'], startsWith('application/json'));
        expect(jsonDecode(req.body), {'other_user_id': _other});
      },
    );

    test(
      'dm_cap_reached (429, as the Worker returns it) is a typed failure',
      () async {
        final h = _H((_) async => _reason(429, 'dm_cap_reached'));
        final f = _fail(await h.repo.startDm(_other));
        expect(f, isA<DmCapReachedFailure>());
        expect(f.httpStatus, dmCapReachedHttpStatus);
        expect(f.reason, MessagingReason.rateLimited);
        expect((f as DmCapReachedFailure).wireName, 'dm_cap_reached');
      },
    );

    final typed = <(int, String, MessagingReason)>[
      (403, 'blocked', MessagingReason.blocked),
      (403, 'not_in_pilot', MessagingReason.notInPilot),
      (404, 'not_found', MessagingReason.notFound),
      (400, 'invalid_request', MessagingReason.invalidRequest),
      (429, 'rate_limited', MessagingReason.rateLimited),
    ];
    for (final (status, wire, reason) in typed) {
      test('typed failure $wire ($status)', () async {
        final h = _H((_) async => _reason(status, wire));
        final f = _fail(await h.repo.startDm(_other));
        expect(f, isNot(isA<DmCapReachedFailure>()));
        expect(f.reason, reason);
        expect(f.httpStatus, status);
      });
    }

    test('malformed success body is a Failure', () async {
      for (final body in <Object?>[
        null,
        'x',
        {},
        {'conversation_id': 7},
        {'conversation_id': ''},
      ]) {
        final h = _H((_) async => _json(200, body));
        final f = _fail(await h.repo.startDm(_other));
        expect(f.reason, MessagingReason.unknown, reason: '$body');
      }
    });
  });

  group('setMuted', () {
    for (final muted in [true, false]) {
      test('POST /v1/conversations/{id}/mute with {muted: $muted}', () async {
        final h = _H((_) async => _json(200, {'muted': muted}));
        final r = await h.repo.setMuted(_conv, muted);
        expect(r.isSuccess, isTrue, reason: '$r');
        final req = h.requests.single;
        expect(req.method, 'POST');
        expect(req.url.path, '/v1/conversations/$_conv/mute');
        expect(req.headers['Authorization'], 'Bearer tok-1');
        expect(jsonDecode(req.body), {'muted': muted});
      });
    }

    test('typed failures map', () async {
      final h = _H((_) async => _reason(403, 'not_a_member'));
      expect(
        _fail(await h.repo.setMuted(_conv, true)).reason,
        MessagingReason.notAMember,
      );
    });

    test('malformed success body is a Failure', () async {
      final h = _H((_) async => _json(200, {'muted': 'yes'}));
      expect(
        _fail(await h.repo.setMuted(_conv, true)).reason,
        MessagingReason.unknown,
      );
    });
  });

  final calls = <String, _Call>{
    'startDm': (r) => r.startDm(_other),
    'setMuted': (r) => r.setMuted(_conv, true),
  };
  for (final e in calls.entries) {
    group('${e.key} transport failures', () {
      test('401 -> unknown, unauthorized', () async {
        final h = _H(
          (_) async => _json(401, {
            'error': {'message': 'token rejected'},
          }),
        );
        final f = _fail(await e.value(h.repo));
        expect(f.reason, MessagingReason.unknown);
        expect(f.category, FailureCode.unauthorized);
      });
      test('5xx -> unknown, server', () async {
        final h = _H(
          (_) async => _json(502, {
            'error': {'message': 'x'},
          }),
        );
        final f = _fail(await e.value(h.repo));
        expect(f.reason, MessagingReason.unknown);
        expect(f.category, FailureCode.server);
      });
      test('offline (ClientException) -> offline', () async {
        final h = _H((_) async => throw http.ClientException('down'));
        expect(_fail(await e.value(h.repo)).reason, MessagingReason.offline);
      });
      test('timeout -> offline', () async {
        final h = _H((_) => Completer<http.Response>().future);
        expect(_fail(await e.value(h.repo)).reason, MessagingReason.offline);
      });
      test('non-JSON body -> Failure, no throw', () async {
        final h = _H((_) async => http.Response('<html>', 200));
        expect(_fail(await e.value(h.repo)).reason, MessagingReason.unknown);
      });
    });
  }

  test('unavailable repository refuses both with not_in_pilot', () async {
    const u = UnavailableMessagingRepository();
    expect(_fail(await u.startDm(_other)).reason, MessagingReason.notInPilot);
    expect(
      _fail(await u.setMuted(_conv, true)).reason,
      MessagingReason.notInPilot,
    );
  });
}
