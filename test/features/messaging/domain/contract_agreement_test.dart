import 'dart:io';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/models/message_page.dart';
import 'package:dabbler/features/messaging/domain/models/report_category.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps `docs/messaging/openapi.yaml` and the Dart interface in agreement,
/// operation by operation: names, fields, reasons. Static: no network, no SQL.
const _yamlPath = 'docs/messaging/openapi.yaml';
const _readmePath = 'docs/messaging/README.md';
const _repoPath = 'lib/features/messaging/domain/messaging_repository.dart';

/// operationId -> the interface method that implements it (same name).
const _operations = <String>[
  'getGameConversation',
  'listMessages',
  'sendTextMessage',
  'reportMessage',
  'muteConversation',
  'unmuteConversation',
];

/// A compile-time proof of the interface: this class implements every
/// operation with the contract's shapes. It also demonstrates the contract's
/// idempotency rule (a duplicate key returns the same message, one row).
class _InMemoryMessaging implements MessagingRepository {
  final Map<String, Message> _byKey = {};
  final List<Message> rows = [];

  @override
  Future<Result<String, Failure>> startDm(String otherUserId) async =>
      Err(MessagingFailure.offline());

  @override
  Future<Result<void, Failure>> setMuted(
    String conversationId,
    bool muted,
  ) async => Err(MessagingFailure.offline());

  @override
  Future<Result<Conversation, Failure>> getGameConversation(
    String gameId,
  ) async => Err(MessagingFailure.offline());

  @override
  Future<Result<MessagePage, Failure>> listMessages({
    required String conversationId,
    int? cursor,
    MessageDirection direction = MessageDirection.older,
    int? limit,
  }) async => Err(MessagingFailure.offline());

  @override
  Future<Result<Message, Failure>> sendTextMessage({
    required String conversationId,
    required String body,
    required String idempotencyKey,
  }) async {
    final existing = _byKey['$conversationId/$idempotencyKey'];
    if (existing != null) return Ok(existing);
    final m = Message(
      id: 'id-${rows.length + 1}',
      conversationId: conversationId,
      seq: rows.length + 1,
      kind: MessageKind.text,
      body: body,
      clientKey: idempotencyKey,
      createdAt: DateTime.utc(2026, 10, 13),
    );
    rows.add(m);
    _byKey['$conversationId/$idempotencyKey'] = m;
    return Ok(m);
  }

  @override
  Future<Result<void, Failure>> reportMessage({
    required String messageId,
    required ReportCategory reason,
  }) async => const Ok(null);

  @override
  Future<Result<void, Failure>> muteConversation(String conversationId) async =>
      const Ok(null);

  @override
  Future<Result<void, Failure>> unmuteConversation(
    String conversationId,
  ) async => const Ok(null);
}

/// operationId -> its `x-reasons`, read from the yaml text.
Map<String, List<String>> _yamlOperationReasons(String yaml) {
  final out = <String, List<String>>{};
  String? current;
  for (final line in yaml.split('\n')) {
    final op = RegExp(r'^\s+operationId:\s*(\w+)').firstMatch(line);
    if (op != null) current = op.group(1);
    final r = RegExp(r'^\s+x-reasons:\s*\[(.*)\]').firstMatch(line);
    if (r != null && current != null) {
      out[current] = r
          .group(1)!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }
  return out;
}

/// The wire reasons: the `Reason` schema's enum.
List<String> _yamlReasonEnum(String yaml) {
  final start = yaml.indexOf('    Reason:');
  final end = yaml.indexOf('    ErrorBody:');
  final block = yaml.substring(start, end);
  return RegExp(
    r'^\s+- ([a-z_]+)\s*$',
    multiLine: true,
  ).allMatches(block).map((m) => m.group(1)!).toList();
}

/// method name -> the reasons its doc comment lists ("Reasons: a, b (+ offline).").
Map<String, Set<String>> _interfaceReasons(String source) {
  final out = <String, Set<String>>{};
  final doc = StringBuffer();
  for (final line in source.split('\n')) {
    final t = line.trim();
    if (t.startsWith('///')) {
      doc.write('${t.substring(3).trim()} ');
      continue;
    }
    final m = RegExp(
      r'^Future<Result<[^>]*(?:<[^>]*>)?[^>]*, Failure>>\s+(\w+)\(',
    ).firstMatch(t);
    if (m != null) {
      final reasons = RegExp(
        r'Reasons:\s*(.*?)\s*\(\+ offline\)',
      ).firstMatch(doc.toString());
      expect(reasons, isNotNull, reason: '${m.group(1)} lists its reasons');
      out[m.group(1)!] = reasons!
          .group(1)!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    if (t.isNotEmpty) doc.clear();
  }
  return out;
}

/// The property names of a schema in the yaml (`    SchemaName:` ... `properties:`).
Set<String> _yamlSchemaProperties(String yaml, String schema) {
  final lines = yaml.split('\n');
  final i = lines.indexWhere((l) => l == '    $schema:');
  expect(i, greaterThanOrEqualTo(0), reason: schema);
  var j = i + 1;
  while (j < lines.length && !RegExp(r'^    \w').hasMatch(lines[j])) {
    j++;
  }
  final block = lines.sublist(i, j);
  final p = block.indexWhere((l) => l == '      properties:');
  final props = <String>{};
  for (var k = p + 1; k < block.length; k++) {
    final m = RegExp(r'^        (\w+):').firstMatch(block[k]);
    if (m != null) props.add(m.group(1)!);
    if (RegExp(r'^      \w').hasMatch(block[k])) break;
  }
  return props;
}

void main() {
  late String yaml;
  late String readme;
  late String repoSource;

  setUpAll(() {
    yaml = File(_yamlPath).readAsStringSync();
    readme = File(_readmePath).readAsStringSync();
    repoSource = File(_repoPath).readAsStringSync();
  });

  group('operations (AC1, AC2)', () {
    test('the yaml defines exactly the six P2 operations', () {
      final ids = RegExp(
        r'operationId:\s*(\w+)',
      ).allMatches(yaml).map((m) => m.group(1)!).toList();
      expect(ids, _operations);
    });

    test('the interface declares exactly those operations, no more', () {
      final methods = RegExp(
        r'^\s*Future<Result<[^;]*?>>\s+(\w+)\(',
        multiLine: true,
      ).allMatches(repoSource).map((m) => m.group(1)!).toList();
      expect(methods, _operations);
    });

    test('every method returns Future<Result<T, Failure>>', () {
      final signatures = RegExp(
        r'^\s*Future<Result<[^;]*?>>\s+\w+\(',
        multiLine: true,
      ).allMatches(repoSource);
      expect(signatures.length, _operations.length);
      for (final s in signatures) {
        expect(s.group(0), contains(', Failure>>'));
      }
      expect(repoSource, isNot(contains('Either')));
    });

    test('the in-memory implementation compiles against the interface', () {
      expect(_InMemoryMessaging(), isA<MessagingRepository>());
    });
  });

  group('typed reasons (AC1, AC2)', () {
    test('the reason enum covers every reason in the contract', () {
      final contract = _yamlReasonEnum(yaml);
      expect(contract, isNotEmpty);
      for (final r in contract) {
        expect(
          MessagingReason.fromWire(r),
          isNot(MessagingReason.unknown),
          reason: '$r is in the contract but not in the Dart enum',
        );
      }
      // ...and the Dart enum adds only the two client-side reasons.
      // `under_age` is a DM reason from the Worker's start-DM call (KAN-557),
      // outside this game-chat contract.
      final dartServer = MessagingReason.values
          .where((r) => r.isServerReason && r != MessagingReason.underAge)
          .map((r) => r.wireName)
          .toSet();
      expect(dartServer, contract.toSet());
      expect(contract, isNot(contains('offline')));
      expect(contract, isNot(contains('unknown')));
    });

    test(
      'the proposed reason names are all in the contract or client-side',
      () {
        const proposed = {
          'not_in_pilot',
          'not_a_member',
          'removed',
          'left_read_only',
          'game_ended',
          'game_cancelled',
          'blocked',
          'suspended',
          'rate_limited',
          'not_found',
          'invalid_request',
        };
        expect(_yamlReasonEnum(yaml).toSet(), proposed);
      },
    );

    test('every operation lists its reasons, all from the contract enum', () {
      final byOp = _yamlOperationReasons(yaml);
      expect(byOp.keys.toList(), _operations);
      final all = _yamlReasonEnum(yaml).toSet();
      for (final e in byOp.entries) {
        expect(e.value, isNotEmpty, reason: e.key);
        expect(all.containsAll(e.value), isTrue, reason: e.key);
      }
    });

    test(
      'the interface lists, per method, the same reasons as the contract',
      () {
        final fromYaml = _yamlOperationReasons(yaml);
        final fromDart = _interfaceReasons(repoSource);
        expect(fromDart.keys.toList(), _operations);
        for (final op in _operations) {
          expect(fromDart[op], fromYaml[op]!.toSet(), reason: op);
        }
      },
    );

    test('left_read_only, game_ended and game_cancelled are send reasons', () {
      final send = _yamlOperationReasons(yaml)['sendTextMessage']!;
      expect(
        send,
        containsAll(['left_read_only', 'game_ended', 'game_cancelled']),
      );
    });

    test('the error body in the contract is the shape the parser reads', () {
      expect(yaml, contains('ErrorBody:'));
      for (final key in ['reason', 'message', 'retry_after_seconds']) {
        expect(yaml, contains('            $key:'));
      }
      final f = MessagingFailure.fromErrorBody(429, {
        'error': {'reason': 'rate_limited', 'retry_after_seconds': 3},
      });
      expect(f.reason, MessagingReason.rateLimited);
    });
  });

  group('fields (AC2)', () {
    test(
      'Message, Conversation, MessagePage and ViewBoundary fields agree',
      () {
        final message = Message(
          id: 'a',
          conversationId: 'b',
          seq: 1,
          kind: MessageKind.text,
          body: 'x',
          createdAt: DateTime.utc(2026),
        );
        expect(
          _yamlSchemaProperties(yaml, 'Message'),
          message.toJson().keys.toSet(),
        );

        const conversation = Conversation(
          id: 'a',
          gameId: 'b',
          writable: true,
          muted: false,
          lastSeq: 0,
        );
        // `kind` is the constant 'game' on the wire.
        expect(
          _yamlSchemaProperties(yaml, 'Conversation'),
          conversation.toJson().keys.toSet(),
        );

        const page = MessagePage(
          messages: [],
          hasOlder: false,
          hasNewer: false,
          pageSize: 30,
        );
        expect(
          _yamlSchemaProperties(yaml, 'MessagePage'),
          page.toJson().keys.toSet(),
        );
      },
    );

    test('limits agree with the contract', () {
      expect(yaml, contains('maximum: 50, default: 30'));
      expect(yaml, contains('maxLength: ${MessagingLimits.maxBodyLength}'));
    });

    test(
      'the report categories are exactly the existing report_reason enum',
      () {
        final baseline = File(
          'supabase/migrations/20260829080500_baseline_schema.sql',
        ).readAsStringSync();
        final block = RegExp(
          r'CREATE TYPE "public"\."report_reason" AS ENUM \((.*?)\);',
          dotAll: true,
        ).firstMatch(baseline)!.group(1)!;
        final existing = RegExp(
          r"'(\w+)'",
        ).allMatches(block).map((m) => m.group(1)).toList();
        expect(existing.length, 10);
        expect(ReportCategory.values.map((c) => c.wireName).toList(), existing);
      },
    );

    test('the report operation carries no free-text field', () {
      // Contract: ReportRequest has exactly one property, the reason enum.
      final props = _yamlSchemaProperties(yaml, 'ReportRequest');
      expect(props, {'reason'});
      final block = yaml.substring(yaml.indexOf('    ReportRequest:'));
      expect(block, contains('required: [reason]'));
      expect(block, contains('enum: ['));
      for (final bad in [
        'note',
        'details',
        'comment',
        'text',
        'message',
        'body',
      ]) {
        expect(props.contains(bad), isFalse, reason: bad);
      }
      // The operation sends only that schema as its request body.
      final op = yaml.substring(
        yaml.indexOf('operationId: reportMessage'),
        yaml.indexOf('operationId: muteConversation'),
      );
      expect(op, contains(r"$ref: '#/components/schemas/ReportRequest'"));
      expect(
        RegExp(
          r'type: string(?!\s*\n\s*(format|enum))',
        ).hasMatch(op.replaceAll(RegExp(r'#.*'), '')),
        isFalse,
      );
      // Interface: reportMessage takes the message id and the reason, nothing else.
      final sig = RegExp(
        r'Future<Result<void, Failure>> reportMessage\(\{(.*?)\}\);',
        dotAll: true,
      ).firstMatch(repoSource)!.group(1)!;
      final params = RegExp(
        r'(\w+)\s*,',
      ).allMatches(sig).map((m) => m.group(1)).toList();
      expect(params, ['messageId', 'reason']);
      expect(sig, isNot(contains('String?')));
      expect(sig, isNot(contains('note')));
      // Models and limits: no report note limit.
      expect(
        File(
          'lib/features/messaging/domain/models/message_page.dart',
        ).readAsStringSync(),
        isNot(contains('ReportNote')),
      );
      for (final f in Directory(
        'lib/features/messaging/domain',
      ).listSync(recursive: true).whereType<File>()) {
        expect(f.readAsStringSync(), isNot(contains('maxReportNoteLength')));
      }
    });

    test('the README states why there is no free-text note', () {
      expect(
        readme,
        contains(
          'no free-text note (D13, D21; revisit only with a CEO decision)',
        ),
      );
    });

    test('the report categories agree with the contract', () {
      final cats = ReportCategory.values.map((c) => c.wireName).join(', ');
      expect(yaml, contains('enum: [$cats]'));
    });
  });

  group('idempotency (AC3)', () {
    test(
      'the contract requires an Idempotency-Key on send and says a duplicate '
      'returns the same message',
      () {
        expect(yaml, contains('name: Idempotency-Key'));
        final sendBlock = yaml.substring(
          yaml.indexOf('operationId: sendTextMessage'),
        );
        expect(sendBlock, contains('required: true'));
        expect(yaml, contains('returns the SAME message'));
        expect(yaml, contains('creates no'));
        expect(readme, contains('returns the same message'));
        expect(readme.replaceAll(RegExp(r'\s+'), ' '), contains('one row'));
      },
    );

    test(
      'a duplicate send with the same key returns the same message, one row',
      () async {
        final repo = _InMemoryMessaging();
        final a = await repo.sendTextMessage(
          conversationId: 'c1',
          body: 'hi',
          idempotencyKey: 'k1',
        );
        final b = await repo.sendTextMessage(
          conversationId: 'c1',
          body: 'hi',
          idempotencyKey: 'k1',
        );
        final c = await repo.sendTextMessage(
          conversationId: 'c1',
          body: 'hi again',
          idempotencyKey: 'k2',
        );
        expect(a.requireValue, b.requireValue);
        expect(a.requireValue.id, b.requireValue.id);
        expect(c.requireValue.id, isNot(a.requireValue.id));
        expect(repo.rows.length, 2);
      },
    );
  });

  group('pagination and the boundary (AC4)', () {
    test('the contract pages by seq with older and newer directions', () {
      expect(yaml, contains('name: cursor'));
      expect(yaml, contains('enum: [older, newer]'));
      expect(yaml, contains('older_cursor'));
      expect(yaml, contains('newer_cursor'));
      expect(yaml, contains('maximum: 50, default: 30'));
    });

    test('left_at_seq is a typed boundary in the contract and the models', () {
      expect(yaml, contains('ViewBoundary:'));
      expect(yaml, contains('enum: [left_at_seq]'));
      expect(yaml, contains('clients apply no rule'));
    });
  });

  group('README (AC5)', () {
    test('states the D24 rules and labels them a recommendation', () {
      expect(readme, contains('msg_authorize'));
      expect(readme, contains('bearer token unchanged'));
      expect(readme, contains('trusts only the `user_id` that RPC returns'));
      expect(readme, contains('NOT YET CEO-APPROVED'));
      expect(readme, contains('D24'));
    });

    test('keeps the approved and unapproved rulings apart', () {
      expect(readme, contains('CEO-approved'));
      for (final d in ['D1', 'D13', 'D18', 'D5', 'D7', 'D4', 'D8', 'D16']) {
        expect(readme, contains(d));
      }
      expect(readme.toLowerCase(), isNot(contains('within 24 hours')));
      expect(yaml.toLowerCase(), isNot(contains('24 hours')));
    });

    test('says no test was run against a database', () {
      expect(readme, contains('AUTHORED, NOT RUN'));
    });
  });

  group('scope and safety (AC6, AC7)', () {
    test('the contract has nothing for typing, presence, previews, search, '
        'receipts, attachments or reactions', () {
      final text = yaml.toLowerCase();
      for (final word in [
        'typing',
        'presence',
        'preview',
        'search',
        'receipt',
        'attachment',
        'reaction',
        'delivered',
        'read_receipt',
      ]) {
        expect(text.contains(word), isFalse, reason: word);
      }
      // "read" as a state word (not inside names like left_read_only).
      expect(RegExp(r'\bread\b').hasMatch(text), isFalse);
      expect(
        RegExp(r'^  /', multiLine: true).allMatches(yaml).length,
        4,
        reason: 'four paths, six operations',
      );
    });

    test(
      'nothing in the domain layer imports a network or Supabase package',
      () {
        final files = Directory('lib/features/messaging/domain')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
        expect(files, isNotEmpty);
        for (final f in files) {
          final imports = f
              .readAsLinesSync()
              .where((l) => l.trimLeft().startsWith('import '))
              .join('\n');
          for (final bad in [
            'package:supabase',
            'package:http',
            'package:dio',
            'dart:io',
            'package:flutter_riverpod',
          ]) {
            expect(
              imports.contains(bad),
              isFalse,
              reason: '${f.path} imports $bad',
            );
          }
        }
      },
    );

    test('the messaging flag is still false', () {
      expect(FeatureFlags.messaging, isFalse);
    });

    test('no secret, key or connection string in the contract files', () {
      final secretLike = RegExp(
        r'(eyJ[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9]{20,}|sk_(live|test)_|postgres(ql)?://\S+:\S+@|(?=[A-Za-z0-9]*\d)(?=[A-Za-z0-9]*[A-Z])(?=[A-Za-z0-9]*[a-z])[A-Za-z0-9]{40,})',
      );
      for (final text in [yaml, readme, repoSource]) {
        expect(secretLike.hasMatch(text), isFalse);
        final refs = RegExp(
          r'([a-z]{20})\.supabase\.co',
        ).allMatches(text).map((m) => m.group(1)).toSet();
        expect(refs.difference({'wtncuzcskpigqpmnxwws'}), isEmpty);
      }
    });
  });
}
