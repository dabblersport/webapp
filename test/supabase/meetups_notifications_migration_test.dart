import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static shape checks over the KAN-431 meetups notifications migration. It is
/// authored, not applied: no database is involved.
const _path = 'supabase/migrations/20260915150000_meetups_notifications.sql';
const _card = 'supabase/migrations/20260915130000_meetups_card_fields.sql';
const _probes = 'supabase/tests/kan431/meetups_notifications_probes.sql';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

void main() {
  late String sql;
  late String probes;

  setUpAll(() {
    expect(File(_path).existsSync(), isTrue);
    sql = _strip(File(_path).readAsStringSync());
    probes = File(_probes).readAsStringSync();
  });

  test('sorts after the card-fields migration', () {
    expect(_path.compareTo(_card), greaterThan(0));
  });

  test('one BEGIN and one COMMIT', () {
    expect(RegExp(r'^BEGIN;', multiLine: true).allMatches(sql).length, 1);
    expect(RegExp(r'^COMMIT;', multiLine: true).allMatches(sql).length, 1);
  });

  test('no row is deleted, truncated or updated; nothing is dropped', () {
    expect(
      RegExp(r'\b(DELETE|TRUNCATE|DROP)\b', caseSensitive: false).hasMatch(sql),
      isFalse,
    );
    expect(RegExp(r'^\s*UPDATE\s', multiLine: true).hasMatch(sql), isFalse);
    expect(sql, isNot(contains('DO UPDATE')));
  });

  test('five kinds inserted with EN and Arabic labels, push channel', () {
    for (final k in [
      'meetup.rsvp_received',
      'meetup.request_received',
      'meetup.request_approved',
      'meetup.request_declined',
      'meetup.cancelled',
    ]) {
      expect(sql, contains("'$k'"));
    }
    expect(
      sql,
      contains(
        '(key, label_en, label_ar, default_priority, default_channels, route_template, timing, is_active)',
      ),
    );
    expect(sql, contains('ON CONFLICT (key) DO NOTHING'));
    expect(
      RegExp('\\{inapp,push\\}').allMatches(sql).length,
      greaterThanOrEqualTo(5),
    );
    // each kind row carries Arabic script
    final arabic = RegExp(r"'[؀-ۿ][؀-ۿ ّ]+'");
    expect(arabic.allMatches(sql).length, greaterThanOrEqualTo(5));
    expect(sql, contains('/meetups/{entity_id}'));
  });

  test('both triggers installed on the right tables and events', () {
    expect(
      sql,
      contains('AFTER INSERT OR UPDATE OF status ON public.meetup_rsvps'),
    );
    expect(sql, contains('AFTER UPDATE OF is_cancelled ON public.meetups'));
    expect(sql, contains('trg_meetup_rsvps_notify'));
    expect(sql, contains('trg_meetups_cancel_notify'));
  });

  test('delivery goes through process_notification_event for every kind', () {
    final calls = RegExp(
      r'process_notification_event\(',
    ).allMatches(sql).length;
    expect(calls, greaterThanOrEqualTo(6));
    for (final k in [
      'meetup.request_received',
      'meetup.rsvp_received',
      'meetup.request_approved',
      'meetup.request_declined',
      'meetup.cancelled',
    ]) {
      expect(
        RegExp("process_notification_event\\(\\s*[^;]*'$k'").hasMatch(sql),
        isTrue,
        reason: k,
      );
    }
    // not the no-op shim
    expect(sql, isNot(contains('emit_event(')));
  });

  test('definer, pinned search_path, owned by postgres, revoked', () {
    expect(RegExp('SECURITY DEFINER').allMatches(sql).length, 2);
    expect(
      RegExp(r"SET search_path TO 'public', 'pg_temp'").allMatches(sql).length,
      2,
    );
    expect(
      sql,
      contains(
        'ALTER FUNCTION public.trg_meetup_rsvps_notify() OWNER TO postgres',
      ),
    );
    expect(
      sql,
      contains(
        'ALTER FUNCTION public.trg_meetups_cancel_notify() OWNER TO postgres',
      ),
    );
    expect(
      RegExp(
        r'REVOKE ALL ON FUNCTION public\.trg_\w+\(\) FROM PUBLIC, anon, authenticated',
      ).allMatches(sql).length,
      2,
    );
  });

  test('identity is auth.uid(); the actor is never the recipient', () {
    expect(RegExp(r'auth\.uid\(\)').allMatches(sql).length, 2);
    expect(sql, contains('v_actor <> NEW.user_id'));
    expect(sql, contains('NEW.user_id <> v_host_uid'));
    expect(sql, contains('s.user_id IS DISTINCT FROM v_actor'));
  });

  test('does not restate the KAN-427 functions', () {
    for (final f in [
      'rpc_meetup_rsvp',
      'rpc_meetup_decide_request',
      'rpc_meetup_cancel',
      'rpc_meetup_remove_attendee',
      'rpc_create_meetup',
      'process_notification_event(\n  uuid',
    ]) {
      expect(sql, isNot(contains('CREATE OR REPLACE FUNCTION public.$f')));
    }
  });

  test('post-conditions assert kinds, triggers, definer, acl', () {
    expect(sql, contains('POST-CONDITION FAILED'));
    expect(sql, contains('pg_trigger'));
    expect(sql, contains('has_function_privilege'));
    expect(sql, contains('prosecdef'));
    expect(sql, contains("tgenabled = 'O'"));
  });

  group('probes', () {
    test('marked READ-ONLY and WRITE-IN-TRANSACTION-ROLLBACK', () {
      expect(probes, contains('[READ-ONLY]'));
      expect(probes, contains('[WRITE-IN-TRANSACTION-ROLLBACK]'));
    });

    test('every behavioural block ends in rollback and never commits', () {
      expect(
        RegExp(r'^begin;', multiLine: true).allMatches(probes).length,
        RegExp(r'^rollback;', multiLine: true).allMatches(probes).length,
      );
      expect(
        RegExp(
          r'^commit;',
          multiLine: true,
          caseSensitive: false,
        ).hasMatch(probes),
        isFalse,
      );
    });

    test('cover every change', () {
      for (final needle in [
        'meetup.request_received',
        'meetup.rsvp_received',
        'meetup.request_approved',
        'meetup.request_declined',
        'meetup.cancelled',
        'trg_meetup_rsvps_notify',
        'trg_meetups_cancel_notify',
        'proacl',
        'net.http_request_queue',
        'push_enabled = false',
        'muted_kinds',
        'host-self',
        'self-cancel',
        'actor',
        '-- C3b [WRITE-IN-TRANSACTION-ROLLBACK]',
        '-- C3c [WRITE-IN-TRANSACTION-ROLLBACK]',
        'Your request was approved, but the meet-up is full',
      ]) {
        expect(probes, contains(needle), reason: needle);
      }
    });
  });
}
