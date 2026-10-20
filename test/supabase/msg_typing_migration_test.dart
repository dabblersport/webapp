import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-579 migration (public.msg_typing), its probe pack
/// and rollback. Authored and NOT applied/run; these tests run no SQL.
const _dir = 'supabase/migrations';
const _name = '20261020140000_kan579_msg_typing.sql';
const _packDir = 'supabase/tests/messaging';
const _sig = 'public.msg_typing(uuid, boolean, text)';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  late String sql;

  setUpAll(() {
    sql = _squash(_strip(File('$_dir/$_name').readAsStringSync()));
  });

  test('sorts after the latest migration it builds on; unique version', () {
    expect(_name.compareTo('20261020130000'), greaterThan(0));
    final same = Directory(_dir)
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((n) => n.startsWith(_name.substring(0, 14)));
    expect(same.length, 1);
  });

  test(
    'ephemeral: no DROP, no write to any table, no policy, no owner change',
    () {
      final up = sql.toUpperCase();
      for (final bad in [
        'DROP ',
        'INSERT ',
        'UPDATE ',
        'DELETE ',
        'TRUNCATE',
        'ALTER TABLE',
        'CREATE TABLE',
        'POLICY',
        'OWNER TO',
        'NOTIFICATIONS',
        'LAST_ACTIVITY_AT',
      ]) {
        expect(up, isNot(contains(bad)), reason: bad);
      }
    },
  );

  test(
    'definer with a pinned search_path; the signature is the one the Worker calls',
    () {
      expect(sql, contains('CREATE OR REPLACE FUNCTION public.msg_typing('));
      expect(
        sql,
        contains(
          'p_conversation_id uuid, p_typing boolean, p_access_mode text DEFAULT \'allowlist\'',
        ),
      );
      expect(sql, contains('SECURITY DEFINER'));
      expect(sql, contains('SET search_path = public, pg_temp'));
    },
  );

  test('identity is auth.uid(); the caller must pass the send gate', () {
    expect(sql, contains('v_uid uuid := auth.uid()'));
    expect(
      sql,
      contains('public.msg_evaluate(p_conversation_id, v_uid, p_access_mode)'),
    );
    expect(
      sql,
      contains("v_eval.allowed_action IS DISTINCT FROM 'send' THEN RETURN"),
    );
  });

  test(
    'one private broadcast per recipient on the user topic, event typing',
    () {
      expect(
        sql,
        contains(
          "realtime.send(v_payload, 'typing', 'user:' || v_to::text, true)",
        ),
      );
      expect(RegExp('realtime\\.send').allMatches(sql).length, 1);
    },
  );

  test('the payload is exactly type, conversation_id, user_id, on', () {
    expect(
      sql,
      contains(
        "jsonb_build_object( 'type', 'typing', 'conversation_id', p_conversation_id, 'user_id', v_uid, 'on', p_typing )",
      ),
    );
    for (final never in ['body', 'text,', 'name', 'draft']) {
      final payload = RegExp(
        r"jsonb_build_object\([^;]*\)",
      ).firstMatch(sql)!.group(0)!;
      expect(payload, isNot(contains("'$never'")), reason: never);
    }
  });

  test(
    'recipients: current roster or DM members, never the caller, blockers or muted',
    () {
      expect(sql, contains("r.status = 'active'"));
      expect(sql, contains("r.role IN ('host', 'player', 'sub')"));
      expect(sql, contains('r.user_id <> v_uid'));
      expect(sql, contains('dm.user_id <> v_uid'));
      expect(
        sql,
        contains('b.blocker_user_id = r.user_id AND b.blocked_user_id = v_uid'),
      );
      expect(
        sql,
        contains(
          'b.blocker_user_id = dm.user_id AND b.blocked_user_id = v_uid',
        ),
      );
      expect(sql, contains('mm.muted_at IS NOT NULL'));
      expect(sql, contains('dm.muted_at IS NULL'));
    },
  );

  test(
    'failures are swallowed with the sqlstate only; never raises to the caller',
    () {
      expect(
        sql,
        contains(
          "RAISE WARNING 'msg_typing send failed (sqlstate %)', SQLSTATE",
        ),
      );
      expect(
        sql,
        contains("RAISE WARNING 'msg_typing failed (sqlstate %)', SQLSTATE"),
      );
      expect(RegExp('RAISE EXCEPTION').hasMatch(sql), isFalse);
      expect(
        RegExp(
          r"RAISE WARNING '[^']*',[^;]*(v_payload|p_conversation_id|v_uid)",
        ).hasMatch(sql),
        isFalse,
      );
    },
  );

  test('grants: authenticated only', () {
    expect(sql, contains('REVOKE ALL ON FUNCTION $_sig FROM PUBLIC, anon'));
    expect(sql, contains('GRANT EXECUTE ON FUNCTION $_sig TO authenticated'));
    expect(sql, isNot(contains('TO anon')));
  });

  test(
    'probe pack covers the acceptance cases; rollback revokes and drops nothing',
    () {
      final probes = File('$_packDir/typing_probes.sql').readAsStringSync();
      expect(probes, contains('AUTHORED, NOT RUN'));
      for (final marker in [
        'pass_b_signalled',
        'pass_typer_not_signalled',
        'pass_exactly_four_keys',
        'pass_stop_delivered',
        'pass_non_member_and_removed_queue_none',
        'pass_blocker_not_signalled',
        'pass_muted_not_signalled',
        'pass_no_notification_or_push',
        'pass_bad_input_queues_none',
        'pass_anon_denied',
      ]) {
        expect(probes, contains(marker), reason: marker);
      }
      final blocks = RegExp(
        r'\[WRITE-IN-TRANSACTION-ROLLBACK\]',
      ).allMatches(probes).length;
      expect(
        RegExp(r'^ROLLBACK;$', multiLine: true).allMatches(probes).length,
        blocks,
      );

      final rollback = _squash(
        _strip(File('$_packDir/typing_rollback.sql').readAsStringSync()),
      );
      expect(rollback.toUpperCase(), isNot(contains('DROP')));
      expect(
        rollback,
        contains(
          'revoke all on function $_sig from public, anon, authenticated',
        ),
      );
    },
  );
}
