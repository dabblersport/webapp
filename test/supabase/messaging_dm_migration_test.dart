import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-560 migration (DM conversations, mute, start-DM, the daily cap), its probe pack and
/// rollback. Authored and NOT applied/run; these tests run no SQL. They never assert that the migration is the
/// newest one, only that it sorts after a fixed earlier cut-off.
const _dir = 'supabase/migrations';
const _name = '20261013160900_kan560_msg_dm_conversations.sql';
const _kan529 =
    '$_dir/20261013160100_kan529_msg_evaluate_closed_game_reasons.sql';
const _kan505 = '$_dir/20261013150200_kan505_msg_functions.sql';
const _kan547 = '$_dir/20261013160800_kan547_msg_my_conversations.sql';
const _pack = 'supabase/tests/messaging';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// One function definition, from its CREATE to the closing $$;.
String _fn(String sql, String name) {
  final a = sql.indexOf('CREATE OR REPLACE FUNCTION public.$name(');
  expect(a, greaterThanOrEqualTo(0), reason: name);
  final body = sql.indexOf(r'AS $$', a);
  return sql.substring(a, sql.indexOf(r'$$;', body) + 3);
}

String _norm(String fnText) => _squash(_strip(fnText));

void main() {
  late String raw;
  late String sql;

  setUpAll(() {
    raw = File('$_dir/$_name').readAsStringSync();
    sql = _squash(_strip(raw));
  });

  test(
    'exists, sorts after a fixed cut-off, unique version, name avoids the other filters',
    () {
      expect(File('$_dir/$_name').existsSync(), isTrue);
      expect(_name.compareTo('20261013160800'), greaterThan(0));
      expect(_name, contains('msg_dm'));
      expect(_name, isNot(contains('msg_report')));
      expect(_name, isNot(contains('_msg_system')));
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

  group('one transaction, the only two drops', () {
    test('exactly one BEGIN and one COMMIT', () {
      expect(RegExp(r'^BEGIN;$', multiLine: true).allMatches(raw).length, 1);
      expect(RegExp(r'^COMMIT;$', multiLine: true).allMatches(raw).length, 1);
      expect(RegExp('ROLLBACK').hasMatch(sql), isFalse);
    });

    test('the only drops are the old kind check and NOT NULL on game_id', () {
      final drops = RegExp(
        r'\bdrop\b[^;]*;',
        caseSensitive: false,
      ).allMatches(sql).map((m) => m.group(0)).toList();
      expect(drops, [
        'DROP CONSTRAINT IF EXISTS msg_conversations_kind_check;',
        'DROP NOT NULL;',
      ]);
      expect(
        RegExp(
          r'DROP (TABLE|FUNCTION|COLUMN|INDEX|POLICY|TRIGGER|SCHEMA|TYPE)',
        ).hasMatch(sql),
        isFalse,
      );
    });

    test(
      'the kind check is re-added with game and dm, game_id is paired with the kind',
      () {
        expect(
          sql,
          contains(
            "ADD CONSTRAINT msg_conversations_kind_check CHECK (kind IN ('game', 'dm'))",
          ),
        );
        expect(sql, contains('ALTER COLUMN game_id DROP NOT NULL'));
        expect(
          sql,
          contains(
            "CHECK ((kind = 'game' AND game_id IS NOT NULL) OR (kind = 'dm' AND game_id IS NULL))",
          ),
        );
        // the check is re-added after it is dropped
        expect(
          sql.indexOf('DROP CONSTRAINT IF EXISTS msg_conversations_kind_check'),
          lessThan(sql.indexOf('ADD CONSTRAINT msg_conversations_kind_check')),
        );
      },
    );
  });

  group('msg_dm_pairs and muted_at', () {
    late String t;
    setUpAll(() {
      final a = sql.indexOf('CREATE TABLE IF NOT EXISTS public.msg_dm_pairs');
      t = sql.substring(a, sql.indexOf(');', a) + 2);
    });

    test(
      'identifiers only: exactly the five columns, one pair per user pair, ordered',
      () {
        final cols = RegExp(
          r'(?:\(|,) (\w+) (?:uuid|timestamptz)',
        ).allMatches(t).map((m) => m.group(1)).toList();
        expect(cols, [
          'conversation_id',
          'user_low',
          'user_high',
          'started_by',
          'created_at',
        ]);
        expect(
          t,
          contains(
            'conversation_id uuid PRIMARY KEY REFERENCES public.msg_conversations (id)',
          ),
        );
        expect(t, contains('CHECK (user_low < user_high)'));
        expect(t, contains('UNIQUE (user_low, user_high)'));
        expect(t, contains('CHECK (started_by IN (user_low, user_high))'));
        for (final bad in ['body', 'text', 'content', 'message', 'preview']) {
          expect(
            RegExp(
              '\\b$bad\\b',
            ).hasMatch(t.replaceAll('public.msg_conversations', '')),
            isFalse,
            reason: bad,
          );
        }
      },
    );

    test('RLS on, no policy, service_role only', () {
      expect(
        sql,
        contains('ALTER TABLE public.msg_dm_pairs ENABLE ROW LEVEL SECURITY;'),
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON TABLE public.msg_dm_pairs FROM PUBLIC, anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'GRANT SELECT, INSERT, UPDATE ON TABLE public.msg_dm_pairs TO service_role;',
        ),
      );
      expect(sql, isNot(contains('POLICY')));
    });

    test('muted_at is additive', () {
      expect(
        sql,
        contains(
          'ALTER TABLE public.msg_conversation_members ADD COLUMN IF NOT EXISTS muted_at timestamptz;',
        ),
      );
    });
  });

  group('helpers', () {
    test(
      'age from profiles.age (16+ on every profile, at least one profile); deleted/banned from auth.users',
      () {
        final age = _norm(_fn(raw, 'msg_user_age_ok'));
        expect(
          age,
          contains('FROM public.profiles p WHERE p.user_id = p_user'),
        );
        expect(age, contains('p.age IS NULL OR p.age < 16'));
        final un = _norm(_fn(raw, 'msg_user_unavailable'));
        expect(un, contains('FROM auth.users u'));
        expect(un, contains('u.deleted_at IS NULL'));
        expect(
          un,
          contains('u.banned_until IS NULL OR u.banned_until <= now()'),
        );
        for (final f in [age, un]) {
          expect(
            f,
            contains('SECURITY DEFINER SET search_path = public, pg_temp'),
          );
        }
      },
    );

    test('the helpers have no grant to any API role', () {
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.msg_user_unavailable(uuid) FROM PUBLIC, anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.msg_user_age_ok(uuid) FROM PUBLIC, anon, authenticated;',
        ),
      );
      expect(
        RegExp(r'GRANT EXECUTE ON FUNCTION public\.msg_user_').hasMatch(sql),
        isFalse,
      );
    });
  });

  group('msg_evaluate and msg_authorize: game behaviour unchanged', () {
    test(
      'the game path is the KAN-529 text; only the declarations and the DM block are added',
      () {
        final old = _norm(
          _fn(File(_kan529).readAsStringSync(), 'msg_evaluate'),
        );
        var now = _fn(raw, 'msg_evaluate');
        // strip the added block (from its comment to the end of its IF) and the two declarations
        final a = now.indexOf('-- KAN-560: a one-to-one DM');
        final b = now.indexOf(
          "RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, NULL::uuid;\n    RETURN;\n  END IF;\n",
          a,
        );
        expect(a, greaterThan(0));
        expect(b, greaterThan(a));
        final endOfBlock =
            now.indexOf('END IF;\n', b + 60) + 'END IF;\n'.length;
        now = now.substring(0, a) + now.substring(endOfBlock);
        now = now.replaceFirst(
          '  v_kind      text;\n  v_other     uuid;\n',
          '',
        );
        expect(_norm(now), old);
      },
    );

    test(
      'the DM branch: members, either-direction block, unavailable counterpart, send',
      () {
        final e = _norm(_fn(raw, 'msg_evaluate'));
        expect(
          e,
          contains(
            "SELECT c.kind INTO v_kind FROM public.msg_conversations c WHERE c.id = p_conversation_id; IF v_kind = 'dm' THEN",
          ),
        );
        expect(
          e,
          contains(
            'o.conversation_id = me.conversation_id AND o.user_id <> me.user_id',
          ),
        );
        expect(
          e,
          contains(
            "RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;",
          ),
        );
        expect(
          e,
          contains(
            '(b.blocker_user_id = p_user_id AND b.blocked_user_id = v_other) OR (b.blocker_user_id = v_other AND b.blocked_user_id = p_user_id)',
          ),
        );
        expect(
          e,
          contains(
            "RETURN QUERY SELECT 'read'::text, 'blocked'::text, NULL::bigint, NULL::uuid;",
          ),
        );
        expect(e, contains('IF public.msg_user_unavailable(v_other) THEN'));
        expect(
          e,
          contains(
            "RETURN QUERY SELECT 'read'::text, 'suspended'::text, NULL::bigint, NULL::uuid;",
          ),
        );
        expect(
          e,
          contains(
            "RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, NULL::uuid;",
          ),
        );
        // the DM block sits after the access-mode and pilot gates and before the game lookup
        expect(
          e.indexOf("'not_in_pilot'"),
          lessThan(e.indexOf("IF v_kind = 'dm'")),
        );
        expect(
          e.indexOf("IF v_kind = 'dm'"),
          lessThan(
            e.indexOf('FROM public.msg_conversations c JOIN public.games g'),
          ),
        );
        // signature and attributes
        expect(
          e,
          contains(
            'RETURNS TABLE (allowed_action text, reason text, left_at_seq bigint, game_id uuid) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = \'public\', \'pg_temp\'',
          ),
        );
        expect(
          sql,
          contains(
            'REVOKE ALL ON FUNCTION public.msg_evaluate(uuid, uuid, text) FROM PUBLIC, anon, authenticated;',
          ),
        );
      },
    );

    test('msg_authorize differs from KAN-505 only in member_user_ids for a DM', () {
      final old = _norm(_fn(File(_kan505).readAsStringSync(), 'msg_authorize'));
      var now = _fn(raw, 'msg_authorize');
      final a = now.indexOf('CASE WHEN v_eval.game_id IS NULL THEN');
      final elseAt = now.indexOf('ELSE\n', a) + 'ELSE\n'.length;
      final endAt = now.indexOf('END,', elseAt);
      now =
          now.substring(0, a) +
          now.substring(elseAt, endAt) +
          ',' +
          now.substring(endAt + 'END,'.length);
      expect(_norm(now).replaceAll(' ,', ','), old);
      expect(
        _norm(_fn(raw, 'msg_authorize')),
        contains(
          'FROM public.msg_conversation_members m WHERE m.conversation_id = p_conversation_id',
        ),
      );
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.msg_authorize(uuid, text) TO authenticated, service_role;',
        ),
      );
    });

    test(
      'msg_report_message is not re-issued (it only calls msg_evaluate)',
      () {
        expect(sql, isNot(contains('msg_report_message')));
      },
    );
  });

  group('msg_notify', () {
    late String n;
    setUpAll(() => n = _norm(_fn(raw, 'msg_notify')));

    test(
      'KAN-547 behaviour intact: signature, gate, stamp, payload, quiet failure',
      () {
        expect(
          n,
          contains(
            "p_conversation_id uuid, p_seq bigint, p_access_mode text DEFAULT 'allowlist' ) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp",
          ),
        );
        expect(
          n,
          contains(
            'public.msg_evaluate(p_conversation_id, v_uid, p_access_mode)',
          ),
        );
        expect(
          n,
          contains(
            'UPDATE public.msg_conversations SET last_activity_at = now() WHERE id = p_conversation_id',
          ),
        );
        expect(
          n,
          contains(
            "jsonb_build_object( 'type', 'msg', 'conversation_id', p_conversation_id, 'seq', p_seq )",
          ),
        );
        expect(
          n,
          contains(
            "realtime.send(v_payload, 'msg', 'user:' || v_to::text, true)",
          ),
        );
        expect(RegExp('EXCEPTION WHEN OTHERS THEN').allMatches(n).length, 3);
        expect(n, isNot(contains('RAISE EXCEPTION')));
      },
    );

    test('a muted member is skipped, in a game chat and in a DM', () {
      expect(RegExp(r'mm\.muted_at IS NOT NULL').allMatches(n).length, 1);
      expect(n, contains('dm.muted_at IS NULL'));
      expect(n, contains("c.kind = 'dm'"));
      expect(RegExp(r'b\.blocked_user_id = v_uid').allMatches(n).length, 2);
    });

    test('grants re-stated', () {
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.msg_notify(uuid, bigint, text) TO authenticated;',
        ),
      );
    });
  });

  group('msg_set_muted and msg_start_dm', () {
    test(
      'msg_set_muted: auth.uid(), member via msg_evaluate, upsert of the caller own row',
      () {
        final f = _norm(_fn(raw, 'msg_set_muted'));
        expect(
          f,
          contains(
            'msg_set_muted(p_conversation_id uuid, p_muted boolean) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp',
          ),
        );
        expect(f, contains('v_uid uuid := auth.uid()'));
        expect(
          f,
          contains("public.msg_evaluate(p_conversation_id, v_uid, 'all')"),
        );
        expect(
          f,
          contains("RAISE EXCEPTION 'not_member' USING ERRCODE = '42501'"),
        );
        expect(
          f,
          contains(
            'ON CONFLICT (conversation_id, user_id) DO UPDATE SET muted_at = EXCLUDED.muted_at',
          ),
        );
        expect(RegExp(r'p_(user|uid)').hasMatch(f), isFalse);
      },
    );

    test(
      'msg_start_dm: signature, attributes, named cap of 20 per 24 hours, identity auth.uid()',
      () {
        final f = _norm(_fn(raw, 'msg_start_dm'));
        expect(
          f,
          contains(
            'msg_start_dm(p_other_user uuid) RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp',
          ),
        );
        expect(f, contains('msg_dm_daily_cap CONSTANT int := 20;'));
        expect(
          f,
          contains(
            "d.created_at > now() - interval '24 hours') >= msg_dm_daily_cap",
          ),
        );
        expect(f, contains('v_uid uuid := auth.uid()'));
      },
    );

    test(
      'msg_start_dm refusals in the right order, existing pair returned before the cap',
      () {
        final f = _norm(_fn(raw, 'msg_start_dm'));
        final order = [
          "'not_authenticated' USING ERRCODE = '28000'",
          "'invalid_request' USING ERRCODE = '22023'",
          "'age_restricted' USING ERRCODE = '42501'",
          "'not_found' USING ERRCODE = 'P0002'",
          "'blocked' USING ERRCODE = '42501'",
          "'rate_limited' USING ERRCODE = '54000'",
        ];
        var last = -1;
        for (final r in order) {
          final i = f.indexOf(r);
          expect(i, greaterThan(last), reason: r);
          last = i;
        }
        expect(
          f,
          contains(
            'NOT public.msg_user_age_ok(v_uid) OR NOT public.msg_user_age_ok(p_other_user)',
          ),
        );
        expect(f, contains('public.msg_user_unavailable(p_other_user)'));
        expect(
          f,
          contains(
            '(b.blocker_user_id = v_uid AND b.blocked_user_id = p_other_user) OR (b.blocker_user_id = p_other_user AND b.blocked_user_id = v_uid)',
          ),
        );
        expect(f, contains('RETURN v_conv;'));
        expect(
          f.indexOf('RETURN v_conv;'),
          lessThan(f.indexOf("'rate_limited'")),
        );
        expect(f, contains('least(v_uid, p_other_user)'));
        expect(f, contains('greatest(v_uid, p_other_user)'));
        expect(
          f,
          contains(
            "INSERT INTO public.msg_conversations (kind) VALUES ('dm') RETURNING id INTO v_conv",
          ),
        );
        expect(
          f,
          contains(
            'INSERT INTO public.msg_dm_pairs (conversation_id, user_low, user_high, started_by) VALUES (v_conv, v_low, v_high, v_uid)',
          ),
        );
        expect(
          f,
          contains(
            'INSERT INTO public.msg_conversation_members (conversation_id, user_id) VALUES (v_conv, v_low), (v_conv, v_high)',
          ),
        );
        expect(f, contains('pg_advisory_xact_lock'));
      },
    );
  });

  group('grants', () {
    test(
      'msg_start_dm and msg_set_muted: revoked from PUBLIC and anon, executable by authenticated only',
      () {
        for (final sig in [
          'msg_start_dm(uuid)',
          'msg_set_muted(uuid, boolean)',
        ]) {
          expect(
            sql,
            contains('REVOKE ALL ON FUNCTION public.$sig FROM PUBLIC, anon;'),
          );
          expect(
            sql,
            contains('GRANT EXECUTE ON FUNCTION public.$sig TO authenticated;'),
          );
        }
        final grants = RegExp(
          r'GRANT EXECUTE ON FUNCTION public\.(\w+)',
        ).allMatches(sql).map((m) => m.group(1)).toList();
        expect(grants..sort(), [
          'msg_authorize',
          'msg_notify',
          'msg_set_muted',
          'msg_start_dm',
        ]);
        expect(sql, isNot(contains('OWNER TO')));
      },
    );

    test('no content column, no secret, no http', () {
      expect(
        RegExp(r'eyJ[A-Za-z0-9_-]{10,}|[0-9a-f]{40,}|https?://').hasMatch(raw),
        isFalse,
      );
      expect(sql, isNot(contains('CREATE POLICY')));
    });
  });

  group('probes', () {
    late String p;
    setUpAll(() => p = File('$_pack/dm_probes.sql').readAsStringSync());

    test('AUTHORED NOT RUN; every block BEGIN..ROLLBACK; no DROP, no COMMIT', () {
      expect(p.split('\n').first, contains('AUTHORED, NOT RUN'));
      final heads = RegExp(
        r'^-- D\d+ \[(READ-ONLY|WRITE-IN-TRANSACTION-ROLLBACK)\] AUTHORED, NOT RUN\.',
        multiLine: true,
      ).allMatches(p).length;
      expect(heads, 12);
      expect(RegExp(r'^BEGIN;$', multiLine: true).allMatches(p).length, heads);
      expect(
        RegExp(r'^ROLLBACK;$', multiLine: true).allMatches(p).length,
        heads,
      );
      expect(p, isNot(contains('COMMIT')));
      expect(RegExp(r'\bdrop\b', caseSensitive: false).hasMatch(p), isFalse);
    });

    test(
      'no psql variable inside a dollar-quoted body (psql would not substitute it)',
      () {
        for (final m in RegExp(r'\$\$(.*?)\$\$', dotAll: true).allMatches(p)) {
          expect(m.group(1)!.contains(":'"), isFalse, reason: m.group(1));
        }
      },
    );

    test('every case of the brief is present', () {
      for (final c in [
        'pass_dm_kind_no_game',
        'pass_pair_row_with_starter',
        'pass_second_start_same_id',
        'pass_other_side_same_id',
        'pass_target_under_16_refused',
        'pass_target_without_age_refused',
        'pass_caller_under_16_refused',
        'pass_self_refused',
        'pass_caller_blocked_target_refused',
        'pass_target_blocked_caller_refused',
        'pass_banned_target_refused',
        'pass_blocked_side_read_only',
        'pass_blocker_side_read_only',
        'pass_conversation_kept',
        'pass_twentieth_allowed',
        'pass_twentyfirst_new_dm_refused',
        'pass_existing_pair_not_counted',
        'pass_muted_by_member',
        'pass_unmuted_by_member',
        'pass_mute_refused_for_non_member',
        'pass_counterpart_woken',
        'pass_muted_recipient_skipped',
        'pass_notify_never_raises',
        'pass_dm_message_reportable',
        'pass_game_chat_member_still_sends',
        'pass_anon_start_refused',
        'pass_anon_mute_refused',
        'pass_start_dm_authenticated',
        'pass_set_muted_anon_refused',
      ]) {
        expect(p, contains(c), reason: c);
      }
      expect(
        RegExp(
          r'select\s+(payload|m\.payload)\b',
          caseSensitive: false,
        ).hasMatch(p),
        isFalse,
      );
    });
  });

  group('rollback', () {
    late String r;
    setUpAll(() => r = File('$_pack/dm_rollback.sql').readAsStringSync());

    test(
      'refuses when any dm row exists, revokes, restores the previous function texts verbatim',
      () {
        expect(r, contains('AUTHORED, NOT RUN'));
        final s = _squash(_strip(r));
        expect(
          s,
          contains(
            "if exists (select 1 from public.msg_conversations where kind = 'dm') then raise exception 'rollback refused: dm conversations exist'",
          ),
        );
        expect(
          s,
          contains(
            'revoke execute on function public.msg_start_dm(uuid) from authenticated;',
          ),
        );
        expect(
          s,
          contains(
            'revoke execute on function public.msg_set_muted(uuid, boolean) from authenticated;',
          ),
        );
        expect(
          _fn(r, 'msg_evaluate'),
          _fn(File(_kan529).readAsStringSync(), 'msg_evaluate'),
        );
        expect(
          _fn(r, 'msg_authorize'),
          _fn(File(_kan505).readAsStringSync(), 'msg_authorize'),
        );
        expect(
          _fn(r, 'msg_notify'),
          _fn(File(_kan547).readAsStringSync(), 'msg_notify'),
        );
        expect(
          s,
          contains(
            "add constraint msg_conversations_kind_check check (kind = 'game')",
          ),
        );
        expect(s, contains('alter column game_id set not null'));
      },
    );

    test(
      'the only removals are the two new constraints; nothing else is dropped',
      () {
        final drops = RegExp(
          r'\bdrop\b[^;]*;',
          caseSensitive: false,
        ).allMatches(_squash(_strip(r))).map((m) => m.group(0)).toList();
        expect(drops, [
          'drop constraint if exists msg_conversations_kind_game_check;',
          'drop constraint if exists msg_conversations_kind_check;',
        ]);
        expect(
          RegExp(
            r'drop (table|function|column|index)',
            caseSensitive: false,
          ).hasMatch(r),
          isFalse,
        );
      },
    );
  });

  test('README lists the new files', () {
    final r = File('$_pack/README.md').readAsStringSync();
    expect(r, contains('## KAN-560'));
    expect(r, contains('dm_probes.sql'));
    expect(r, contains('dm_rollback.sql'));
  });

  test(
    'probe setup is idempotent: every allowlist insert is ON CONFLICT DO NOTHING',
    () {
      final p = File('$_pack/dm_probes.sql').readAsStringSync();
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
