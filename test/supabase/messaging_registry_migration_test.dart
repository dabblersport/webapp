import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-505 (Messaging T8) migrations and probe pack. The migrations
/// are authored and NOT applied; these tests pin their shape. They run no SQL.
const _dir = 'supabase/migrations';
const _packDir = 'supabase/tests/messaging';
const _registry = '20261013150000_kan505_msg_registry.sql';
const _allowlist = '20261013150100_kan505_msg_access_allowlist.sql';
const _functions = '20261013150200_kan505_msg_functions.sql';
const _realtime = '20261013150300_kan505_msg_realtime_user_topic_policy.sql';
const _mine = [_registry, _allowlist, _functions, _realtime];

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
  late String readme;

  setUpAll(() {
    raw = {for (final n in _mine) n: _read('$_dir/$n')};
    sql = {for (final n in _mine) n: _squash(_stripComments(raw[n]!))};
    probes = _read('$_packDir/probes.sql');
    rollback = _read('$_packDir/rollback.sql');
    readme = _read('$_packDir/README.md');
  });

  group('files', () {
    test('four separate msg_ migrations exist', () {
      final present =
          Directory(_dir)
              .listSync()
              .map((e) => e.uri.pathSegments.last)
              .where((n) => n.contains('kan505'))
              .toList()
            ..sort();
      expect(present, _mine);
      for (final n in _mine) {
        expect(n, contains('msg_'));
      }
    });

    test('each concern lives in its own file', () {
      expect(
        sql[_registry],
        contains('CREATE TABLE IF NOT EXISTS public.msg_conversations'),
      );
      expect(sql[_registry], isNot(contains('FUNCTION')));
      expect(sql[_allowlist], contains('public.msg_access_allowlist'));
      expect(sql[_allowlist], isNot(contains('FUNCTION')));
      expect(sql[_functions], isNot(contains('CREATE TABLE')));
      expect(sql[_functions], isNot(contains('realtime.messages')));
      expect(sql[_realtime], contains('realtime.messages'));
      expect(sql[_realtime], isNot(contains('CREATE TABLE')));
      expect(sql[_realtime], isNot(contains('FUNCTION')));
    });

    test('apply order is registry, allowlist, functions, realtime', () {
      final sorted = [..._mine]..sort();
      expect(sorted, _mine);
    });
  });

  group('no drop', () {
    test('no drop keyword in the migrations or the messaging pack', () {
      for (final n in _mine) {
        expect(_hasDrop(raw[n]!), isFalse, reason: n);
      }
      expect(_hasDrop(probes), isFalse);
      expect(_hasDrop(rollback), isFalse);
      expect(_hasDrop(readme), isFalse);
    });

    test('the drop check fires on a drop', () {
      expect(_hasDrop('DROP TABLE x;'), isTrue);
    });
  });

  group('registry', () {
    test('no message-text column', () {
      final cols = RegExp(
        r'\b(body|text_content|content|message_text|message|preview|snippet)\s+(text|varchar|jsonb)\b',
        caseSensitive: false,
      );
      expect(cols.hasMatch(sql[_registry]!), isFalse);
      expect(cols.hasMatch(sql[_allowlist]!), isFalse);
    });

    test('keyed to games and game_roster', () {
      expect(sql[_registry], contains('REFERENCES public.games (id)'));
      expect(sql[_registry], contains('REFERENCES public.game_roster (id)'));
      expect(sql[_registry], contains('left_at_seq bigint'));
    });

    test('RLS enabled and no anon or authenticated access', () {
      for (final t in ['msg_conversations', 'msg_conversation_members']) {
        expect(
          sql[_registry],
          contains('ALTER TABLE public.$t ENABLE ROW LEVEL SECURITY'),
        );
        expect(
          sql[_registry],
          contains(
            'REVOKE ALL ON TABLE public.$t FROM PUBLIC, anon, authenticated',
          ),
        );
      }
      expect(
        sql[_allowlist],
        contains(
          'ALTER TABLE public.msg_access_allowlist ENABLE ROW LEVEL SECURITY',
        ),
      );
      expect(
        sql[_allowlist],
        contains(
          'REVOKE ALL ON TABLE public.msg_access_allowlist FROM PUBLIC, anon, authenticated',
        ),
      );
      for (final n in [_registry, _allowlist]) {
        expect(sql[n], isNot(contains('CREATE POLICY')));
        expect(
          RegExp(
            r'GRANT [^;]* TO (anon|authenticated|PUBLIC)',
          ).hasMatch(sql[n]!),
          isFalse,
        );
      }
    });
  });

  group('functions', () {
    const fns = [
      'msg_evaluate',
      'msg_can_read',
      'msg_can_send',
      'msg_authorize',
    ];

    test('every function is SECURITY DEFINER with the pinned search_path', () {
      for (final f in fns) {
        final start = sql[_functions]!.indexOf('FUNCTION public.$f(');
        expect(start, greaterThanOrEqualTo(0), reason: f);
        final header = sql[_functions]!.substring(
          start,
          sql[_functions]!.indexOf(r'AS $$', start),
        );
        expect(header, contains('SECURITY DEFINER'), reason: f);
        expect(
          header,
          contains("SET search_path = 'public', 'pg_temp'"),
          reason: f,
        );
      }
    });

    test(
      'revoked from PUBLIC and anon; grants only authenticated / service_role',
      () {
        final s = sql[_functions]!;
        for (final f in fns) {
          expect(
            RegExp(
              'REVOKE ALL ON FUNCTION public\\.$f\\([^)]*\\) FROM PUBLIC, anon',
            ).hasMatch(s),
            isTrue,
            reason: f,
          );
        }
        final grants = RegExp(
          r'GRANT EXECUTE ON FUNCTION [^;]* TO ([^;]*);',
        ).allMatches(s).map((m) => m.group(1)!.trim());
        for (final g in grants) {
          expect(['service_role', 'authenticated, service_role'], contains(g));
        }
        expect(
          s,
          contains(
            'GRANT EXECUTE ON FUNCTION public.msg_authorize(uuid, text) TO authenticated, service_role',
          ),
        );
      },
    );

    test(
      'msg_authorize returns the contracted fields and takes the user from auth.uid()',
      () {
        final s = sql[_functions]!;
        expect(
          s,
          contains(
            'RETURNS TABLE ( user_id uuid, allowed_action text, reason text, '
            'left_at_seq bigint, member_user_ids uuid[], hidden_sender_ids uuid[] )',
          ),
        );
        expect(s, contains('v_uid uuid := auth.uid()'));
        expect(
          s,
          contains("SELECT NULL::uuid, NULL::text, 'not_authenticated'::text"),
        );
      },
    );

    test('typed reasons including not_in_pilot via the allowlist', () {
      final s = sql[_functions]!;
      for (final r in [
        'not_authenticated',
        'messaging_off',
        'not_in_pilot',
        'not_member',
        'removed',
        'read_only',
        'left',
      ]) {
        expect(s, contains("'$r'::text"), reason: r);
      }
      expect(
        s,
        contains(
          "p_access_mode = 'allowlist' AND NOT EXISTS (SELECT 1 FROM public.msg_access_allowlist",
        ),
      );
    });

    test(
      'lifecycle uses end_at / is_cancelled at call time, no trigger or timer',
      () {
        final s = sql[_functions]!;
        expect(s, contains('IF NOT v_cancelled AND v_end_at >= now() THEN'));
        for (final n in _mine) {
          expect(sql[n], isNot(contains('TRIGGER')), reason: n);
          expect(sql[n]!.toLowerCase(), isNot(contains('cron')), reason: n);
        }
      },
    );

    test(
      'roster rule: host/player/sub, active sends, left reads to seq, others removed',
      () {
        final s = sql[_functions]!;
        expect(s, contains("r.role IN ('host', 'player', 'sub')"));
        expect(s, contains("IF v_status = 'active' THEN"));
        expect(s, contains("IF v_status = 'left' THEN"));
        expect(s, contains('COALESCE(v_left_seq, 0)'));
      },
    );

    test('blocks come from user_blocks only, never the restrictions store', () {
      expect(
        sql[_functions],
        contains('FROM public.user_blocks b WHERE b.blocker_user_id = v_uid'),
      );
      for (final n in _mine) {
        expect(
          sql[n]!.toLowerCase(),
          isNot(contains('restrictions')),
          reason: n,
        );
      }
    });
  });

  group('realtime policy', () {
    test('exactly the per-user topic rule, SELECT for authenticated', () {
      final s = sql[_realtime]!;
      expect(
        s,
        contains(
          'CREATE POLICY msg_user_topic_receive ON realtime.messages FOR SELECT TO authenticated',
        ),
      );
      expect(
        s,
        contains("USING (realtime.topic() = 'user:' || auth.uid()::text)"),
      );
      expect(RegExp(r'USING \(').allMatches(s).length, 1);
    });
  });

  group('pack', () {
    test('probes are marked AUTHORED, NOT RUN at the top and per block', () {
      expect(probes.split('\n').first, contains('AUTHORED, NOT RUN'));
      final heads = RegExp(
        r'^-- P\d+b? \[(READ-ONLY|WRITE-IN-TRANSACTION-ROLLBACK)\] AUTHORED, NOT RUN\.',
        multiLine: true,
      ).allMatches(probes).length;
      expect(heads, 11); // P1-P10 plus P6b (KAN-529)
      expect(
        RegExp(r'^begin;$', multiLine: true).allMatches(probes).length,
        heads,
      );
      expect(
        RegExp(r'^rollback;$', multiLine: true).allMatches(probes).length,
        heads,
      );
      expect(probes, isNot(contains('commit;')));
    });

    test('probes cover every required case', () {
      for (final p in [
        'pass_non_member',
        'pass_guessed_id',
        'pass_kicked',
        'pass_left_reads_to_seq',
        'pass_ended_game_ended',
        'pass_cancelled_game_cancelled',
        'pass_blocker_hides_blocked',
        'pass_not_in_pilot',
        'pass_no_uid',
        'pass_a_not_on_b_topic',
      ]) {
        expect(probes, contains(p), reason: p);
      }
      expect(probes, contains("'player', 'kicked'"));
    });

    test('rollback disables, states CEO approval, and is marked', () {
      expect(rollback, contains('AUTHORED, NOT RUN'));
      expect(rollback, contains('CEO'));
      expect(rollback, contains('using (false)'));
      expect(rollback, contains('revoke all on function public.msg_authorize'));
    });

    test('README states honest status and the hold-back', () {
      expect(readme, contains('AUTHORED, NOT RUN'));
      expect(readme, contains('Hold-back'));
      expect(readme, contains('Apply order'));
    });

    test('only wtncuzcskpigqpmnxwws if any project ref appears', () {
      final texts = [...raw.values, probes, rollback, readme];
      for (final t in texts) {
        for (final m in RegExp(r'\b[a-z]{20}\b').allMatches(t)) {
          expect(m.group(0), 'wtncuzcskpigqpmnxwws');
        }
      }
    });
  });
}
