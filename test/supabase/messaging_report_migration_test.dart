import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-512 (Messaging T17) report migrations and probe pack. The
/// migrations are authored and NOT applied; these tests pin their shape. They run no SQL.
const _dir = 'supabase/migrations';
const _packDir = 'supabase/tests/messaging';
const _check = '20261013160200_kan512_msg_report_no_snapshot_check.sql';
const _function = '20261013160300_kan512_msg_report_function.sql';
const _mine = [_check, _function];
const _sig =
    'public.msg_report_message(uuid, uuid, bigint, public.report_reason, text)';

String _stripComments(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

bool _hasDrop(String text) =>
    RegExp(r'\bdrop\b', caseSensitive: false).hasMatch(text);

String _read(String path) => File(path).readAsStringSync();

void main() {
  late Map<String, String> raw;
  late Map<String, String> sql;
  late String probes;
  late String rollback;

  setUpAll(() {
    raw = {for (final n in _mine) n: _read('$_dir/$n')};
    sql = {for (final n in _mine) n: _squash(_stripComments(raw[n]!))};
    probes = _read('$_packDir/report_probes.sql');
    rollback = _read('$_packDir/report_rollback.sql');
  });

  group('files', () {
    test(
      'two msg_report migrations, newer than 20261013150300, check first',
      () {
        final present =
            Directory(_dir)
                .listSync()
                .map((e) => e.uri.pathSegments.last)
                .where(
                  (n) =>
                      n.contains('msg_report') &&
                      !n.contains('msg_report_list'),
                )
                .toList()
              ..sort();
        expect(present, _mine);
        for (final n in _mine) {
          expect(n.compareTo('20261013150300'), greaterThan(0), reason: n);
        }
      },
    );

    test('the CHECK and the function live in separate files', () {
      expect(sql[_check], contains('ADD CONSTRAINT'));
      expect(sql[_check], isNot(contains('FUNCTION')));
      expect(sql[_function], contains('CREATE OR REPLACE FUNCTION'));
      expect(sql[_function], isNot(contains('ADD CONSTRAINT')));
    });

    test('no destructive keyword anywhere, comments included', () {
      for (final n in _mine) {
        expect(_hasDrop(raw[n]!), isFalse, reason: n);
      }
      expect(_hasDrop(probes), isFalse);
      expect(_hasDrop(rollback), isFalse);
    });

    test('no new reports table and no text column', () {
      for (final n in _mine) {
        expect(sql[n], isNot(contains('CREATE TABLE')), reason: n);
        expect(
          sql[n],
          isNot(matches(RegExp(r'ADD COLUMN', caseSensitive: false))),
        );
        expect(
          sql[n],
          isNot(matches(RegExp(r'\bbody\b|\bp_text\b|\bp_body\b'))),
        );
      }
    });
  });

  group('CHECK', () {
    test('message reports must carry a NULL snapshot', () {
      expect(
        sql[_check],
        contains(
          "CHECK (target_type <> 'message'::public.mod_target OR content_snapshot IS NULL)",
        ),
      );
      expect(
        sql[_check],
        contains('moderation_reports_message_no_snapshot_check'),
      );
    });

    test('added NOT VALID, no VALIDATE in the file, reasoning stated', () {
      expect(sql[_check], contains('NOT VALID'));
      expect(sql[_check], isNot(contains('VALIDATE CONSTRAINT')));
      expect(raw[_check], contains('WHY THIS CANNOT FAIL ON EXISTING ROWS'));
      expect(raw[_check], contains('does not scan existing rows'));
      expect(raw[_check], contains('probe R1'));
    });
  });

  group('function', () {
    test('SECURITY DEFINER with a pinned search_path', () {
      expect(sql[_function], contains('SECURITY DEFINER'));
      expect(sql[_function], contains("SET search_path = 'public', 'pg_temp'"));
    });

    test('EXECUTE to authenticated only', () {
      expect(
        sql[_function],
        contains(
          'REVOKE ALL ON FUNCTION $_sig FROM PUBLIC, anon, service_role;',
        ),
      );
      expect(
        sql[_function],
        contains('GRANT EXECUTE ON FUNCTION $_sig TO authenticated;'),
      );
      final grants = RegExp(
        r'GRANT EXECUTE[^;]*;',
      ).allMatches(sql[_function]!).toList();
      expect(grants.length, 1);
    });

    test('reuses the existing report_reason enum, creates no type', () {
      expect(sql[_function], contains('p_reason public.report_reason'));
      expect(sql[_function], isNot(contains('CREATE TYPE')));
      expect(sql[_function], isNot(contains('ADD VALUE')));
    });

    test(
      'inserts target_type message with NULL snapshot and details; no snapshot written',
      () {
        expect(
          sql[_function],
          contains(
            "INSERT INTO public.moderation_reports (reporter_user_id, target_type, target_id, reason, details, content_snapshot) "
            "VALUES (v_uid, 'message'::public.mod_target, p_message_id, p_reason, NULL, NULL)",
          ),
        );
        expect(sql[_function], isNot(contains('p_snapshot')));
        expect(sql[_function], isNot(contains('jsonb')));
      },
    );

    test(
      'caller from auth.uid(), re-checked with msg_evaluate and left_at_seq',
      () {
        expect(sql[_function], contains('v_uid uuid := auth.uid();'));
        expect(
          sql[_function],
          contains(
            'public.msg_evaluate(p_conversation_id, v_uid, p_access_mode)',
          ),
        );
        expect(
          sql[_function],
          contains("p_message_seq > COALESCE(v_eval.left_at_seq, 0)"),
        );
        expect(sql[_function], contains("ERRCODE = '42501'"));
      },
    );

    test('idempotent per (reporter, message) without a new index', () {
      expect(sql[_function], contains('pg_advisory_xact_lock'));
      expect(sql[_function], contains('r.reporter_user_id = v_uid'));
      expect(sql[_function], contains('r.target_id = p_message_id'));
      expect(sql[_function], contains('RETURN QUERY SELECT v_id, false;'));
      expect(sql[_function], isNot(contains('CREATE UNIQUE INDEX')));
    });

    test('no response-time promise', () {
      expect(
        raw[_function]!.toLowerCase(),
        isNot(matches(RegExp(r'within \d|hours?\b|sla\b'))),
      );
    });
  });

  group('probes and rollback', () {
    test('probe pack is marked AUTHORED, NOT RUN on every block', () {
      expect(probes, contains('AUTHORED, NOT RUN.'));
      final blocks = RegExp(
        r'^-- R\d+ \[(READ-ONLY|WRITE-IN-TRANSACTION-ROLLBACK)\] AUTHORED, NOT RUN\.',
        multiLine: true,
      ).allMatches(probes).length;
      expect(blocks, greaterThanOrEqualTo(4));
      expect(
        RegExp(r'^begin;', multiLine: true).allMatches(probes).length,
        blocks,
      );
      expect(
        RegExp(r'^rollback;', multiLine: true).allMatches(probes).length,
        blocks,
      );
      expect(probes, isNot(contains('commit;')));
    });

    test(
      'violator count expects 0, non-member denied, member allowed, repeat no duplicate',
      () {
        expect(probes, contains('pass_no_violators'));
        expect(probes, contains("content_snapshot is not null"));
        expect(probes, contains('pass_non_member_denied'));
        expect(probes, contains('pass_member_allowed'));
        expect(probes, contains('pass_repeat_no_duplicate'));
        expect(probes, contains('pass_null_snapshot'));
      },
    );

    test('rollback revokes execution and is marked AUTHORED, NOT RUN', () {
      expect(rollback, contains('AUTHORED, NOT RUN.'));
      expect(
        rollback,
        contains('revoke execute on function public.msg_report_message'),
      );
      expect(rollback.toLowerCase(), isNot(contains('delete from')));
    });
  });
}
