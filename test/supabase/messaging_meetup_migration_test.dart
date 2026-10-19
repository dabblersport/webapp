import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-558 migration (meetup chat), its probe pack and rollback. Authored and NOT applied/run;
/// these tests run no SQL. They never assert that the migration is the newest one, only that it sorts after a fixed
/// earlier cut-off.
const _dir = 'supabase/migrations';
const _name = '20261017130000_kan558_msg_meetup_chat.sql';
const _dm = '$_dir/20261013160900_kan560_msg_dm_conversations.sql';
const _list = '$_dir/20261013161000_kan555_msg_my_conversations_dm.sql';
const _pack = 'supabase/tests/messaging';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String _fn(
  String sql,
  String name, {
  String kw = 'CREATE OR REPLACE FUNCTION',
}) {
  final a = sql.indexOf('$kw public.$name(');
  expect(a, greaterThanOrEqualTo(0), reason: name);
  final body = sql.indexOf(r'AS $$', a);
  return sql.substring(a, sql.indexOf(r'$$;', body) + 3);
}

/// Every line of [prev] appears, in order, in [next] (next only ADDS lines).
void _onlyAdds(String prev, String next, String what) {
  final n = next.split('\n');
  var j = 0;
  for (final line in prev.split('\n')) {
    while (j < n.length && n[j] != line) {
      j++;
    }
    expect(j, lessThan(n.length), reason: '$what lost: $line');
    j++;
  }
}

void main() {
  late String raw;
  late String sql;
  late String dm;
  late String list;

  setUpAll(() {
    raw = File('$_dir/$_name').readAsStringSync();
    sql = _squash(_strip(raw));
    dm = File(_dm).readAsStringSync();
    list = File(_list).readAsStringSync();
  });

  test(
    'exists, sorts after a fixed cut-off, unique version, named msg_meetup',
    () {
      expect(File('$_dir/$_name').existsSync(), isTrue);
      expect(_name.compareTo('20261017120000'), greaterThan(0));
      expect(_name, contains('msg_meetup'));
      final same = Directory(_dir)
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .where((n) => n.startsWith(_name.substring(0, 14)));
      expect(same.length, 1);
    },
  );

  group('schema', () {
    test('one transaction; the only drops are the two CHECK replacements', () {
      expect(RegExp(r'^BEGIN;$', multiLine: true).allMatches(raw).length, 1);
      expect(RegExp(r'^COMMIT;$', multiLine: true).allMatches(raw).length, 1);
      final drops = RegExp(
        r'\bDROP\b[^;]*;',
        caseSensitive: false,
      ).allMatches(sql).map((m) => m.group(0)).toList();
      expect(drops, [
        'DROP CONSTRAINT IF EXISTS msg_conversations_kind_check;',
        'DROP CONSTRAINT IF EXISTS msg_conversations_kind_game_check;',
      ]);
    });

    test('kind meetup, meetup_id unique FK, exactly-one shape check', () {
      expect(
        sql,
        contains(
          "ADD CONSTRAINT msg_conversations_kind_check CHECK (kind IN ('game', 'dm', 'meetup'));",
        ),
      );
      expect(
        sql,
        contains(
          'ADD COLUMN IF NOT EXISTS meetup_id uuid CONSTRAINT msg_conversations_meetup_id_key UNIQUE REFERENCES public.meetups (id);',
        ),
      );
      expect(
        sql,
        contains(
          "CHECK ((kind = 'game' AND game_id IS NOT NULL AND meetup_id IS NULL) "
          "OR (kind = 'meetup' AND meetup_id IS NOT NULL AND game_id IS NULL) "
          "OR (kind = 'dm' AND game_id IS NULL AND meetup_id IS NULL));",
        ),
      );
    });

    test(
      'no content column, no table, no policy, no owner change, no secret',
      () {
        for (final bad in ['content', 'body', 'preview', 'text_content']) {
          expect(sql.toLowerCase(), isNot(contains(bad)), reason: bad);
        }
        expect(RegExp('CREATE TABLE|POLICY|OWNER TO').hasMatch(sql), isFalse);
        expect(
          RegExp(
            r'eyJ[A-Za-z0-9_-]{10,}|[0-9a-f]{40,}|https?://',
          ).hasMatch(raw),
          isFalse,
        );
      },
    );
  });

  group('functions are the previous text plus the meetup additions only', () {
    test(
      'msg_evaluate only adds to the KAN-560 text; game and DM paths kept',
      () {
        final prev = _fn(dm, 'msg_evaluate');
        final next = _fn(raw, 'msg_evaluate');
        _onlyAdds(prev, next, 'msg_evaluate');
        final f = _squash(_strip(next));
        expect(f, contains("IF v_kind = 'meetup' THEN"));
        expect(f, contains('IF v_m_owner = p_user_id THEN'));
        expect(f, contains("IF v_m_status = 'going' THEN"));
        expect(f, contains("IF v_m_status = 'cancelled' THEN"));
        expect(f, contains('COALESCE(mt.end_at, mt.start_at)'));
        for (final reason in [
          'game_cancelled',
          'game_ended',
          'left',
          'not_member',
        ]) {
          expect(f, contains("'$reason'::text"), reason: reason);
        }
        expect(f, isNot(contains('meetup_ended')));
        expect(f, isNot(contains('meetup_cancelled')));
        // the meetup block sits after the DM block and before the game lookup
        expect(
          f.indexOf("IF v_kind = 'dm' THEN"),
          lessThan(f.indexOf("IF v_kind = 'meetup' THEN")),
        );
        expect(
          f.indexOf("IF v_kind = 'meetup' THEN"),
          lessThan(f.indexOf('SELECT c.game_id, g.is_cancelled, g.end_at')),
        );
        expect(
          f,
          contains(
            "LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = 'public', 'pg_temp'",
          ),
        );
      },
    );

    test('msg_authorize: one changed CASE line, the rest only added', () {
      final prev = _fn(dm, 'msg_authorize');
      final next = _fn(raw, 'msg_authorize');
      _onlyAdds(
        prev.replaceFirst(
          '         CASE WHEN v_eval.game_id IS NULL THEN\n',
          '         WHEN v_eval.game_id IS NULL THEN\n',
        ),
        next,
        'msg_authorize',
      );
      final f = _squash(_strip(next));
      expect(f, contains("mc.kind = 'meetup'"));
      expect(f, contains("AND r.status = 'going'"));
      expect(f, contains('SELECT mt.creator_user_id AS uid'));
    });

    test(
      'msg_my_conversations only adds a meetup branch to the KAN-555 text',
      () {
        final prev = _fn(
          list,
          'msg_my_conversations',
          kw: 'CREATE FUNCTION',
        ).replaceFirst('CREATE FUNCTION', 'CREATE OR REPLACE FUNCTION');
        final next = _fn(raw, 'msg_my_conversations');
        _onlyAdds(prev, next, 'msg_my_conversations');
        final f = _squash(_strip(next));
        expect(f, contains("WHERE c.kind = 'meetup'"));
        expect(f, contains("'meetup'::text"));
        expect(f, contains("mr.status IN ('going', 'cancelled')"));
        expect(f, contains('mt.creator_user_id = auth.uid()'));
        expect(
          f,
          contains(
            'ORDER BY t.last_activity_at DESC, t.start_at DESC NULLS LAST',
          ),
        );
      },
    );
  });

  test('grants re-asserted as before', () {
    for (final g in [
      'REVOKE ALL ON FUNCTION public.msg_evaluate(uuid, uuid, text) FROM PUBLIC, anon, authenticated;',
      'REVOKE ALL ON FUNCTION public.msg_authorize(uuid, text) FROM PUBLIC, anon;',
      'GRANT EXECUTE ON FUNCTION public.msg_authorize(uuid, text) TO authenticated, service_role;',
      'REVOKE ALL ON FUNCTION public.msg_my_conversations(int) FROM PUBLIC, anon;',
      'GRANT EXECUTE ON FUNCTION public.msg_my_conversations(int) TO authenticated;',
    ]) {
      expect(sql, contains(g), reason: g);
    }
    expect(RegExp('GRANT ').allMatches(sql).length, 2);
  });

  group('probes and rollback', () {
    late String p;
    setUpAll(() => p = File('$_pack/meetup_probes.sql').readAsStringSync());

    test('AUTHORED NOT RUN; every block BEGIN..ROLLBACK; no COMMIT, no DROP', () {
      expect(p.split('\n').first, contains('AUTHORED, NOT RUN'));
      final heads = RegExp(
        r'^-- M\d+ \[(READ-ONLY|WRITE-IN-TRANSACTION-ROLLBACK)\] AUTHORED, NOT RUN\.',
        multiLine: true,
      ).allMatches(p).length;
      expect(heads, 9);
      expect(RegExp(r'^BEGIN;$', multiLine: true).allMatches(p).length, heads);
      expect(
        RegExp(r'^ROLLBACK;$', multiLine: true).allMatches(p).length,
        heads,
      );
      expect(p.toLowerCase(), isNot(contains('commit')));
      expect(RegExp(r'\bdrop\b', caseSensitive: false).hasMatch(p), isFalse);
      for (final m in RegExp(r'\$\$(.*?)\$\$', dotAll: true).allMatches(p)) {
        expect(m.group(1)!.contains(":'"), isFalse);
      }
    });

    test('every case of the brief is present', () {
      for (final c in [
        'pass_going_member_can_send',
        'pass_cancelled_rsvp_reads_to_boundary',
        'pass_ended_meetup_read_only',
        'pass_cancelled_meetup_read_only',
        'pass_non_member_refused',
        'pass_organiser_is_member',
        'pass_meetup_row_has_title_start_end',
        'pass_game_row_unchanged',
        'pass_dm_row_unchanged',
        'pass_game_authorize_unchanged',
        'pass_dm_authorize_unchanged',
      ]) {
        expect(p, contains(c), reason: c);
      }
    });

    test('rollback refuses when meetup rows exist and restores previous texts', () {
      final r = File('$_pack/meetup_rollback.sql').readAsStringSync();
      final s = _squash(_strip(r));
      expect(r, contains('AUTHORED, NOT RUN'));
      expect(
        s,
        contains(
          "if exists (select 1 from public.msg_conversations where kind = 'meetup' or meetup_id is not null) then raise exception",
        ),
      );
      expect(
        s.indexOf('raise exception'),
        lessThan(s.indexOf('DROP CONSTRAINT')),
      );
      expect(s, contains("CHECK (kind IN ('game', 'dm'));"));
      expect(
        s,
        contains(
          "CHECK ((kind = 'game' AND game_id IS NOT NULL) OR (kind = 'dm' AND game_id IS NULL));",
        ),
      );
      expect(r, contains(_fn(dm, 'msg_evaluate')));
      expect(r, contains(_fn(dm, 'msg_authorize')));
      expect(
        r,
        contains(
          _fn(
            list,
            'msg_my_conversations',
            kw: 'CREATE FUNCTION',
          ).replaceFirst('CREATE FUNCTION', 'CREATE OR REPLACE FUNCTION'),
        ),
      );
      final drops = RegExp(
        r'\bDROP\b[^;]*;',
        caseSensitive: false,
      ).allMatches(s).length;
      expect(drops, 2);
    });

    test('README lists the new files', () {
      final r = File('$_pack/README.md').readAsStringSync();
      expect(r, contains('## KAN-558'));
      expect(r, contains('meetup_probes.sql'));
      expect(r, contains('meetup_rollback.sql'));
    });
  });
}
