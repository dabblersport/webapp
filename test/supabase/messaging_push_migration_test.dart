import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-572 migration (chat message push through the existing
/// notifications -> trg_push_on_notification_insert path). Runs no SQL.
const _migration = 'supabase/migrations/20261019120000_kan572_msg_push.sql';
const _probes = 'supabase/tests/messaging/push_probes.sql';
const _rollback = 'supabase/tests/messaging/push_rollback.sql';

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
    sql = _squash(_strip(File(_migration).readAsStringSync()));
  });

  test('probe and rollback files exist', () {
    expect(File(_probes).existsSync(), isTrue);
    expect(File(_rollback).existsSync(), isTrue);
  });

  test('no DROP, no DELETE, no TRUNCATE', () {
    expect(
      RegExp(r'\b(drop|delete|truncate)\b', caseSensitive: false).hasMatch(sql),
      isFalse,
    );
  });

  test('definer with pinned search_path, anon and PUBLIC revoked', () {
    expect(sql, contains('SECURITY DEFINER SET search_path = public, pg_temp'));
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.msg_notify(uuid, bigint, text) FROM PUBLIC, anon',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.msg_notify(uuid, bigint, text) TO authenticated',
      ),
    );
  });

  test('adds a push-enabled message.received kind without overwriting', () {
    expect(sql, contains("'message.received'"));
    expect(sql, contains("'{inapp,push}'::public.notify_channel[]"));
    expect(sql, contains('ON CONFLICT (key) DO NOTHING'));
  });

  test('reuses the notifications table; no direct FCM or http call', () {
    expect(sql, contains('INSERT INTO public.notifications'));
    expect(sql.toLowerCase(), isNot(contains('net.http_post')));
    expect(sql.toLowerCase(), isNot(contains('fcm')));
  });

  test('keeps the Realtime wake-up and the KAN-560 recipient rules', () {
    expect(
      sql,
      contains(
        "PERFORM realtime.send(v_payload, 'msg', 'user:' || v_to::text, true)",
      ),
    );
    expect(sql, contains('mm.muted_at IS NOT NULL'));
    expect(sql, contains('dm.muted_at IS NULL'));
    expect(sql, contains('b.blocked_user_id = v_uid'));
    expect(sql, contains("r.status = 'active'"));
  });

  test('excludes the sender and dedupes unread bursts', () {
    expect(sql, contains('IF v_to <> v_uid THEN'));
    expect(sql, contains("n.created_at > now() - interval '2 minutes'"));
    expect(sql, contains('n.is_read = false'));
  });

  test('payload is content-free: fixed title, null body, ids only', () {
    expect(sql, contains("'message.received', 'New message', NULL, v_route"));
    // nothing from the message row or the sender profile is read
    expect(sql, isNot(contains('msg_messages')));
    expect(sql, isNot(contains('display_name')));
    expect(RegExp(r'\b(body|text|content)\s*:=').hasMatch(sql), isFalse);
  });
}
