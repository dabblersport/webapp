import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-510 (Messaging T15) migration, probe pack and Worker. The migration
/// and probes are authored and NOT applied/run; these tests pin their shape. They run no SQL.
const _migration = 'supabase/migrations/20261013160000_kan510_msg_system_lines.sql';
const _probes = 'supabase/tests/messaging/system_lines_probes.sql';
const _worker = 'workers/messaging/src/system_line.ts';
const _workerTest = 'workers/messaging/test/system_line.test.ts';

String _stripComments(String sql) => sql
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

  setUpAll(() {
    raw = File(_migration).readAsStringSync();
    sql = _squash(_stripComments(raw));
  });

  group('triggers (AC1)', () {
    test('three triggers, exactly the four events', () {
      expect(RegExp(r'CREATE TRIGGER (\w+)').allMatches(sql).map((m) => m.group(1)).toList(),
          ['msg_system_roster_insert', 'msg_system_roster_status', 'msg_system_game_cancelled']);
      expect(sql, contains("AFTER INSERT ON public.game_roster FOR EACH ROW WHEN (NEW.status = 'active')"));
      expect(sql, contains("AFTER UPDATE OF status ON public.game_roster"));
      expect(sql, contains("OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('active', 'left', 'kicked')"));
      expect(sql, contains('AFTER UPDATE OF is_cancelled ON public.games'));
      expect(sql, contains('OLD.is_cancelled IS NOT TRUE AND NEW.is_cancelled IS TRUE'));
      for (final e in ['joined', 'left', 'removed', 'cancelled']) {
        expect(sql, contains("'$e'"));
      }
    });

    test('only these tables are triggered and none is edited', () {
      final on = RegExp(r'(?:INSERT|UPDATE(?: OF \w+)?) ON (public\.\w+)')
          .allMatches(sql)
          .map((m) => m.group(1))
          .toSet();
      expect(on, {'public.game_roster', 'public.games'});
      expect(RegExp(r'\bALTER TABLE\b|\bCREATE TABLE\b|\bDROP\b', caseSensitive: false).hasMatch(sql), isFalse);
      expect(sql, isNot(contains('CREATE OR REPLACE TRIGGER')));
    });
  });

  group('no timer (AC4, C3)', () {
    test('no cron, no end_at, no scheduled job', () {
      expect(RegExp('cron|end_at', caseSensitive: false).hasMatch(raw), isFalse);
      expect(RegExp(r'pg_sleep|schedule|interval', caseSensitive: false).hasMatch(sql), isFalse);
    });

    test('the file says game finished is rendered by the client from the end time', () {
      expect(raw, contains('game finished'));
      expect(raw, contains('client renders'));
      expect(raw, contains('NO "game finished" line'));
    });
  });

  group('secrets (AC5)', () {
    test('settings and binding are named, never valued', () {
      expect(raw, contains('app.msg_worker_url'));
      expect(raw, contains('app.msg_hmac_secret'));
      expect(raw, contains('MSG_SYSTEM_HMAC_SECRET'));
      expect(RegExp(r"set_config\s*\(|ALTER (DATABASE|ROLE)[^;]*SET app\.", caseSensitive: false).hasMatch(sql), isFalse);
      expect(RegExp(r'https?://').hasMatch(sql), isFalse);
      expect(RegExp(r'eyJ[A-Za-z0-9_-]{10,}|sk_[a-z]+_|[0-9a-f]{40,}').hasMatch(raw), isFalse);
    });

    test('the request is signed with HMAC-SHA256 from the setting', () {
      expect(sql, contains("'sha256'"));
      expect(sql, contains("current_setting('app.msg_hmac_secret', true)"));
      expect(sql, contains("'X-Msg-Signature'"));
    });
  });

  group('safety', () {
    test('functions are internal: definer, empty search_path, no public execute', () {
      expect(RegExp(r'SECURITY DEFINER SET search_path = \x27\x27').allMatches(sql).length, 3);
      for (final f in ['msg_system_notify(text, uuid, uuid)', 'msg_system_roster_trg()', 'msg_system_game_trg()']) {
        expect(sql, contains('REVOKE ALL ON FUNCTION public.$f FROM PUBLIC, anon, authenticated'));
      }
    });

    test('a failure never blocks the roster change and leaks no payload', () {
      expect(sql, contains('EXCEPTION WHEN OTHERS THEN RAISE WARNING'));
      expect(sql, contains('RETURN NULL'));
    });

    test('carries no name or text, only ids and the event kind', () {
      expect(sql, contains("'event_id'"));
      expect(sql, contains("'conversation_id'"));
      expect(RegExp(r"'(name|username|display_name|body|text|email)'").hasMatch(sql), isFalse);
    });
  });

  group('probes and Worker tests (C4)', () {
    test('probe pack is marked AUTHORED, NOT RUN and rolls back every block', () {
      final p = File(_probes).readAsStringSync();
      expect(p, contains('AUTHORED, NOT RUN'));
      expect('begin;'.allMatches(p).length, '\nrollback;'.allMatches(p).length);
      expect(RegExp(r'\bdrop\b', caseSensitive: false).hasMatch(p), isFalse);
      expect(RegExp(r'eyJ[A-Za-z0-9_-]{10,}|[0-9a-f]{40,}').hasMatch(p), isFalse);
    });

    test('the Worker verifies HMAC before any write and stores one line per event_id', () {
      final w = File(_worker).readAsStringSync();
      expect(w, contains('MSG_SYSTEM_HMAC_SECRET'));
      expect(w.indexOf('verifySignature(secret'), lessThan(w.indexOf('insertMessage(')));
      expect(w, contains('clientKey: event_id'));
    });

    test('Worker tests cover valid, missing, bad, tampered and repeated', () {
      final t = File(_workerTest).readAsStringSync();
      for (final name in [
        'a valid signature stores one system line',
        'a missing signature stores none',
        'a bad signature (wrong key) stores none',
        'a tampered body stores none',
        'the same event delivered twice stores one line',
      ]) {
        expect(t, contains(name));
      }
    });
  });
}
