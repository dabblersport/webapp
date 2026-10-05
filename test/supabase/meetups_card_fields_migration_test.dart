import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static shape checks over the KAN-429 additive card-fields migration. It is
/// authored, not applied.
const _path = 'supabase/migrations/20260915130000_meetups_card_fields.sql';
const _base = 'supabase/migrations/20260915120000_meetups_hardening.sql';
const _probes = 'supabase/tests/kan427/meetups_card_fields_probes.sql';

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
    expect(File(_path).existsSync(), isTrue);
    raw = File(_path).readAsStringSync();
    sql = _strip(raw);
  });

  test('sorts after the hardening migration and does not edit it', () {
    expect(_path.compareTo(_base), greaterThan(0));
    expect(File(_base).readAsStringSync(), isNot(contains('attendee_avatars')));
  });

  test('one BEGIN and one COMMIT; nothing destructive', () {
    expect(RegExp(r'^BEGIN;', multiLine: true).allMatches(sql).length, 1);
    expect(RegExp(r'^COMMIT;', multiLine: true).allMatches(sql).length, 1);
    expect(
      RegExp(r'\b(DELETE|TRUNCATE|DROP)\b', caseSensitive: false).hasMatch(sql),
      isFalse,
    );
  });

  test('the view is replaced, not dropped; the new column is last', () {
    expect(sql, contains('CREATE OR REPLACE VIEW public.v_meetup_list'));
    expect(sql, isNot(contains('security_invoker')));
    final view = sql.substring(
      sql.indexOf('CREATE OR REPLACE VIEW'),
      sql.indexOf('ORDER BY COALESCE'),
    );
    expect(
      view.lastIndexOf('AS attendee_avatars'),
      greaterThan(view.lastIndexOf('AS my_rsvp_status')),
    );
    // Every column of the hardening view survives, in order.
    final baseSql = _strip(File(_base).readAsStringSync());
    final bv = baseSql.substring(
      baseSql.indexOf('CREATE VIEW public.v_meetup_list'),
      baseSql.indexOf('FROM public.meetups m'),
    );
    final names = RegExp(r'AS (\w+)').allMatches(bv).map((m) => m.group(1)!);
    var at = 0;
    for (final n in names) {
      final i = view.indexOf('AS $n', at);
      expect(i, greaterThanOrEqualTo(at), reason: '$n kept in order');
      at = i;
    }
    expect(view, contains("auth.uid() IS NULL THEN '[]'::jsonb"));
  });

  test('view grants are re-asserted as the hardening migration leaves them', () {
    expect(sql, contains('ALTER VIEW public.v_meetup_list OWNER TO postgres;'));
    expect(
      sql,
      contains(
        'GRANT SELECT, REFERENCES, TRIGGER, MAINTAIN ON TABLE public.v_meetup_list TO anon;',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT SELECT, REFERENCES, TRIGGER, MAINTAIN ON TABLE public.v_meetup_list TO authenticated;',
      ),
    );
    expect(
      sql,
      contains('GRANT ALL ON TABLE public.v_meetup_list TO service_role;'),
    );
  });

  test('rpc_meetup_card keeps its signature, security and search_path', () {
    final i = sql.indexOf('CREATE OR REPLACE FUNCTION public.rpc_meetup_card(');
    final fn = sql.substring(i, sql.indexOf(r'$function$;', i));
    expect(fn, contains('p_meetup_id uuid, p_profile_type text DEFAULT'));
    expect(fn, contains('RETURNS jsonb'));
    expect(fn, contains('SECURITY DEFINER'));
    expect(fn, contains("SET search_path TO 'public'"));
    for (final k in <String>[
      "'sport_key'",
      "'sport_name_en'",
      "'sport_name_ar'",
      "'min_skill'",
      "'max_skill'",
      "'area_name'",
      "'venue_name'",
      "'attendees'",
      "'avatar_url',       hp_avatar",
      "'counts',    counts_",
    ]) {
      expect(fn, contains(k), reason: k);
    }
    expect(fn, contains('if me is not null then'));
    expect(fn, contains('limit 8'));
  });

  test('card grants are re-asserted', () {
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.rpc_meetup_card(uuid, text) FROM PUBLIC;',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.rpc_meetup_card(uuid, text) TO anon, authenticated, service_role;',
      ),
    );
  });

  test('probe pack exists and marks every block', () {
    final p = File(_probes).readAsStringSync();
    final blocks = RegExp(
      r'^-- [A-Z]\d+ \[(READ-ONLY|WRITE-IN-TRANSACTION-ROLLBACK)\]',
      multiLine: true,
    ).allMatches(p).length;
    expect(blocks, greaterThanOrEqualTo(4));
  });
}
