import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-542 migration (msg_system_notify also wakes the post-change roster
/// through Realtime), its probe pack and rollback. Authored and NOT applied/run; these tests run no
/// SQL and do not assert that the migration is the newest one.
const _name = '20261013160700_kan542_msg_system_wake.sql';
const _migration = 'supabase/migrations/$_name';
const _kan539 =
    'supabase/migrations/20261013160500_kan539_msg_system_notify_vault.sql';
const _probes = 'supabase/tests/messaging/system_wake_probes.sql';
const _rollback = 'supabase/tests/messaging/system_wake_rollback.sql';
const _url =
    'https://dabbler-messaging-staging.dabbler-sport.workers.dev/internal/system-line';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// The function statement (CREATE OR REPLACE .. $fn$;), squashed.
String _fn(String sql) {
  final s = _squash(_strip(sql));
  final a = s.indexOf('CREATE OR REPLACE FUNCTION');
  return s.substring(a, s.indexOf('\$fn\$;', a) + 5);
}

void main() {
  late String raw;
  late String sql;
  late String fn;
  late String probes;
  late String rollback;

  setUpAll(() {
    raw = File(_migration).readAsStringSync();
    sql = _squash(_strip(raw));
    fn = _fn(raw);
    probes = File(_probes).readAsStringSync();
    rollback = File(_rollback).readAsStringSync();
  });

  group('migration', () {
    test('sorts after KAN-541, has a unique version and avoids msg_report', () {
      expect(_name.compareTo('20261013160600'), greaterThan(0));
      expect(_name, isNot(contains('msg_report')));
      final versions = Directory('supabase/migrations')
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .where((n) => RegExp(r'^\d{14}_').hasMatch(n))
          .map((n) => n.substring(0, 14))
          .toList();
      expect(versions.where((v) => v == _name.substring(0, 14)).length, 1);
    });

    test('redefines only msg_system_notify, no DROP, no other statement', () {
      expect(
        RegExp(
          r'CREATE OR REPLACE FUNCTION (public\.\w+)',
        ).allMatches(sql).map((m) => m.group(1)).toList(),
        ['public.msg_system_notify'],
      );
      expect(raw, isNot(matches(RegExp(r'drop', caseSensitive: false))));
      expect(sql, isNot(contains('CREATE TRIGGER')));
      expect(sql, isNot(contains('ALTER ')));
      expect(sql, isNot(contains('GRANT EXECUTE')));
    });

    test('keeps everything from KAN-539 and adds only the guarded wake', () {
      // Remove the added wake block and the two added declarations: what is
      // left must equal the KAN-539 function exactly.
      final start = fn.indexOf('BEGIN v_payload :=');
      final end = fn.indexOf(
        'END; EXCEPTION WHEN OTHERS THEN RAISE WARNING \'msg_system_notify failed',
      );
      expect(start, greaterThan(0));
      expect(end, greaterThan(start));
      final withoutWake =
          fn.substring(0, start) + fn.substring(end + 'END; '.length);
      final withoutDecls = withoutWake.replaceFirst(
        'v_payload jsonb; v_to uuid; ',
        '',
      );
      expect(withoutDecls, _fn(File(_kan539).readAsStringSync()));
    });

    test(
      'the wake runs after the enqueue, so only when the line is queued',
      () {
        expect(
          fn.indexOf('PERFORM net.http_post'),
          lessThan(fn.indexOf('realtime.send')),
        );
        expect(RegExp(r'PERFORM net\.http_post').allMatches(fn).length, 1);
      },
    );

    test('keeps the signature, definer, empty search_path, Vault and URL', () {
      expect(
        sql,
        contains(
          'public.msg_system_notify(p_event text, p_game_id uuid, p_user_id uuid) RETURNS void',
        ),
      );
      expect(
        sql,
        contains('LANGUAGE plpgsql SECURITY DEFINER SET search_path = \'\''),
      );
      expect(sql, contains('FROM vault.decrypted_secrets s'));
      expect(sql, contains("WHERE s.name = 'msg_hmac_secret'"));
      expect(sql, contains("v_url constant text := '$_url'"));
      expect(
        RegExp(
          r'https?://[^\s\x27]+',
        ).allMatches(sql).map((m) => m.group(0)).toSet(),
        {_url},
      );
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.msg_system_notify(text, uuid, uuid) FROM PUBLIC, anon, authenticated',
        ),
      );
    });

    test('the wake is private, schema-qualified and seq-less', () {
      expect(
        fn,
        contains(
          "PERFORM realtime.send(v_payload, 'msg', 'user:' || v_to::text, true);",
        ),
      );
      expect(
        RegExp(r'realtime\.send').allMatches(fn).length,
        1,
        reason: 'one call site',
      );
      expect(
        fn,
        contains(
          "v_payload := jsonb_build_object('type', 'sync', 'conversation_id', v_conv);",
        ),
      );
      expect(fn, isNot(contains("'seq'")));
      expect(fn, isNot(contains("'text'")));
      expect(fn, isNot(contains("'event', 'sync'")));
    });

    test('wakes the post-change active roster only', () {
      expect(
        fn,
        contains(
          'SELECT DISTINCT r.user_id FROM public.game_roster r WHERE r.game_id = p_game_id AND r.status = \'active\' AND r.role IN (\'host\', \'player\', \'sub\')',
        ),
      );
      expect(fn, isNot(contains('p_user_id <>')));
      expect(fn, isNot(contains('r.user_id <>')));
    });

    test('the wake has its own exception block with sqlstate-only warnings', () {
      expect(
        fn,
        contains(
          "EXCEPTION WHEN OTHERS THEN RAISE WARNING 'msg_system_notify wake failed (sqlstate %)', SQLSTATE; END; EXCEPTION WHEN OTHERS THEN RAISE WARNING 'msg_system_notify failed (sqlstate %)', SQLSTATE; END;",
        ),
      );
      for (final m in RegExp(
        r"RAISE WARNING '[^']*', ([^;]*);",
      ).allMatches(fn)) {
        expect(m.group(1), 'SQLSTATE', reason: 'warnings carry only sqlstate');
      }
    });

    test('contains no literal secret or key-like string; not applied', () {
      for (final bad in [
        RegExp(r'eyJ[A-Za-z0-9_-]{10,}'),
        RegExp(r'sha256=[0-9a-f]{16,}'),
        RegExp(r'[0-9a-f]{40,}'),
        RegExp(r'postgres(ql)?://'),
      ]) {
        expect(bad.hasMatch(raw), isFalse, reason: bad.pattern);
      }
      expect(raw, contains('AUTHORED, NOT APPLIED'));
    });
  });

  group('probes and rollback', () {
    test('both say AUTHORED, NOT RUN', () {
      expect(probes, contains('AUTHORED, NOT RUN'));
      expect(rollback, contains('AUTHORED, NOT RUN'));
    });

    test('every probe block is wrapped and rolled back, never committed', () {
      var depth = 0;
      var blocks = 0;
      for (final l in probes.split('\n')) {
        final line = l.trim();
        if (line.isEmpty || line.startsWith('--')) continue;
        if (line == 'begin;' || line == 'begin read only;') {
          expect(depth, 0);
          depth = 1;
          blocks++;
          continue;
        }
        if (line == 'rollback;') {
          expect(depth, 1);
          depth = 0;
          continue;
        }
        expect(depth, 1, reason: 'outside a wrapper: $line');
      }
      expect(depth, 0);
      expect(blocks, 6);
      expect(probes, contains('[READ-ONLY]'));
      expect(probes, contains('[WRITE-IN-TRANSACTION-ROLLBACK]'));
      expect(
        probes,
        isNot(matches(RegExp(r'^\s*commit\s*;', multiLine: true))),
      );
      expect(probes, isNot(matches(RegExp(r'drop', caseSensitive: false))));
    });

    test(
      'probes cover join, removal, leave, cancel, failure; Vault-missing is NOT RUN',
      () {
        for (final s in [
          'pass_system_line_queued',
          'pass_joiner_b_woken_once',
          'pass_all_private',
          'pass_exactly_type_and_conversation_id',
          'pass_removed_not_woken',
          'pass_cancel_request_queued',
          'pass_no_conversation_no_wake',
          'pass_roster_change_succeeded',
          'pass_system_line_still_queued',
        ]) {
          expect(probes, contains(s), reason: s);
        }
        final k7 = probes.substring(probes.indexOf('-- K7 NOT RUN'));
        expect(k7, contains('MISSING'));
        expect(k7, contains('refuses Vault access'));
        expect(
          k7.split('\n').every((l) => l.trim().isEmpty || l.startsWith('--')),
          isTrue,
          reason: 'K7 has no executable SQL',
        );
      },
    );

    test('no probe selects a payload, a secret or a signature', () {
      expect(probes, isNot(contains('vault.decrypted_secrets')));
      expect(probes, isNot(contains('X-Msg-Signature')));
      expect(
        RegExp(r'select\s+payload\b', caseSensitive: false).hasMatch(probes),
        isFalse,
      );
      expect(RegExp(r'sha256=[0-9a-f]{16,}').hasMatch(probes), isFalse);
    });

    test(
      'rollback restores the KAN-539 body inside BEGIN..COMMIT, no DROP',
      () {
        expect(rollback, contains('BEGIN;'));
        expect(rollback, contains('COMMIT;'));
        expect(rollback, contains('MANUAL LAST RESORT'));
        expect(_fn(rollback), _fn(File(_kan539).readAsStringSync()));
        expect(rollback, isNot(contains('realtime.send')));
        expect(rollback, isNot(matches(RegExp(r'drop', caseSensitive: false))));
      },
    );
  });
}
