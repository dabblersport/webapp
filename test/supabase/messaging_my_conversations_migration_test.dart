import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-547 migration (the Messages list data): last_activity_at, the msg_notify stamp
/// and public.msg_my_conversations. Authored and NOT applied; these tests run no SQL. They never assert that
/// the migration is the newest one, only that it sorts after a fixed earlier cut-off.
const _dir = 'supabase/migrations';
const _name = '20261013160800_kan547_msg_my_conversations.sql';
const _kan541 = '$_dir/20261013160600_kan541_msg_notify.sql';
const _pack = 'supabase/tests/messaging';
const _probes = '$_pack/my_conversations_probes.sql';
const _rollback = '$_pack/my_conversations_rollback.sql';

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

/// One function definition, from its CREATE to the closing $$; (comments kept).
String _fn(String sql, String name) {
  final a = sql.indexOf('CREATE OR REPLACE FUNCTION public.$name(');
  expect(a, greaterThanOrEqualTo(0), reason: name);
  final body = sql.indexOf(r'AS $$', a);
  return sql.substring(a, sql.indexOf(r'$$;', body) + 3);
}

void main() {
  late String raw;
  late String sql;

  setUpAll(() {
    raw = File('$_dir/$_name').readAsStringSync();
    sql = _squash(_strip(raw));
  });

  test(
    'exists, sorts after a fixed cut-off, unique version, name keeps the filters off',
    () {
      expect(File('$_dir/$_name').existsSync(), isTrue);
      expect(_name.compareTo('20261013160700'), greaterThan(0));
      expect(_name, contains('msg_my_conversations'));
      expect(_name, isNot(contains('msg_report')));
      expect(_name, isNot(contains('_msg_system')));
      final versions = Directory(_dir)
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .where((n) => RegExp(r'^\d{14}_').hasMatch(n))
          .map((n) => n.substring(0, 14))
          .where((v) => v == _name.substring(0, 14));
      expect(versions.length, 1);
    },
  );

  group('column and index', () {
    test('only IF NOT EXISTS forms, not null with a default, no backfill', () {
      expect(
        sql,
        contains(
          'ALTER TABLE public.msg_conversations ADD COLUMN IF NOT EXISTS last_activity_at timestamptz NOT NULL DEFAULT now();',
        ),
      );
      expect(
        sql,
        contains(
          'CREATE INDEX IF NOT EXISTS msg_conversations_last_activity_idx ON public.msg_conversations (last_activity_at);',
        ),
      );
      expect(RegExp(r'CREATE (UNIQUE )?INDEX').allMatches(sql).length, 1);
      expect(RegExp(r'ALTER TABLE').allMatches(sql).length, 1);
      // the user_id index already exists (KAN-505): not recreated
      expect(sql, isNot(contains('msg_conversation_members_user_idx')));
      expect(sql, isNot(contains('msg_conversation_members')));
      // no backfill
      expect(
        RegExp(
          r'\bUPDATE public\.msg_conversations SET last_activity_at = (?!now\(\) WHERE id = p_conversation_id)',
        ).hasMatch(sql),
        isFalse,
      );
    });
  });

  group('msg_notify', () {
    test('is the KAN-541 text with exactly one added statement', () {
      final old = _fn(File(_kan541).readAsStringSync(), 'msg_notify');
      final now = _fn(raw, 'msg_notify');
      const stamp = r'''
  -- KAN-547: the one added statement. Stamps the conversation so the Messages list can order by
  -- recent activity. Quiet: a failed stamp warns (sqlstate only) and the wake-ups below still go out.
  BEGIN
    UPDATE public.msg_conversations SET last_activity_at = now() WHERE id = p_conversation_id;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'msg_notify stamp failed (sqlstate %)', SQLSTATE;
  END;
''';
      const gate = '''
  IF v_eval.allowed_action IS DISTINCT FROM 'send' THEN
    RETURN;
  END IF;
''';
      expect(old, contains(gate));
      expect(now, old.replaceFirst(gate, '$gate\n${stamp.trimRight()}\n'));
      expect(
        RegExp(r'UPDATE public\.msg_conversations').allMatches(now).length,
        1,
      );
    });

    test(
      'signature, attributes, gate, payload and quiet failure are intact; grants re-stated',
      () {
        final n = _squash(_strip(_fn(raw, 'msg_notify')));
        expect(
          n,
          contains(
            'p_conversation_id uuid, p_seq bigint, p_access_mode text DEFAULT \'allowlist\'',
          ),
        );
        expect(
          n,
          contains(
            'RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp',
          ),
        );
        expect(n, contains('v_uid uuid := auth.uid()'));
        expect(
          n,
          contains(
            'public.msg_evaluate(p_conversation_id, v_uid, p_access_mode)',
          ),
        );
        expect(
          n,
          contains(
            "realtime.send(v_payload, 'msg', 'user:' || v_to::text, true)",
          ),
        );
        expect(
          n,
          contains(
            "jsonb_build_object( 'type', 'msg', 'conversation_id', p_conversation_id, 'seq', p_seq )",
          ),
        );
        expect(RegExp('EXCEPTION WHEN OTHERS THEN').allMatches(n).length, 3);
        expect(n, isNot(contains('RAISE EXCEPTION')));
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
      },
    );
  });

  group('msg_my_conversations', () {
    late String f;
    setUpAll(() => f = _squash(_strip(_fn(raw, 'msg_my_conversations'))));

    test('signature, columns, attributes', () {
      expect(f, contains('msg_my_conversations(p_limit int DEFAULT 50)'));
      expect(
        f,
        contains(
          'RETURNS TABLE ( conversation_id uuid, game_id uuid, game_title text, sport text, start_at timestamptz, end_at timestamptz, state text, last_activity_at timestamptz )',
        ),
      );
      expect(
        f,
        contains(
          'LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp',
        ),
      );
    });

    test('identity from auth.uid() only: no user parameter', () {
      expect(f, contains('r.user_id = auth.uid()'));
      expect(f, contains('auth.uid() IS NOT NULL'));
      expect(RegExp(r'p_(user|uid|member|profile)').hasMatch(f), isFalse);
    });

    test('state rules and the membership rule of msg_evaluate', () {
      expect(f, contains("WHEN m.status = 'left' THEN 'left'"));
      expect(
        f,
        contains("WHEN g.is_cancelled OR g.end_at < now() THEN 'read_only'"),
      );
      expect(f, contains("ELSE 'send'"));
      expect(f, contains("m.status IN ('active', 'left')"));
      expect(f, contains("r.role IN ('host', 'player', 'sub')"));
      expect(
        f,
        contains(
          "ORDER BY (r.status = 'active') DESC, (r.status = 'left') DESC, r.joined_at DESC LIMIT 1",
        ),
      );
      // the same lateral ordering as msg_evaluate
      final evaluate = _squash(
        _strip(
          File(
            '$_dir/20261013150200_kan505_msg_functions.sql',
          ).readAsStringSync(),
        ),
      );
      expect(
        evaluate,
        contains(
          "AND r.role IN ('host', 'player', 'sub') ORDER BY (r.status = 'active') DESC, (r.status = 'left') DESC, r.joined_at DESC LIMIT 1",
        ),
      );
    });

    test('order, tie-break and limit clamp', () {
      expect(f, contains('ORDER BY c.last_activity_at DESC, g.start_at DESC'));
      expect(
        f,
        contains('LIMIT least(greatest(coalesce(p_limit, 50), 1), 100)'),
      );
    });

    test(
      'sport name comes from the sports table; nothing else is selected',
      () {
        expect(f, contains('LEFT JOIN public.sports s ON s.id = g.sport_id'));
        expect(f, contains('s.name_en'));
        for (final bad in [
          'body',
          'content',
          'message',
          'sender',
          'unread',
          'preview',
          'member_user_ids',
          'array_agg',
        ]) {
          expect(f.toLowerCase(), isNot(contains(bad)), reason: bad);
        }
      },
    );
  });

  group('grants and safety', () {
    test(
      'revoked from PUBLIC and anon, executable by authenticated only; owner not changed',
      () {
        expect(
          sql,
          contains(
            'REVOKE ALL ON FUNCTION public.msg_my_conversations(int) FROM PUBLIC, anon;',
          ),
        );
        expect(
          sql,
          contains(
            'GRANT EXECUTE ON FUNCTION public.msg_my_conversations(int) TO authenticated;',
          ),
        );
        expect(sql, isNot(contains('OWNER TO')));
        expect(sql, isNot(contains('service_role')));
      },
    );

    test('no DROP, no policy, no content column, no secret', () {
      expect(_hasDrop(raw), isFalse);
      expect(sql, isNot(contains('POLICY')));
      expect(sql, isNot(contains('CREATE TABLE')));
      expect(
        RegExp(r'eyJ[A-Za-z0-9_-]{10,}|[0-9a-f]{40,}|https?://').hasMatch(raw),
        isFalse,
      );
    });
  });

  group('probes and rollback', () {
    test(
      'probe pack: every block BEGIN..ROLLBACK, AUTHORED NOT RUN, the listed cases present',
      () {
        final p = File(_probes).readAsStringSync();
        expect(p.split('\n').first, contains('AUTHORED, NOT RUN'));
        final heads = RegExp(
          r'^-- M\d+ \[(READ-ONLY|WRITE-IN-TRANSACTION-ROLLBACK)\] AUTHORED, NOT RUN\.',
          multiLine: true,
        ).allMatches(p).length;
        expect(heads, 10);
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
          'pass_user_id_index_exists',
          'pass_send_state',
          'pass_ended_read_only',
          'pass_leaver_left',
          'pass_kicked_absent',
          'pass_non_member_empty',
          'pass_anon_refused',
          'pass_newest_first_tie_by_start',
          'pass_limit_capped_at_100',
          'pass_limit_zero_clamped_to_one',
          'pass_stamp_moved_it_up',
          'pass_failed_stamp_does_not_raise',
          'pass_authenticated_can_execute',
          'pass_anon_cannot_execute',
        ]) {
          expect(p, contains(c), reason: c);
        }
      },
    );

    test(
      'rollback revokes the function and re-issues the previous msg_notify; nothing is removed',
      () {
        final r = File(_rollback).readAsStringSync();
        expect(r, contains('AUTHORED, NOT RUN'));
        expect(_hasDrop(r), isFalse);
        expect(
          _squash(_strip(r)),
          contains(
            'revoke execute on function public.msg_my_conversations(int) from authenticated;',
          ),
        );
        expect(
          _fn(r, 'msg_notify'),
          _fn(File(_kan541).readAsStringSync(), 'msg_notify'),
        );
        expect(_fn(r, 'msg_notify'), isNot(contains('last_activity_at')));
      },
    );

    test('README lists the new files', () {
      final r = File('$_pack/README.md').readAsStringSync();
      expect(r, contains('## KAN-547'));
      expect(r, contains('my_conversations_probes.sql'));
      expect(r, contains('my_conversations_rollback.sql'));
    });
  });

  test(
    'probe setup is idempotent: every allowlist insert is ON CONFLICT DO NOTHING',
    () {
      final p = File('$_pack/my_conversations_probes.sql').readAsStringSync();
      final inserts = RegExp(
        r'insert into public\.msg_access_allowlist[^;]*;',
      ).allMatches(p).toList();
      expect(inserts, isNotEmpty);
      for (final m in inserts) {
        expect(m.group(0), contains('on conflict (user_id) do nothing'));
      }
    },
  );
}
