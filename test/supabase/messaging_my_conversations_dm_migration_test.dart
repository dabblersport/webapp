import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-555 migration (DM rows in the Messages list), its probe pack and rollback. Authored and NOT
/// applied/run; these tests run no SQL. They never assert that the migration is the newest one, only that it sorts after
/// a fixed earlier cut-off.
const _dir = 'supabase/migrations';
const _name = '20261013161000_kan555_msg_my_conversations_dm.sql';
const _v1 = '$_dir/20261013160800_kan547_msg_my_conversations.sql';
const _pack = 'supabase/tests/messaging';

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

void main() {
  late String raw;
  late String sql;
  late String f;
  late String v1;

  setUpAll(() {
    raw = File('$_dir/$_name').readAsStringSync();
    sql = _squash(_strip(raw));
    f = _squash(
      _strip(_fn(raw, 'msg_my_conversations', kw: 'CREATE FUNCTION')),
    );
    v1 = _squash(
      _strip(_fn(File(_v1).readAsStringSync(), 'msg_my_conversations')),
    );
  });

  test(
    'exists, sorts after a fixed cut-off, unique version, name keeps the filters off',
    () {
      expect(File('$_dir/$_name').existsSync(), isTrue);
      expect(_name.compareTo('20261013160900'), greaterThan(0));
      expect(_name, contains('msg_my_conversations_dm'));
      expect(_name, isNot(contains('msg_report')));
      final same = Directory(_dir)
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .where(
            (n) =>
                RegExp(r'^\d{14}_').hasMatch(n) &&
                n.startsWith(_name.substring(0, 14)),
          );
      expect(same.length, 1);
    },
  );

  group('rename, not remove', () {
    test('one transaction; v1 is renamed and revoked; nothing is removed', () {
      expect(RegExp(r'^BEGIN;$', multiLine: true).allMatches(raw).length, 1);
      expect(RegExp(r'^COMMIT;$', multiLine: true).allMatches(raw).length, 1);
      expect(
        sql,
        contains(
          'ALTER FUNCTION public.msg_my_conversations(int) RENAME TO msg_my_conversations_v1;',
        ),
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.msg_my_conversations_v1(int) FROM PUBLIC, anon, authenticated;',
        ),
      );
      expect(_hasDrop(raw), isFalse);
      expect(
        sql,
        isNot(
          contains('CREATE OR REPLACE FUNCTION public.msg_my_conversations('),
        ),
      );
      expect(
        RegExp('CREATE TABLE|ALTER TABLE|CREATE INDEX|POLICY').hasMatch(sql),
        isFalse,
      );
    });

    test('the header explains why CREATE OR REPLACE could not be used', () {
      expect(raw, contains('cannot change return type of'));
    });
  });

  group('columns', () {
    test(
      'the v1 columns first and unchanged, then exactly the five new ones',
      () {
        const v1Cols = [
          'conversation_id uuid',
          'game_id uuid',
          'game_title text',
          'sport text',
          'start_at timestamptz',
          'end_at timestamptz',
          'state text',
          'last_activity_at timestamptz',
        ];
        const newCols = [
          'kind text',
          'counterpart_user_id uuid',
          'counterpart_name text',
          'counterpart_avatar text',
          'muted boolean',
        ];
        final a = f.indexOf('RETURNS TABLE (');
        final cols = f
            .substring(a + 'RETURNS TABLE ('.length, f.indexOf(') LANGUAGE', a))
            .split(',')
            .map((c) => c.trim())
            .toList();
        expect(cols, [...v1Cols, ...newCols]);
        // and v1 has exactly the first eight
        final b = v1.indexOf('RETURNS TABLE (');
        final old = v1
            .substring(
              b + 'RETURNS TABLE ('.length,
              v1.indexOf(') LANGUAGE', b),
            )
            .split(',')
            .map((c) => c.trim())
            .toList();
        expect(old, v1Cols);
      },
    );

    test('no content, preview, sender or unread column; no member list', () {
      for (final bad in [
        'body',
        'content',
        'preview',
        'unread',
        'sender',
        'member_user_ids',
        'array_agg',
        'text_content',
      ]) {
        expect(f.toLowerCase(), isNot(contains(bad)), reason: bad);
      }
    });
  });

  group('game rows are the KAN-547 rules', () {
    test(
      'state rules, membership rule, sport name, join, order and limit all kept',
      () {
        for (final piece in [
          "WHEN m.status = 'left' THEN 'left'",
          "WHEN g.is_cancelled OR g.end_at < now() THEN 'read_only'",
          "ELSE 'send'",
          "r.role IN ('host', 'player', 'sub')",
          "ORDER BY (r.status = 'active') DESC, (r.status = 'left') DESC, r.joined_at DESC LIMIT 1",
          "m.status IN ('active', 'left')",
          'LEFT JOIN public.sports s ON s.id = g.sport_id',
          's.name_en',
          'JOIN public.games g ON g.id = c.game_id',
          'auth.uid() IS NOT NULL',
          'LIMIT least(greatest(coalesce(p_limit, 50), 1), 100)',
        ]) {
          expect(v1, contains(piece), reason: 'v1 lost $piece');
          expect(f, contains(piece), reason: piece);
        }
        expect(f, contains("'game'::text AS kind"));
        expect(f, contains('NULL::uuid AS counterpart_user_id'));
      },
    );

    test(
      'order: last activity first, ties by start_at; limit clamp unchanged',
      () {
        expect(
          f,
          contains(
            'ORDER BY t.last_activity_at DESC, t.start_at DESC NULLS LAST',
          ),
        );
      },
    );
  });

  group('DM rows', () {
    test('membership, kind and the empty-DM rule', () {
      expect(
        f,
        contains('JOIN public.msg_dm_pairs d ON d.conversation_id = c.id'),
      );
      expect(
        f,
        contains(
          'JOIN public.msg_conversation_members me ON me.conversation_id = c.id AND me.user_id = auth.uid()',
        ),
      );
      expect(
        f,
        contains(
          'JOIN public.msg_conversation_members o ON o.conversation_id = c.id AND o.user_id <> auth.uid()',
        ),
      );
      expect(f, contains("WHERE c.kind = 'dm'"));
      expect(
        f,
        contains(
          'AND (d.started_by = auth.uid() OR c.last_activity_at > c.created_at)',
        ),
      );
      expect(f, contains("'dm'::text"));
    });

    test(
      'read_only for a block in either direction or an unavailable counterpart',
      () {
        expect(
          f,
          contains(
            '(b.blocker_user_id = auth.uid() AND b.blocked_user_id = o.user_id) OR (b.blocker_user_id = o.user_id AND b.blocked_user_id = auth.uid())',
          ),
        );
        expect(f, contains('public.msg_user_unavailable(o.user_id)'));
        expect(f, contains("THEN 'read_only' ELSE 'send'"));
      },
    );

    test('muted is the caller own flag, for DMs and game chats', () {
      expect(f, contains('me.muted_at IS NOT NULL'));
      expect(
        f,
        contains('mm.user_id = auth.uid() AND mm.muted_at IS NOT NULL'),
      );
    });

    test('name and avatar come from the public profile view only', () {
      expect(f, contains('JOIN public.v_profile_public v ON v.id = p.id'));
      expect(f, contains('SELECT v.display_name, v.avatar_url'));
      expect(
        f,
        contains(
          "ORDER BY (p.profile_type = 'personal') DESC, p.created_at ASC LIMIT 1",
        ),
      );
      for (final bad in [
        'p.age',
        'p.bio',
        'p.city',
        'p.username',
        'p.gender',
        'p.latitude',
        'p.longitude',
        'p.persona_type',
        'p.language',
        'p.last_seen',
      ]) {
        expect(f, isNot(contains(bad)), reason: bad);
      }
    });
  });

  group('grants', () {
    test('definer, pinned search_path, identity auth.uid(), authenticated only', () {
      expect(f, contains('msg_my_conversations(p_limit int DEFAULT 50)'));
      expect(
        f,
        contains(
          'LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp',
        ),
      );
      expect(RegExp(r'p_(user|uid|member|profile)').hasMatch(f), isFalse);
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
      expect(RegExp('GRANT').allMatches(sql).length, 1);
      expect(sql, isNot(contains('OWNER TO')));
      expect(sql, isNot(contains('service_role')));
    });

    test('no secret', () {
      expect(
        RegExp(r'eyJ[A-Za-z0-9_-]{10,}|[0-9a-f]{40,}|https?://').hasMatch(raw),
        isFalse,
      );
    });
  });

  group('probes and rollback', () {
    late String p;
    setUpAll(
      () =>
          p = File('$_pack/my_conversations_dm_probes.sql').readAsStringSync(),
    );

    test('AUTHORED NOT RUN; every block BEGIN..ROLLBACK; no DROP', () {
      expect(p.split('\n').first, contains('AUTHORED, NOT RUN'));
      final heads = RegExp(
        r'^-- L\d+ \[(READ-ONLY|WRITE-IN-TRANSACTION-ROLLBACK)\] AUTHORED, NOT RUN\.',
        multiLine: true,
      ).allMatches(p).length;
      expect(heads, 8);
      expect(RegExp(r'^BEGIN;$', multiLine: true).allMatches(p).length, heads);
      expect(
        RegExp(r'^ROLLBACK;$', multiLine: true).allMatches(p).length,
        heads,
      );
      expect(p, isNot(contains('COMMIT')));
      expect(_hasDrop(p), isFalse);
    });

    test(
      'setup is idempotent and no psql variable sits inside a dollar-quoted body',
      () {
        final inserts = RegExp(
          r'insert into public\.msg_access_allowlist[^;]*;',
        ).allMatches(p).toList();
        expect(inserts, isNotEmpty);
        for (final m in inserts) {
          expect(m.group(0), contains('on conflict (user_id) do nothing'));
        }
        for (final m in RegExp(r'\$\$(.*?)\$\$', dotAll: true).allMatches(p)) {
          expect(m.group(1)!.contains(":'"), isFalse);
        }
      },
    );

    test('every case of the brief is present', () {
      for (final c in [
        'pass_starter_sees_dm',
        'pass_recipient_sees_dm_after_first_message',
        'pass_starter_counterpart_is_b',
        'pass_recipient_counterpart_is_a',
        'pass_counterpart_name_is_the_public_name',
        'pass_counterpart_avatar_is_the_public_avatar',
        'pass_dm_row_has_no_game_fields',
        'pass_empty_dm_listed_for_starter',
        'pass_empty_dm_hidden_from_recipient',
        'pass_blocked_side_read_only',
        'pass_blocker_side_read_only',
        'pass_block_in_the_other_direction_read_only',
        'pass_unblocked_send_again',
        'pass_banned_counterpart_read_only',
        'pass_deleted_counterpart_read_only',
        'pass_muter_sees_muted_true',
        'pass_other_side_still_false',
        'pass_game_send_unchanged',
        'pass_game_read_only_unchanged',
        'pass_game_left_unchanged',
        'pass_kicked_game_still_absent',
        'pass_game_rows_have_null_counterpart',
        'pass_dm_ordered_with_games_by_last_activity',
        'pass_non_participant_sees_nothing',
        'pass_limit_capped_at_100',
        'pass_anon_refused',
        'pass_exact_columns',
        'pass_v1_not_callable_by_app',
        'pass_authenticated_can_execute',
        'pass_anon_cannot_execute',
      ]) {
        expect(p, contains(c), reason: c);
      }
    });

    test('rollback swaps the names back; nothing is removed', () {
      final r = File(
        '$_pack/my_conversations_dm_rollback.sql',
      ).readAsStringSync();
      final s = _squash(_strip(r));
      expect(r, contains('AUTHORED, NOT RUN'));
      expect(_hasDrop(r), isFalse);
      expect(
        s,
        contains(
          'alter function public.msg_my_conversations(int) rename to msg_my_conversations_dm_off;',
        ),
      );
      expect(
        s,
        contains(
          'alter function public.msg_my_conversations_v1(int) rename to msg_my_conversations;',
        ),
      );
      expect(
        s,
        contains(
          'grant execute on function public.msg_my_conversations(int) to authenticated;',
        ),
      );
      expect(
        s.indexOf('rename to msg_my_conversations_dm_off'),
        lessThan(s.indexOf('rename to msg_my_conversations;')),
      );
    });

    test('README lists the new files', () {
      final r = File('$_pack/README.md').readAsStringSync();
      expect(r, contains('## KAN-555'));
      expect(r, contains('my_conversations_dm_probes.sql'));
      expect(r, contains('my_conversations_dm_rollback.sql'));
    });
  });
}
