import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-585 migration and its pack. AUTHORED, NOT APPLIED.
const _path =
    'supabase/migrations/20261022100000_kan585_feature_availability.sql';
const _pack = 'supabase/tests/feature_availability';

const _ids = [
  'meetups',
  'favourites',
  'game_browsing',
  'player_game_creation',
  'organiser_game_creation',
  'player_game_joining',
  'organiser_game_joining',
  'social_feed',
  'messaging',
  'messaging_game_chat',
  'messaging_direct',
  'messaging_reporting',
  'messaging_realtime',
  'notifications',
  'multi_sport',
  'organiser_profile',
  'venues_booking',
  'booking_flow',
];
const _excluded = [
  'early_bird_check_in',
  'data_export',
  'payments',
  'community_mobile_nav',
];
const _regions = [
  'Egypt',
  'Morocco',
  'Qatar',
  'Saudi Arabia',
  'United Arab Emirates',
  'Global',
];

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  late String raw;
  late String sql;
  late String flat;
  late String doc;

  setUpAll(() {
    raw = File(_path).readAsStringSync();
    sql = _strip(raw);
    flat = _flat(sql);
    doc = File('$_pack/FEATURE_AVAILABILITY.md').readAsStringSync();
  });

  test('header says AUTHORED, NOT APPLIED', () {
    expect(raw, contains('AUTHORED, NOT APPLIED'));
  });

  test('table, PK and both CHECKs', () {
    expect(flat, contains('CREATE TABLE IF NOT EXISTS public.feature_availability'));
    expect(flat, contains('enabled boolean NOT NULL DEFAULT true'));
    expect(flat, contains('updated_at timestamptz NOT NULL DEFAULT now()'));
    expect(flat, contains('PRIMARY KEY (feature_id, region)'));
    expect(flat, contains(r"CHECK (feature_id ~ '^[a-z][a-z0-9_]{1,63}$')"));
    expect(
      flat,
      contains("CHECK (region IN ('Egypt', 'Morocco', 'Qatar', 'Saudi Arabia', "
          "'United Arab Emirates', 'Global'))"),
    );
  });

  test('RLS enabled, only a SELECT policy for authenticated', () {
    expect(flat,
        contains('ALTER TABLE public.feature_availability ENABLE ROW LEVEL SECURITY'));
    final policies = RegExp(r'CREATE POLICY \w+ ON public\.feature_availability FOR (\w+) TO (\w+)')
        .allMatches(flat)
        .map((m) => '${m.group(1)} ${m.group(2)}')
        .toList();
    expect(policies, ['SELECT authenticated']);
  });

  test('grants: no write to authenticated, anon revoked', () {
    expect(flat, contains('REVOKE ALL ON public.feature_availability FROM PUBLIC, anon;'));
    expect(flat, contains('GRANT SELECT ON public.feature_availability TO authenticated;'));
    expect(flat,
        contains('REVOKE INSERT, UPDATE, DELETE ON public.feature_availability FROM authenticated;'));
    expect(flat, contains('GRANT ALL ON public.feature_availability TO service_role;'));
    final authGrants = RegExp(r'GRANT ([A-Z, ]+) ON public\.feature_availability TO authenticated')
        .allMatches(flat)
        .map((m) => m.group(1)!.trim())
        .toList();
    expect(authGrants, ['SELECT']);
    expect(flat, isNot(matches(RegExp(r'GRANT [^;]* TO [^;]*anon'))));
  });

  test('RPC: SECURITY DEFINER, pinned search_path, EXECUTE revoked, Global fallback', () {
    expect(flat, contains('CREATE OR REPLACE FUNCTION public.get_feature_availability()'));
    expect(flat, contains('RETURNS TABLE (feature_id text, enabled boolean)'));
    expect(flat, contains('SECURITY DEFINER'));
    expect(flat, contains('SET search_path = pg_catalog, public'));
    expect(flat, contains('auth.uid()'));
    expect(flat, contains('public.account_service_region'));
    expect(flat, matches(RegExp(r"COALESCE\(.*'Global'\)")));
    expect(flat,
        contains('REVOKE EXECUTE ON FUNCTION public.get_feature_availability() FROM PUBLIC, anon;'));
    expect(flat,
        contains('GRANT EXECUTE ON FUNCTION public.get_feature_availability() TO authenticated;'));
  });

  test('no DROP in the migration', () {
    expect(sql.toUpperCase(), isNot(contains('DROP')));
  });

  test('seed is exactly 18 ids x 6 regions, all true, ON CONFLICT DO NOTHING', () {
    expect(flat, contains('ON CONFLICT (feature_id, region) DO NOTHING'));
    final rows = RegExp(r"\('([a-z0-9_]+)', '([A-Za-z ]+)', (true|false)\)")
        .allMatches(sql)
        .map((m) => (m.group(1)!, m.group(2)!, m.group(3)!))
        .toList();
    expect(rows.length, 108);
    expect(rows.every((r) => r.$3 == 'true'), isTrue);
    expect(rows.map((r) => r.$1).toSet(), _ids.toSet());
    for (final id in _ids) {
      expect(rows.where((r) => r.$1 == id).map((r) => r.$2).toSet(),
          _regions.toSet(), reason: id);
    }
  });

  test('excluded ids are not seeded', () {
    for (final id in _excluded) {
      expect(sql, isNot(contains("'$id'")), reason: id);
      expect(doc, contains('`$id`'), reason: 'doc lists $id as excluded');
    }
  });

  test('every seeded id is in the doc inventory', () {
    for (final id in _ids) {
      expect(doc, contains('| `$id` | yes'), reason: id);
    }
  });

  test('probes and rollback exist in the pack', () {
    final probes = File('$_pack/probes.sql').readAsStringSync();
    expect(probes, contains('AUTHORED, NOT RUN.'));
    expect(File('$_pack/rollback.sql').readAsStringSync(),
        contains('DROP TABLE IF EXISTS public.feature_availability'));
  });
}
