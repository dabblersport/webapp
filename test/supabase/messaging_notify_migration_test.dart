import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-541 migration (public.msg_notify), its probe pack, the read-only
/// realtime.send check and the rollback. Authored and NOT applied/run; these tests run no SQL and
/// never assert that the migration is the newest one (only that it sorts after a fixed cut-off).
const _name = '20261013160600_kan541_msg_notify.sql';
const _migration = 'supabase/migrations/$_name';
const _pack = 'supabase/tests/messaging';
const _probes = '$_pack/notify_probes.sql';
const _check = '$_pack/notify_realtime_send_check.sql';
const _rollback = '$_pack/notify_rollback.sql';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

bool _hasDrop(String s) =>
    RegExp(r'\bdrop\b', caseSensitive: false).hasMatch(s);

void main() {
  late String raw;
  late String sql;

  setUpAll(() {
    raw = File(_migration).readAsStringSync();
    sql = _squash(_strip(raw));
  });

  test(
    'exists, sorts after the fixed cut-off, name avoids the report/system filters',
    () {
      expect(File(_migration).existsSync(), isTrue);
      expect(_name.compareTo('20261013160500'), greaterThan(0));
      expect(_name, contains('_msg_notify'));
      expect(_name, isNot(contains('msg_report')));
      expect(_name, isNot(contains('_msg_system')));
      final versions = Directory('supabase/migrations')
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .where((n) => RegExp(r'^\d{14}_').hasMatch(n))
          .map((n) => n.substring(0, 14))
          .toList();
      expect(versions.where((v) => v == _name.substring(0, 14)).length, 1);
    },
  );

  group('definition', () {
    test('security definer, search_path, volatile plpgsql, void', () {
      expect(sql, contains('CREATE OR REPLACE FUNCTION public.msg_notify('));
      expect(
        sql,
        contains(
          'p_conversation_id uuid, p_seq bigint, p_access_mode text DEFAULT \'allowlist\'',
        ),
      );
      expect(sql, contains('RETURNS void'));
      expect(sql, contains('LANGUAGE plpgsql'));
      expect(sql, contains('SECURITY DEFINER'));
      expect(sql, contains('SET search_path = public, pg_temp'));
    });

    test('identity from auth.uid() only; the msg_evaluate gate decides', () {
      expect(sql, contains('v_uid uuid := auth.uid()'));
      expect(
        sql,
        contains(
          'public.msg_evaluate(p_conversation_id, v_uid, p_access_mode)',
        ),
      );
      expect(sql, contains("v_eval.allowed_action IS DISTINCT FROM 'send'"));
      expect(RegExp(r'p_(user|uid|sender|member)').hasMatch(sql), isFalse);
    });

    test(
      'recipients are the current active roster, blockers excluded, sender included',
      () {
        expect(sql, contains('FROM public.game_roster r'));
        expect(sql, contains('r.game_id = v_eval.game_id'));
        expect(sql, contains("r.status = 'active'"));
        expect(sql, contains("r.role IN ('host', 'player', 'sub')"));
        expect(sql, contains('FROM public.user_blocks b'));
        expect(sql, contains('b.blocker_user_id = r.user_id'));
        expect(sql, contains('b.blocked_user_id = v_uid'));
        // the sender is not filtered out
        expect(sql, isNot(contains('r.user_id <>')));
        expect(sql, isNot(contains('r.user_id != v_uid')));
      },
    );

    test(
      'realtime.send on the private user topic with the private flag true',
      () {
        expect(
          sql,
          contains(
            "realtime.send(v_payload, 'msg', 'user:' || v_to::text, true)",
          ),
        );
        expect(RegExp(r'realtime\.send').allMatches(sql).length, 1);
        expect(sql, isNot(contains(', false)')));
      },
    );

    test('the payload has exactly three keys and no text', () {
      final m = RegExp(
        r'jsonb_build_object\((.*?)\);',
      ).firstMatch(sql)!.group(1)!;
      final keys = RegExp(
        r"'(\w+)',\s*(?:'msg'|p_\w+)",
      ).allMatches(m).map((x) => x.group(1)).toList();
      expect(keys, ['type', 'conversation_id', 'seq']);
      expect(m, contains("'type', 'msg'"));
      for (final bad in [
        'body',
        'text',
        'sender',
        'media',
        'members',
        'event',
      ]) {
        expect(m, isNot(contains("'$bad'")));
      }
    });

    test('failures are quiet: payload-free warnings, never a raise', () {
      expect(sql, contains('EXCEPTION WHEN OTHERS THEN'));
      expect(
        RegExp(
          r'EXCEPTION WHEN OTHERS THEN RAISE WARNING',
        ).allMatches(sql).length,
        2,
      );
      expect(sql, contains('(sqlstate %)\', SQLSTATE'));
      expect(sql, isNot(contains('RAISE EXCEPTION')));
      expect(sql, isNot(contains('RAISE NOTICE')));
      // warnings never mention the payload or any id
      for (final m in RegExp(r"RAISE WARNING '([^']*)'").allMatches(sql)) {
        expect(m.group(1), isNot(contains('v_payload')));
      }
    });
  });

  group('grants and safety', () {
    test('revoked from PUBLIC and anon, executable by authenticated only', () {
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.msg_notify(uuid, bigint, text) FROM PUBLIC, anon;',
        ),
      );
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.msg_notify(uuid, bigint, text) TO authenticated;',
        ),
      );
      expect(RegExp(r'GRANT').allMatches(sql).length, 1);
      expect(sql, isNot(contains('service_role')));
    });

    test('no policy, no table, no secret, no vault read, no DROP', () {
      expect(sql, isNot(contains('POLICY')));
      expect(sql, isNot(contains('CREATE TABLE')));
      expect(sql, isNot(contains('ALTER TABLE')));
      expect(sql, isNot(contains('vault')));
      expect(sql, isNot(contains('INSERT INTO')));
      expect(
        RegExp(r'eyJ[A-Za-z0-9_-]{10,}|[0-9a-f]{40,}|https?://').hasMatch(raw),
        isFalse,
      );
      expect(_hasDrop(raw), isFalse);
    });

    test('no text column is referenced', () {
      expect(sql, isNot(contains('msg_messages')));
      expect(
        RegExp(r'\b(body|content|text)\b').hasMatch(
          sql
              .replaceAll('p_access_mode text', '')
              .replaceAll('::text', '')
              .replaceAll('bigint, text)', 'bigint)'),
        ),
        isFalse,
      );
    });
  });

  group('probes, realtime.send check and rollback', () {
    test(
      'probe pack: every block BEGIN..ROLLBACK, AUTHORED, NOT RUN, no payload text',
      () {
        final p = File(_probes).readAsStringSync();
        expect(p.split('\n').first, contains('AUTHORED, NOT RUN'));
        final heads = RegExp(
          r'^-- N\d+ \[(READ-ONLY|WRITE-IN-TRANSACTION-ROLLBACK)\] AUTHORED, NOT RUN\.',
          multiLine: true,
        ).allMatches(p).length;
        expect(heads, 6);
        expect(
          RegExp(r'^BEGIN;$', multiLine: true).allMatches(p).length,
          heads,
        );
        expect(
          RegExp(r'^ROLLBACK;$', multiLine: true).allMatches(p).length,
          heads,
        );
        expect(p, isNot(contains('COMMIT')));
        expect(_hasDrop(p), isFalse);
        for (final c in [
          'pass_member_b_woken',
          'pass_sender_own_topic_included',
          'pass_exactly_three_keys',
          'pass_non_member_queues_none',
          'pass_no_gate_queues_none',
          'pass_blocker_excluded',
          'pass_leaver_excluded',
          'pass_removed_excluded',
          'pass_no_insert_policy',
        ]) {
          expect(p, contains(c), reason: c);
        }
        // nothing selects the payload itself for printing
        expect(
          RegExp(
            r'select\s+(payload|m\.payload)\b',
            caseSensitive: false,
          ).hasMatch(p),
          isFalse,
        );
      },
    );

    test(
      'the realtime.send check is read-only and asks for signature, owner and privileges',
      () {
        final c = File(_check).readAsStringSync();
        expect(c, contains('AUTHORED, NOT RUN'));
        expect(c, contains("n.nspname = 'realtime' and p.proname = 'send'"));
        expect(c, contains('pg_get_userbyid(p.proowner)'));
        expect(
          c,
          contains(
            "has_function_privilege('postgres', 'realtime.send(jsonb,text,text,boolean)', 'EXECUTE')",
          ),
        );
        expect(
          c,
          contains(
            "has_table_privilege('postgres', 'realtime.messages', 'INSERT')",
          ),
        );
        final body = _strip(c);
        expect(
          RegExp(
            r'\b(insert|update|delete|create|alter|grant|revoke|perform)\b',
            caseSensitive: false,
          ).hasMatch(body.replaceAll(RegExp(r"'[^']*'"), "''")),
          isFalse,
        );
        expect(
          RegExp(
            r'^select realtime\.send',
            caseSensitive: false,
            multiLine: true,
          ).hasMatch(body),
          isFalse,
        );
        expect(body, contains('BEGIN;'));
        expect(body, contains('ROLLBACK;'));
        expect(_hasDrop(c), isFalse);
      },
    );

    test('rollback only revokes EXECUTE', () {
      final r = File(_rollback).readAsStringSync();
      final body = _squash(_strip(r));
      expect(r, contains('AUTHORED, NOT RUN'));
      expect(
        body,
        'begin; revoke all on function public.msg_notify(uuid, bigint, text) from public, anon, authenticated, service_role; commit;',
      );
      expect(_hasDrop(r), isFalse);
    });

    test('README has a section for this ticket', () {
      expect(
        File('$_pack/README.md').readAsStringSync(),
        contains('## KAN-541'),
      );
    });
  });
}
