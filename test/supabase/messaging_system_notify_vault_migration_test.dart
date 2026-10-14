import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-539 migration (msg_system_notify reads its secret from Vault), its
/// probe pack and rollback. Authored and NOT applied/run; these tests run no SQL and do not
/// assert that the migration is the newest one.
const _name = '20261013160500_kan539_msg_system_notify_vault.sql';
const _migration = 'supabase/migrations/$_name';
const _kan510 =
    'supabase/migrations/20261013160000_kan510_msg_system_lines.sql';
const _probes = 'supabase/tests/messaging/system_notify_vault_probes.sql';
const _rollback = 'supabase/tests/messaging/system_notify_vault_rollback.sql';
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

void main() {
  late String raw;
  late String sql;
  late String probes;
  late String rollback;

  setUpAll(() {
    raw = File(_migration).readAsStringSync();
    sql = _squash(_strip(raw));
    probes = File(_probes).readAsStringSync();
    rollback = File(_rollback).readAsStringSync();
  });

  group('migration', () {
    test('sorts after 20261013160400 and after the KAN-510 migration', () {
      expect(_name.compareTo('20261013160400'), greaterThan(0));
      expect(
        _name.compareTo('20261013160000_kan510_msg_system_lines.sql'),
        greaterThan(0),
      );
    });

    test(
      'redefines only msg_system_notify, with no DROP and no other statement',
      () {
        expect(
          RegExp(
            r'CREATE OR REPLACE FUNCTION (public\.\w+)',
          ).allMatches(sql).map((m) => m.group(1)).toList(),
          ['public.msg_system_notify'],
        );
        expect(sql, isNot(matches(RegExp(r'\bDROP\b', caseSensitive: false))));
        expect(
          raw,
          isNot(matches(RegExp(r'drop', caseSensitive: false))),
          reason: 'no DROP, comments included',
        );
        expect(sql, isNot(contains('CREATE TRIGGER')));
        expect(sql, isNot(contains('ALTER ')));
        expect(sql, isNot(contains('GRANT EXECUTE')));
      },
    );

    test('keeps the signature, SECURITY DEFINER and the empty search_path', () {
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
    });

    test('reads the secret only from Vault, by name', () {
      expect(sql, contains('FROM vault.decrypted_secrets s'));
      expect(sql, contains("WHERE s.name = 'msg_hmac_secret'"));
      expect(
        RegExp('decrypted_secret').allMatches(sql).length,
        greaterThanOrEqualTo(1),
      );
      expect(sql, isNot(contains('current_setting')));
      expect(sql, isNot(contains('app.msg_')));
      // Every other name is schema qualified (the search_path is empty).
      expect(sql, contains('extensions.hmac'));
      expect(sql, contains('net.http_post'));
      expect(sql, contains('public.msg_conversations'));
    });

    test('uses the constant staging URL and no other URL', () {
      expect(sql, contains("v_url constant text := '$_url'"));
      expect(
        RegExp(
          r'https?://[^\s\x27]+',
        ).allMatches(sql).map((m) => m.group(0)).toSet(),
        {_url},
      );
    });

    test('does nothing when the secret is missing and fails quietly', () {
      expect(
        sql,
        contains("IF v_secret IS NULL OR v_secret = '' THEN RETURN; END IF;"),
      );
      expect(
        sql,
        contains(
          "EXCEPTION WHEN OTHERS THEN RAISE WARNING 'msg_system_notify failed (sqlstate %)', SQLSTATE;",
        ),
      );
      expect(
        RegExp('RAISE').allMatches(sql).length,
        1,
        reason: 'one payload-free WARNING only',
      );
    });

    test('keeps the grants revoked from PUBLIC, anon and authenticated', () {
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.msg_system_notify(text, uuid, uuid) FROM PUBLIC, anon, authenticated',
        ),
      );
    });

    test('the event body and signature are the KAN-510 ones', () {
      final old = _squash(_strip(File(_kan510).readAsStringSync()));
      for (final piece in [
        "'event_id', gen_random_uuid(), 'conversation_id', v_conv, 'event', p_event, 'user_id', p_user_id",
        "v_sig := encode(extensions.hmac(convert_to(v_body::text, 'utf8'), convert_to(v_secret, 'utf8'), 'sha256'), 'hex');",
        "headers := jsonb_build_object('Content-Type', 'application/json', 'X-Msg-Signature', 'sha256=' || v_sig)",
        'SELECT c.id INTO v_conv FROM public.msg_conversations c WHERE c.game_id = p_game_id;',
      ]) {
        expect(old, contains(piece), reason: 'KAN-510');
        expect(sql, contains(piece));
      }
    });

    test(
      'contains no literal secret or key-like string; says it is not applied',
      () {
        for (final bad in [
          RegExp(r'eyJ[A-Za-z0-9_-]{10,}'),
          RegExp(r'sha256=[0-9a-f]{16,}'),
          RegExp(r'[0-9a-f]{40,}'),
          RegExp(r'postgres(ql)?://'),
        ]) {
          expect(bad.hasMatch(raw), isFalse, reason: bad.pattern);
        }
        expect(raw, contains('AUTHORED, NOT APPLIED'));
      },
    );

    test('the KAN-510 migration file itself is untouched in meaning', () {
      final old = File(_kan510).readAsStringSync();
      expect(old, contains("current_setting('app.msg_hmac_secret', true)"));
    });
  });

  group('probes and rollback', () {
    test('both say AUTHORED, NOT RUN', () {
      expect(probes, contains('AUTHORED, NOT RUN'));
      expect(rollback, contains('AUTHORED, NOT RUN'));
    });

    test(
      'every probe block is READ-ONLY or WRITE-IN-TRANSACTION-ROLLBACK and rolled back',
      () {
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
      },
    );

    test(
      'probes cover the function attributes, the Vault read, a queued signed request and a missing secret',
      () {
        for (final s in [
          'prosecdef',
          "search_path=",
          'vault.decrypted_secrets',
          'msg_hmac_secret',
          'net.http_request_queue',
          "X-Msg-Signature",
          '^sha256=[0-9a-f]{64}\$',
          'pass_missing_secret_no_request',
          'has_function_privilege(\'anon\'',
          'pass_one_raise_only',
        ]) {
          expect(probes, contains(s), reason: s);
        }
      },
    );

    test('no probe selects the secret or prints a signature value', () {
      expect(
        RegExp(
          r'select\s+decrypted_secret',
          caseSensitive: false,
        ).hasMatch(probes),
        isFalse,
      );
      // The signature header is only ever tested inside bool_and(... ~ regex), never selected.
      final uses = RegExp(
        r"headers ->> 'X-Msg-Signature'",
      ).allMatches(probes).toList();
      expect(uses, isNotEmpty);
      for (final m in uses) {
        expect(
          probes.substring(m.start - 9, m.start),
          'bool_and(',
          reason: 'signature only inside bool_and',
        );
        expect(probes.substring(m.end, m.end + 5), " ~ '^");
      }
      expect(probes, isNot(contains(':test_key')));
      expect(RegExp(r'sha256=[0-9a-f]{16,}').hasMatch(probes), isFalse);
    });

    test(
      'rollback restores the KAN-510 body inside BEGIN..COMMIT, with no DROP',
      () {
        expect(rollback, contains('BEGIN;'));
        expect(rollback, contains('COMMIT;'));
        final r = _squash(_strip(rollback));
        final old = _squash(_strip(File(_kan510).readAsStringSync()));
        final start = old.indexOf(
          'CREATE OR REPLACE FUNCTION public.msg_system_notify',
        );
        final end = old.indexOf('\$fn\$;', start) + 5;
        expect(r, contains(old.substring(start, end)));
        expect(rollback, isNot(matches(RegExp(r'drop', caseSensitive: false))));
        expect(probes, isNot(matches(RegExp(r'drop', caseSensitive: false))));
      },
    );
  });
}
