import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-427 WP1 meetups hardening migration and its probe
/// pack. The migration is authored but not applied; these tests pin its shape.
const _migrationPath =
    'supabase/migrations/20260915120000_meetups_hardening.sql';
const _probesPath = 'supabase/tests/kan427/meetups_hardening_probes.sql';

/// The write functions that must be closed to anon/PUBLIC.
const _writeFunctions = <String>[
  'rpc_create_meetup',
  'rpc_meetup_rsvp',
  'rpc_meetup_cancel',
  'rpc_meetup_set_attendee',
  'rpc_meetup_invite_user',
  'rpc_meetup_mint_link',
  'rpc_meetup_update',
  'rpc_meetup_decide_request',
  'rpc_meetup_remove_attendee',
  'rpc_draft_publish_meetup',
  'rpc_booking_hold_for_meetup',
];

String _stripComments(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

/// Body of `CREATE [OR REPLACE] FUNCTION public.<name>(` up to its closing `$function$;`.
String _functionBlock(String sql, String name) {
  final start = RegExp(
    r'CREATE OR REPLACE FUNCTION public\.' + name + r'\(',
  ).firstMatch(sql);
  expect(start, isNotNull, reason: '$name must be (re)defined');
  final end = sql.indexOf(r'$function$;', start!.start);
  expect(end, greaterThan(start.start));
  return sql.substring(start.start, end + 11);
}

void main() {
  late String raw;
  late String sql; // comments stripped

  setUpAll(() {
    final f = File(_migrationPath);
    expect(f.existsSync(), isTrue, reason: '$_migrationPath must exist');
    raw = f.readAsStringSync();
    sql = _stripComments(raw);
  });

  test('migration filename sorts after the newest existing migration', () {
    final names =
        Directory('supabase/migrations')
            .listSync()
            .map((e) => e.uri.pathSegments.last)
            .where((n) => RegExp(r'^\d{14}_').hasMatch(n))
            .toList()
          ..sort();
    // KAN-429 appends 20260915130000_meetups_card_fields.sql, KAN-431 appends
    // 20260915150000_meetups_notifications.sql after it, KAN-436 appends
    // 20260915150100_kan436_push_payload_meetup_id.sql.
    expect(names, contains('20260915150100_kan436_push_payload_meetup_id.sql'));
    // Later migrations (e.g. 20261008100000_venues_listing_match.sql,
    // 20261008120000_games_listing_match1_card_fields.sql) sort after.
    expect(
      names.last.compareTo('20260915150100_kan436_push_payload_meetup_id.sql'),
      greaterThanOrEqualTo(0),
    );
    expect(names, contains('20260915120000_meetups_hardening.sql'));
  });

  test('exactly one BEGIN; and one COMMIT; and no ROLLBACK', () {
    expect(RegExp(r'^BEGIN;', multiLine: true).allMatches(sql).length, 1);
    expect(RegExp(r'^COMMIT;', multiLine: true).allMatches(sql).length, 1);
    expect(RegExp(r'^ROLLBACK;', multiLine: true).hasMatch(sql), isFalse);
  });

  test('every write function is REVOKEd from PUBLIC and anon', () {
    for (final fn in _writeFunctions) {
      expect(
        RegExp(
          r'REVOKE ALL ON FUNCTION public\.' +
              fn +
              r'\([^)]*\) FROM PUBLIC, anon;',
        ).hasMatch(sql),
        isTrue,
        reason: 'missing REVOKE ... FROM PUBLIC, anon for $fn',
      );
      expect(
        RegExp(
          r'GRANT EXECUTE ON FUNCTION public\.' +
              fn +
              r'\([^)]*\) TO authenticated, service_role;',
        ).hasMatch(sql),
        isTrue,
        reason: 'missing GRANT to authenticated for $fn',
      );
      expect(
        RegExp(
          r'GRANT [A-Z, ]+ ON FUNCTION public\.' +
              fn +
              r'\([^)]*\) TO [^;]*anon',
        ).hasMatch(sql),
        isFalse,
        reason: '$fn must not be granted to anon',
      );
    }
  });

  test('rsvp_self_write policy is dropped', () {
    expect(
      sql,
      contains('DROP POLICY IF EXISTS rsvp_self_write ON public.meetup_rsvps;'),
    );
    expect(sql, isNot(contains('CREATE POLICY rsvp_self_write')));
  });

  test('v_meetup_list is rebuilt without creator_user_id', () {
    expect(sql, contains('DROP VIEW IF EXISTS public.v_meetup_list;'));
    final m = RegExp(
      r'CREATE VIEW public\.v_meetup_list AS(.*?)ORDER BY',
      dotAll: true,
    ).firstMatch(sql);
    expect(m, isNotNull);
    final select = m!.group(1)!.split('WHERE').first;
    // creator_user_id may only appear inside the WHERE gate, never the select list.
    expect(select, isNot(contains('creator_user_id')));
    expect(select, contains('creator_profile_id'));
    expect(select, contains('going_count'));
    expect(select, contains('my_rsvp_status'));
    // the allowlisted anon surface keeps its read grant
    expect(sql, contains('ON TABLE public.v_meetup_list TO anon;'));
    // not turned into a security_invoker view (would return no rows to anon)
    expect(
      RegExp(
        r'v_meetup_list[^;]*security_invoker\s*=\s*(on|true)',
      ).hasMatch(sql),
      isFalse,
    );
  });

  test('rpc_meetup_update exists with the agreed parameter names', () {
    final b = _functionBlock(sql, 'rpc_meetup_update');
    for (final p in [
      'p_meetup_id uuid',
      'p_title text',
      'p_description text',
      'p_start_at timestamp with time zone',
      'p_end_at timestamp with time zone',
      'p_location_name text',
      'p_capacity integer',
    ]) {
      expect(b, contains(p));
    }
    expect(b, contains('creator_user_id <> me'));
    expect(b, contains("'meetup_cancelled'"));
    expect(b, contains("'capacity_below_going_count'"));
    expect(b, contains("emit_event('meetup.updated'"));
  });

  test('rpc_meetup_decide_request exists and is host-only on meetup_rsvps', () {
    final b = _functionBlock(sql, 'rpc_meetup_decide_request');
    expect(b, contains('p_meetup_id uuid, p_user_id uuid, p_decision text'));
    expect(b, contains("'approve'"));
    expect(b, contains("'decline'"));
    expect(b, contains('public.meetup_rsvps'));
    expect(b, contains("'pending'"));
    expect(b, contains("'interested'"));
    expect(b, contains("'cancelled'"));
    expect(b, contains('not_host'));
    expect(b, contains("emit_event('meetup.request_approved'"));
    expect(b, contains("emit_event('meetup.request_declined'"));
    expect(b, isNot(contains("'requested'")));
  });

  test('rpc_meetup_cancel uses creator_user_id and not owner_user_id', () {
    final b = _functionBlock(sql, 'rpc_meetup_cancel');
    expect(b, contains('m.creator_user_id = auth.uid()'));
    expect(b, contains('public.is_admin(auth.uid())'));
    expect(b, isNot(contains('owner_user_id')));
  });

  test('no replaced function references the nonexistent owner_user_id', () {
    for (final fn in [
      'rpc_create_meetup',
      'rpc_meetup_cancel',
      'rpc_meetup_attendees',
      'rpc_meetup_card',
      'rpc_meetup_update',
      'rpc_meetup_decide_request',
      'rpc_meetup_remove_attendee',
      'meetup_counts',
      'meetup_my_status',
    ]) {
      expect(
        _functionBlock(sql, fn),
        isNot(contains('owner_user_id')),
        reason: fn,
      );
    }
  });

  test('rpc_create_meetup carries the v1 guards as RPC checks', () {
    final b = _functionBlock(sql, 'rpc_create_meetup');
    expect(b, contains('public.can_create_meetup(pid)'));
    expect(b, contains("'visibility_not_supported'"));
    expect(b, contains("'free_meetups_only'"));
    expect(b, contains("p_meta->>'joining_rule'"));
    expect(b, contains("p_meta->>'cost_cover'"));
    // guards are not CHECK constraints
    expect(sql, isNot(contains('ADD CONSTRAINT')));
    expect(sql, isNot(contains('ADD CHECK')));
  });

  test(
    'attendees, card and counts read meetup_rsvps, not the legacy table',
    () {
      for (final fn in [
        'rpc_meetup_attendees',
        'rpc_meetup_card',
        'meetup_counts',
        'meetup_my_status',
      ]) {
        final b = _functionBlock(sql, fn);
        expect(b, contains('public.meetup_rsvps'), reason: fn);
        expect(b, isNot(contains('public.meetup_attendees')), reason: fn);
      }
      final counts = RegExp(
        r'CREATE OR REPLACE VIEW public\.v_meetup_counts AS(.*?);',
        dotAll: true,
      ).firstMatch(sql)!.group(1)!;
      expect(counts, contains('public.meetup_rsvps'));
      expect(counts, isNot(contains('public.meetup_attendees')));
    },
  );

  test('every defined function is SECURITY DEFINER with SET search_path', () {
    final defs = RegExp(
      r'CREATE OR REPLACE FUNCTION public\.(\w+)\(.*?\$function\$;',
      dotAll: true,
    ).allMatches(sql).toList();
    expect(defs.length, greaterThanOrEqualTo(9));
    for (final d in defs) {
      final text = d.group(0)!;
      expect(text, contains('SECURITY DEFINER'), reason: d.group(1));
      expect(text, contains('SET search_path'), reason: d.group(1));
    }
  });

  test(
    'new/changed functions raise P0001 errors and derive identity from auth.uid()',
    () {
      for (final fn in [
        'rpc_meetup_update',
        'rpc_meetup_decide_request',
        'rpc_meetup_remove_attendee',
        'rpc_meetup_cancel',
      ]) {
        final b = _functionBlock(sql, fn);
        expect(b, contains("errcode='P0001'"), reason: fn);
        expect(b, contains('auth.uid()'), reason: fn);
      }
    },
  );

  test('retired duplicates are dropped without CASCADE', () {
    expect(
      sql,
      contains('DROP FUNCTION IF EXISTS public.rpc_meetup_create(text, text,'),
    );
    expect(
      sql,
      contains(
        'DROP FUNCTION IF EXISTS public.rpc_meetup_create(uuid, text, text,',
      ),
    );
    expect(
      sql,
      contains(
        'DROP FUNCTION IF EXISTS public.rpc_meetup_rsvp(uuid, text, text);',
      ),
    );
    expect(
      sql,
      contains('DROP FUNCTION IF EXISTS public.rpc_meetup_unrsvp(uuid, text);'),
    );
    expect(RegExp(r'CASCADE', caseSensitive: false).hasMatch(sql), isFalse);
  });

  test("moderation target type 'meetup' is added", () {
    expect(
      sql,
      contains(
        "ALTER TYPE public.mod_target ADD VALUE IF NOT EXISTS 'meetup';",
      ),
    );
  });

  test('no destructive statements against meetups data', () {
    expect(
      RegExp(r'DELETE\s+FROM', caseSensitive: false).hasMatch(sql),
      isFalse,
    );
    expect(
      RegExp(r'\bTRUNCATE\b', caseSensitive: false).hasMatch(sql),
      isFalse,
    );
    // top-level (non-function) DML on meetups must not exist: every UPDATE on
    // public.meetups sits inside a $function$ body.
    final outside = sql.replaceAll(
      RegExp(r'\$function\$.*?\$function\$', dotAll: true),
      '',
    );
    expect(
      RegExp(
        r'UPDATE\s+public\.meetups|INSERT\s+INTO\s+public\.meetups',
        caseSensitive: false,
      ).hasMatch(outside),
      isFalse,
    );
    expect(
      RegExp(r'DROP\s+TABLE', caseSensitive: false).hasMatch(sql),
      isFalse,
    );
  });

  test(
    'rsvp readers become SECURITY DEFINER once the table grants are gone',
    () {
      for (final sig in <String>[
        'public.can_current_user_rsvp_meetup(uuid, uuid)',
        'public.meetup_slots_left(uuid)',
      ]) {
        expect(
          sql,
          contains('ALTER FUNCTION $sig SECURITY DEFINER;'),
          reason: sig,
        );
        expect(
          sql,
          contains('ALTER FUNCTION $sig SET search_path = public;'),
          reason: sig,
        );
        // ...and the post-condition block checks them (single-quoted signature).
        expect(sql, contains("'$sig'"), reason: sig);
      }
      // meetup_slots_left is a definer function but closed to clients.
      expect(
        sql,
        contains(
          'REVOKE ALL ON FUNCTION public.meetup_slots_left(uuid) '
          'FROM PUBLIC, anon, authenticated;',
        ),
      );
      expect(
        sql,
        contains(
          'GRANT EXECUTE ON FUNCTION public.meetup_slots_left(uuid) '
          'TO service_role;',
        ),
      );
      // anon keeps EXECUTE on the rsvp-eligibility check (it answers 'anon').
      expect(
        sql.contains(
          'REVOKE ALL ON FUNCTION public.can_current_user_rsvp_meetup',
        ),
        isFalse,
      );
    },
  );

  test('post-condition block asserts the closed grants', () {
    expect(sql, contains('POST-CONDITION FAILED'));
    expect(sql, contains("has_function_privilege('anon'"));
  });

  group('probes file', () {
    late String probes;
    setUpAll(() {
      final f = File(_probesPath);
      expect(f.existsSync(), isTrue, reason: '$_probesPath must exist');
      probes = f.readAsStringSync();
    });

    test('mentions every changed object', () {
      for (final name in [
        ..._writeFunctions,
        'rpc_meetup_attendees',
        'rpc_meetup_card',
        'meetup_counts',
        'meetup_my_status',
        'v_meetup_list',
        'v_meetup_counts',
        'creator_user_id',
        'rsvp_self_write',
        'meetup_rsvps',
        'moderation_reports',
        'mod_target',
        'rpc_meetup_create',
        'rpc_meetup_unrsvp',
      ]) {
        expect(probes, contains(name), reason: 'probes must cover $name');
      }
    });

    test('every probe block is marked READ-ONLY or WRITE-IN-TRANSACTION', () {
      expect(probes, contains('[READ-ONLY]'));
      expect(probes, contains('[WRITE-IN-TRANSACTION-ROLLBACK]'));
      // every top-level begin has a rollback (no probe commits)
      final begins = RegExp(
        r'^begin;',
        multiLine: true,
      ).allMatches(probes).length;
      final rollbacks = RegExp(
        r'^rollback;',
        multiLine: true,
      ).allMatches(probes).length;
      expect(begins, rollbacks);
      expect(
        RegExp(
          r'^commit;',
          multiLine: true,
          caseSensitive: false,
        ).hasMatch(probes),
        isFalse,
      );
    });

    test('has the eligibility-after-revoke and remove_attendee probes', () {
      expect(probes, contains("'cta' <> 'already'"));
      expect(probes, contains('B4b FAIL: cta'));
      expect(probes, contains('rpc_meetup_remove_attendee(mid, u1)'));
      expect(probes, contains("'cannot_remove_host'"));
      expect(probes, contains('non-host remove_attendee'));
      expect(probes, contains('meetup_slots_left(uuid)'));
    });

    test('covers each required behavioural scenario', () {
      for (final needle in [
        'free_meetups_only', // paid create rejected
        'visibility_not_supported', // non-public create rejected
        'capacity_below_going_count', // update below going
        'meetup_cancelled', // update on cancelled
        'non-host cancel', // cancel by non-host
        'host cancel', // host cancel works
        "'interested'", // full -> interested
        'decline', // decline -> cancelled
        'non-host decide', // non-host decide fails
        'rpc_meetup_attendees', // attendees list from rsvps
        'proacl', // before/after grant listing
        'pg_policy', // policy listing
        'information_schema.columns', // view column check
        'has_function_privilege', // anon execute
      ]) {
        expect(probes, contains(needle), reason: needle);
      }
    });
  });
}
