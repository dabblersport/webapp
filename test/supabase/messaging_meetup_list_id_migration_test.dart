import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-559 migration (meetup id in msg_my_conversations), its probe pack and rollback.
/// Authored and NOT applied/run; these tests run no SQL. For kind meetup, game_id carries the meetup id.
const _dir = 'supabase/migrations';
const _name = '20261017140000_kan559_msg_my_conversations_meetup_id.sql';
const _prev = '$_dir/20261017130000_kan558_msg_meetup_chat.sql';
const _pack = 'supabase/tests/messaging';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String _fn(String sql, String name) {
  final a = sql.indexOf('CREATE OR REPLACE FUNCTION public.$name(');
  expect(a, greaterThanOrEqualTo(0), reason: name);
  final body = sql.indexOf(r'AS $$', a);
  return sql.substring(a, sql.indexOf(r'$$;', body) + 3);
}

void main() {
  late String raw;
  late String sql;
  late String prev;

  setUpAll(() {
    raw = File('$_dir/$_name').readAsStringSync();
    sql = _squash(_strip(raw));
    prev = File(_prev).readAsStringSync();
  });

  test('exists, sorts after KAN-558, unique version, named kan559', () {
    expect(File('$_dir/$_name').existsSync(), isTrue);
    expect(_name.compareTo('20261017130000'), greaterThan(0));
    expect(_name, contains('kan559'));
    final same = Directory(_dir)
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((n) => n.startsWith(_name.substring(0, 14)));
    expect(same.length, 1);
  });

  test(
    'one transaction, no DROP, no content column, header states the rule',
    () {
      expect(RegExp(r'^BEGIN;$', multiLine: true).allMatches(raw).length, 1);
      expect(RegExp(r'^COMMIT;$', multiLine: true).allMatches(raw).length, 1);
      expect(RegExp(r'\bDROP\b', caseSensitive: false).hasMatch(sql), isFalse);
      for (final bad in ['content', 'body', 'preview', 'text_content']) {
        expect(sql.toLowerCase(), isNot(contains(bad)), reason: bad);
      }
      expect(RegExp('CREATE TABLE|POLICY|OWNER TO').hasMatch(sql), isFalse);
      expect(raw, contains('for kind meetup, game_id carries the meetup id'));
    },
  );

  test('only the meetup branch game_id expression differs from KAN-558', () {
    final a = _fn(prev, 'msg_my_conversations').split('\n');
    final b = _fn(raw, 'msg_my_conversations').split('\n');
    expect(b.length, a.length);
    final diffs = <int>[
      for (var i = 0; i < a.length; i++)
        if (a[i] != b[i]) i,
    ];
    expect(diffs.length, 1);
    final i = diffs.single;
    expect(a[i], '             NULL::uuid,');
    expect(b[i], '             mt.id,');
    // the changed line is in the meetup branch: after the last UNION ALL, right after SELECT c.id,
    expect(b[i - 1], '      SELECT c.id,');
    expect(b[i + 1], '             mt.title,');
    expect(i, greaterThan(b.lastIndexOf('      UNION ALL')));
    final f = _squash(_strip(b.join('\n')));
    expect(
      f,
      contains(
        'LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp',
      ),
    );
  });

  test('grants re-asserted as KAN-558 did', () {
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
    expect(RegExp('GRANT ').allMatches(sql).length, 1);
  });

  group('probes and rollback', () {
    late String p;
    setUpAll(
      () => p = File('$_pack/meetup_list_id_probes.sql').readAsStringSync(),
    );

    test('AUTHORED NOT RUN; every block BEGIN..ROLLBACK; no COMMIT, no DROP', () {
      expect(p.split('\n').first, contains('AUTHORED, NOT RUN'));
      final heads = RegExp(
        r'^-- M\d+ \[(READ-ONLY|WRITE-IN-TRANSACTION-ROLLBACK)\] AUTHORED, NOT RUN\.',
        multiLine: true,
      ).allMatches(p).length;
      expect(heads, 3);
      expect(RegExp(r'^BEGIN;$', multiLine: true).allMatches(p).length, heads);
      expect(
        RegExp(r'^ROLLBACK;$', multiLine: true).allMatches(p).length,
        heads,
      );
      expect(p.toLowerCase(), isNot(contains('commit')));
      expect(RegExp(r'\bdrop\b', caseSensitive: false).hasMatch(p), isFalse);
    });

    test('every case of the brief is present', () {
      for (final c in [
        'pass_going_member_gets_meetup_id',
        'pass_organiser_gets_meetup_id',
        'pass_game_row_keeps_game_id',
        'pass_dm_row_game_id_null',
        'pass_outsider_sees_no_meetup_row',
      ]) {
        expect(p, contains(c), reason: c);
      }
    });

    test('rollback restores the KAN-558 definition verbatim, with grants', () {
      final r = File('$_pack/meetup_list_id_rollback.sql').readAsStringSync();
      expect(r, contains('AUTHORED, NOT RUN'));
      expect(r, contains(_fn(prev, 'msg_my_conversations')));
      final s = _squash(_strip(r));
      expect(
        s,
        contains(
          'REVOKE ALL ON FUNCTION public.msg_my_conversations(int) FROM PUBLIC, anon;',
        ),
      );
      expect(
        s,
        contains(
          'GRANT EXECUTE ON FUNCTION public.msg_my_conversations(int) TO authenticated;',
        ),
      );
      expect(RegExp(r'\bDROP\b', caseSensitive: false).hasMatch(s), isFalse);
    });

    test('README lists the new files', () {
      final r = File('$_pack/README.md').readAsStringSync();
      expect(r, contains('## KAN-559'));
      expect(r, contains('meetup_list_id_probes.sql'));
      expect(r, contains('meetup_list_id_rollback.sql'));
      expect(r, contains('for kind meetup,\ngame_id carries the meetup id'));
    });
  });
}
