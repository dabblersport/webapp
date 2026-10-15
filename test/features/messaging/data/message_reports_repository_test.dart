// KAN-552: the Reports calls of the real repository, with FAKES ONLY: a
// MockClient for the Worker and a stub RPC caller. Nothing real is called.
import 'dart:async';
import 'dart:convert';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/worker_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/message_reports_repository.dart';
import 'package:dabbler/features/messaging/domain/models/message_report.dart';
import 'package:dabbler/features/messaging/domain/models/reported_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const _base = 'https://worker.example.invalid';
const _id = '11111111-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _secret = 'FAKE-REPORTED-TEXT';

class _Harness {
  _Harness(Future<http.Response> Function(http.Request) handler) {
    repo = WorkerMessagingRepository(
      http: MessagingHttpClient(
        client: MockClient((req) {
          requests.add(req);
          return handler(req);
        }),
        tokenSupplier: () async => 'tok-admin',
        baseUrl: _base,
        timeout: const Duration(milliseconds: 200),
      ),
      rpc: (fn, params) async {
        rpcCalls.add((fn, params));
        return rpcResult();
      },
    );
  }

  final requests = <http.Request>[];
  final rpcCalls = <(String, Map<String, dynamic>)>[];
  Object? Function() rpcResult = () => const <Object>[];
  late final WorkerMessagingRepository repo;
}

http.Response _json(int status, Object? body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

MessageReportsRefusal _refusal(Object? failure) =>
    (failure as MessageReportsFailure).refusal;

void main() {
  group('readReportedMessage (the audited Worker route)', () {
    test(
      'one GET to the moderation route with the admin token; only the text is kept',
      () async {
        final h = _Harness(
          (_) async => _json(200, {
            'report_id': _id,
            'message': {
              'id': 'm1',
              'conversation_id': 'c1',
              'seq': 4,
              'sender_user_id': 'u1',
              'kind': 'text',
              'body': _secret,
              'created_at': '2026-10-15T10:00:00Z',
            },
          }),
        );
        final r = await h.repo.readReportedMessage(_id);
        expect(r.isSuccess, isTrue);
        expect(r.requireValue.text, _secret);
        expect(r.requireValue.reportId, _id);
        final req = h.requests.single;
        expect(req.method, 'GET');
        expect(req.url.path, '/v1/moderation/reports/$_id/message');
        expect(req.headers['Authorization'], 'Bearer tok-admin');
        // The text never reaches a string form of the result.
        expect('${r.requireValue}', isNot(contains(_secret)));
        expect(r.requireValue.toString(), 'ReportedMessage($_id)');
      },
    );

    for (final c in <(int, String, MessageReportsRefusal)>[
      (403, 'not_a_moderator', MessageReportsRefusal.notAModerator),
      (404, 'not_found', MessageReportsRefusal.notFound),
      (429, 'rate_limited', MessageReportsRefusal.rateLimited),
    ]) {
      test(
        '${c.$1} ${c.$2} is a ${c.$3.name} refusal and carries no text',
        () async {
          final h = _Harness(
            (_) async => _json(c.$1, {
              'error': {'reason': c.$2, 'message': _secret},
            }),
          );
          final r = await h.repo.readReportedMessage(_id);
          expect(r.isFailure, isTrue);
          expect(_refusal(r.requireError), c.$3);
          // Even a server message that held text is not kept on the failure.
          expect('${r.requireError}', isNot(contains(_secret)));
          expect(r.requireError.message, isNot(contains(_secret)));
        },
      );
    }

    test(
      'a 5XX, a 401, a malformed body and a network error are failed',
      () async {
        for (final status in [500, 401]) {
          final h = _Harness(
            (_) async => _json(status, {
              'error': {'message': 'x'},
            }),
          );
          expect(
            _refusal((await h.repo.readReportedMessage(_id)).requireError),
            MessageReportsRefusal.failed,
          );
        }
        final malformed = _Harness(
          (_) async => _json(200, {
            'message': {'id': 'm1'},
          }),
        );
        expect(
          _refusal(
            (await malformed.repo.readReportedMessage(_id)).requireError,
          ),
          MessageReportsRefusal.failed,
        );
        final offline = _Harness(
          (_) async => throw http.ClientException('down'),
        );
        final r = await offline.repo.readReportedMessage(_id);
        expect(_refusal(r.requireError), MessageReportsRefusal.failed);
        expect((r.requireError).category, FailureCode.network);
        final slow = _Harness((_) => Completer<http.Response>().future);
        expect(
          _refusal((await slow.repo.readReportedMessage(_id)).requireError),
          MessageReportsRefusal.failed,
        );
      },
    );
  });

  group('listMessageReports (the admin RPC)', () {
    test('calls msg_list_message_reports and parses id-only rows', () async {
      final h = _Harness((_) async => _json(200, {}));
      h.rpcResult = () => [
        {
          'report_id': _id,
          'reason': 'spam',
          'created_at': '2026-10-15T09:00:00+00:00',
          'status': 'open',
          'target_message_id': '99999999-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          'conversation_id': null,
        },
      ];
      final r = await h.repo.listMessageReports(limit: 20);
      final rows = r.requireValue;
      expect(rows, hasLength(1));
      expect(rows.single.shortId, '11111111');
      expect(rows.single.reason, 'spam');
      expect(rows.single.status, 'open');
      expect(rows.single.createdAt.isUtc, isTrue);
      expect(h.rpcCalls.single.$1, 'msg_list_message_reports');
      expect(h.rpcCalls.single.$2, {'p_limit': 20});
      expect(h.requests, isEmpty); // the list never touches the Worker
    });

    test(
      'a non-admin (P0001 forbidden) is notAModerator; other errors are failed',
      () async {
        final h = _Harness((_) async => _json(200, {}));
        h.rpcResult = () =>
            throw const PostgrestException(message: 'forbidden', code: 'P0001');
        expect(
          _refusal((await h.repo.listMessageReports()).requireError),
          MessageReportsRefusal.notAModerator,
        );
        h.rpcResult = () =>
            throw const PostgrestException(message: 'boom', code: '500');
        expect(
          _refusal((await h.repo.listMessageReports()).requireError),
          MessageReportsRefusal.failed,
        );
        h.rpcResult = () => 'not a list';
        expect(
          _refusal((await h.repo.listMessageReports()).requireError),
          MessageReportsRefusal.failed,
        );
        h.rpcResult = () => throw TimeoutException('slow');
        final r = await h.repo.listMessageReports();
        expect(_refusal(r.requireError), MessageReportsRefusal.failed);
        expect(r.requireError.category, FailureCode.network);
      },
    );

    test('a row model has no field that could hold names or text', () {
      final r = MessageReport(
        reportId: _id,
        reason: 'spam',
        createdAt: _epoch,
        status: 'open',
      );
      expect(r.props.length, 4);
      expect(
        const ReportedMessage(reportId: _id, text: _secret) ==
            const ReportedMessage(reportId: _id, text: 'other'),
        isTrue,
      );
    });
  });

  group('the fake repository', () {
    test(
      'lists newest first, reads once per call, counts reads, scripts refusals',
      () async {
        final fake = FakeMessagingRepository()
          ..seedMessageReports(
            [
              MessageReport(
                reportId: 'a',
                reason: 'spam',
                createdAt: DateTime.utc(2026, 10, 1),
                status: 'open',
              ),
              MessageReport(
                reportId: 'b',
                reason: 'abuse',
                createdAt: DateTime.utc(2026, 10, 2),
                status: 'open',
              ),
            ],
            texts: {'a': 'ta', 'b': 'tb'},
          );
        expect(
          (await fake.listMessageReports()).requireValue.map((r) => r.reportId),
          ['b', 'a'],
        );
        expect((await fake.readReportedMessage('a')).requireValue.text, 'ta');
        expect((await fake.readReportedMessage('a')).requireValue.text, 'ta');
        expect(fake.reportedMessageReads, ['a', 'a']);
        fake.failNextReportedMessageRead(MessageReportsRefusal.rateLimited);
        expect(
          _refusal((await fake.readReportedMessage('b')).requireError),
          MessageReportsRefusal.rateLimited,
        );
        expect((await fake.readReportedMessage('b')).isSuccess, isTrue);
        expect(
          _refusal((await fake.readReportedMessage('zzz')).requireError),
          MessageReportsRefusal.notFound,
        );
      },
    );
  });
}

final _epoch = DateTime.utc(2026);
