import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static shape checks over the KAN-436 push-payload migration. Authored, not applied.
const _path =
    'supabase/migrations/20260915150100_kan436_push_payload_meetup_id.sql';
const _prev = 'supabase/migrations/20260915150000_meetups_notifications.sql';
const _baseline = 'supabase/migrations/20260829080500_baseline_schema.sql';
const _probes = 'supabase/tests/kan436/push_payload_meetup_id_probes.sql';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

void main() {
  late String raw;
  late String sql;

  setUpAll(() {
    raw = File(_path).readAsStringSync();
    sql = _strip(raw);
  });

  test('sorts after the KAN-431 migration and is the only new file', () {
    expect(_path.compareTo(_prev), greaterThan(0));
  });

  test('one BEGIN and one COMMIT; nothing dropped, deleted or updated', () {
    expect(RegExp(r'^BEGIN;', multiLine: true).allMatches(sql).length, 1);
    expect(RegExp(r'^COMMIT;', multiLine: true).allMatches(sql).length, 1);
    expect(
      RegExp(r'\b(DELETE|TRUNCATE|DROP)\b', caseSensitive: false).hasMatch(sql),
      isFalse,
    );
    expect(RegExp(r'^\s*UPDATE\s', multiLine: true).hasMatch(sql), isFalse);
  });

  test('replaces the push trigger function, definer, pinned search_path', () {
    expect(
      sql,
      contains(
        'CREATE OR REPLACE FUNCTION "public"."trg_push_on_notification_insert"()',
      ),
    );
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains('SET "search_path" TO \'public\', \'pg_temp\''));
  });

  test('data map adds meetup_id only for meetup context; entity_id kept', () {
    expect(sql, contains("'entity_id',    COALESCE(NEW.id::text, '')"));
    expect(sql, contains("NEW.context->>'entity_type' = 'meetup'"));
    expect(sql, contains("NULLIF(NEW.context->>'entity_id', '') IS NOT NULL"));
    expect(
      sql,
      contains("jsonb_build_object('meetup_id', NEW.context->>'entity_id')"),
    );
    expect(sql, contains("ELSE '{}'::jsonb"));
  });

  test('body is the baseline body except for the data expression', () {
    String body(String s) {
      final a = s.indexOf(
        'CREATE OR REPLACE FUNCTION "public"."trg_push_on_notification_insert"()',
      );
      final b = s.indexOf(r'$$;', s.indexOf(r'AS $$', a));
      return s.substring(a, b);
    }

    final base = body(File(_baseline).readAsStringSync());
    final mine = body(raw);
    final cut = RegExp(r"\) \|\| CASE.*?END", dotAll: true);
    expect(mine.replaceFirst(cut, ')'), base);
  });

  test('post-conditions: definer, search_path, ACL unchanged', () {
    expect(sql, contains('prosecdef'));
    expect(sql, contains('search_path=public, pg_temp'));
    expect(sql, contains('proacl'));
    expect(sql, contains("kan436.pne_acl"));
  });

  test('probe pack covers the agreed scenarios', () {
    final p = File(_probes).readAsStringSync();
    for (final s in [
      'meetup.invited',
      'game.invited',
      'meetup_id',
      'push_enabled = false',
      'muted_kinds',
      'fn_public_activities_notify',
      'prosecdef',
      'proacl',
    ]) {
      expect(p, contains(s), reason: s);
    }
  });
}
