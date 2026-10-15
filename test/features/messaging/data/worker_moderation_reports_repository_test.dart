import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/fake_moderation_reports_repository.dart';
import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/unavailable_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/worker_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/report_row.dart';
import 'package:dabbler/features/messaging/domain/moderation_reports_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

// KAN-552. Clearly-fake fixtures; MockClient and a fake RPC caller, no network.
const _base = 'https://worker.example.invalid';
const _report = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const _msg = '11111111-2222-4333-8444-555555555555';

class _H {
  _H({
    Future<http.Response> Function(http.Request)? handler,
    Object? rpcResult,
    Object? rpcThrows,
  }) {
    repo = WorkerMessagingRepository(
      http: MessagingHttpClient(
        client: MockClient((req) async {
          requests.add(req);
          return handler!(req);
        }),
        tokenSupplier: () async => 'tok-admin',
        baseUrl: _base,
        timeout: const Duration(milliseconds: 200),
      ),
      rpc: (fn, params) async {
        rpcCalls.add((fn, params));
        if (rpcThrows != null) throw rpcThrows;
        return rpcResult;
      },
    );
  }
  final requests = <http.Request>[];
  final rpcCalls = <(String, Map<String, dynamic>)>[];
  late final WorkerMessagingRepository repo;
}

http.Response _json(int status, Object? body) => http.Response(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _row(String id, {String reason = 'spam'}) => {
  'report_id': id,
  'reason': reason,
  'created_at': '2026-10-15T10:00:00Z',
  'status': 'open',
  'target_message_id': _msg,
  'conversation_id': null,
};

void main() {
  group('listMessageReports (RPC)', () {
    test('calls msg_list_message_reports and parses rows in order', () async {
      final h = _H(
        rpcResult: [
          _row('r2'),
          _row('r1', reason: 'scam'),
        ],
      );
      final r = await h.repo.listMessageReports(limit: 20);
      expect(h.rpcCalls.single.$1, SupabaseConfig.msgListMessageReportsRpc);
      expect(h.rpcCalls.single.$1, 'msg_list_message_reports');
      expect(h.rpcCalls.single.$2, {'p_limit': 20});
      final rows = r.requireValue;
      expect(rows.map((e) => e.reportId), ['r2', 'r1']);
      expect(rows.last.reason, 'scam');
      expect(rows.first.conversationId, isNull);
      expect(rows.first.createdAt, DateTime.utc(2026, 10, 15, 10));
    });

    test('a malformed row or payload is a Failure, never a throw', () async {
      for (final bad in <Object?>[
        null,
        {'x': 1},
        [
          {'report_id': 'r1'},
        ],
        [
          {..._row('r1'), 'created_at': 'not a date'},
        ],
        [42],
      ]) {
        final r = await _H(rpcResult: bad).repo.listMessageReports();
        expect(r.isFailure, isTrue, reason: '$bad');
        expect(r.requireError, isA<MessagingFailure>());
      }
    });

    test('a thrown RPC (non-admin P0001 forbidden) is a Failure', () async {
      final r = await _H(
        rpcThrows: Exception('forbidden'),
      ).repo.listMessageReports();
      expect(r.isFailure, isTrue);
    });
  });

  group('readReportedMessage (Worker)', () {
    test('GET /v1/moderation/reports/{id}/message with bearer', () async {
      final h = _H(
        handler: (_) async => _json(200, {
          'report_id': _report,
          'message': {
            'id': _msg,
            'conversation_id': 'c',
            'seq': 3,
            'sender_user_id': 'u',
            'kind': 'text',
            'body': 'FAKE reported text',
            'created_at': '2026-10-15T10:00:00Z',
          },
        }),
      );
      final r = await h.repo.readReportedMessage(_report);
      final req = h.requests.single;
      expect(req.method, 'GET');
      expect(req.url.path, '/v1/moderation/reports/$_report/message');
      expect(req.headers['Authorization'], 'Bearer tok-admin');
      final m = r.requireValue;
      expect(m.body, 'FAKE reported text');
      expect(m.messageId, _msg);
      expect(m.toString(), isNot(contains('FAKE')));
    });

    test('403 not_a_moderator -> NotAModeratorFailure', () async {
      final h = _H(
        handler: (_) async => _json(403, {
          'error': {'reason': 'not_a_moderator', 'message': 'no'},
        }),
      );
      final f = (await h.repo.readReportedMessage(_report)).requireError;
      expect(f, isA<NotAModeratorFailure>());
      expect((f as MessagingFailure).httpStatus, 403);
      expect(f.category, FailureCode.forbidden);
    });

    test('404 not_found and 429 rate_limited map to typed reasons', () async {
      Future<Failure> run(int s, String reason) async => (await _H(
        handler: (_) async => _json(s, {
          'error': {'reason': reason},
        }),
      ).repo.readReportedMessage(_report)).requireError;
      final nf = await run(404, 'not_found') as MessagingFailure;
      expect(nf.reason, MessagingReason.notFound);
      final rl = await run(429, 'rate_limited') as MessagingFailure;
      expect(rl.reason, MessagingReason.rateLimited);
    });

    test('malformed 200 and 5XX are Failures, never throws', () async {
      for (final resp in [
        _json(200, {'report_id': _report}),
        _json(200, null),
        _json(502, {
          'error': {'reason': 'upstream'},
        }),
        http.Response('not json', 200),
      ]) {
        final r = await _H(
          handler: (_) async => resp,
        ).repo.readReportedMessage(_report);
        expect(r.isFailure, isTrue);
      }
    });
  });

  test('unavailable repository fails both, calling nothing', () async {
    const u = UnavailableMessagingRepository();
    expect((await u.listMessageReports()).isFailure, isTrue);
    expect((await u.readReportedMessage(_report)).isFailure, isTrue);
  });

  test('fake repository counts calls, orders newest first', () async {
    final f = FakeModerationReportsRepository()
      ..seedReports([
        ReportRow(
          reportId: 'old',
          reason: 'spam',
          createdAt: DateTime.utc(2026, 1, 1),
          status: 'open',
          targetMessageId: 'm1',
        ),
        ReportRow(
          reportId: 'new',
          reason: 'spam',
          createdAt: DateTime.utc(2026, 2, 1),
          status: 'open',
          targetMessageId: 'm2',
        ),
      ])
      ..seedBody('new', 'x');
    final list = await f.listMessageReports();
    expect(list.requireValue.map((r) => r.reportId), ['new', 'old']);
    final read = await f.readReportedMessage('new');
    expect(read, isA<Ok<ReportedMessage, Failure>>());
    expect(f.readCalls, 1);
    expect(f.readIds, ['new']);
    expect((await f.readReportedMessage('old')).isFailure, isTrue);
  });
}
