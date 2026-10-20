import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-595 migration (Active stream read RPC), its probe pack and rollback. Authored and NOT
/// applied/run; these tests run no SQL.
const _dir = 'supabase/migrations';
const _name = '20261020120000_kan595_active_stream.sql';
const _pack = 'supabase/tests/active_stream';
const _sig = 'public.active_stream(text[], text, int, timestamptz, text, uuid)';

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

  setUpAll(() {
    raw = File('$_dir/$_name').readAsStringSync();
    sql = _squash(_strip(raw));
  });

  test('exists, sorts after a fixed cut-off, unique version', () {
    expect(_name.compareTo('20261019120000'), greaterThan(0));
    final same = Directory(_dir)
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((n) => n.startsWith(_name.substring(0, 14)));
    expect(same.length, 1);
  });

  test('one transaction; no DROP, no write, no table/policy/owner change', () {
    expect(RegExp(r'^BEGIN;$', multiLine: true).allMatches(raw).length, 1);
    expect(RegExp(r'^COMMIT;$', multiLine: true).allMatches(raw).length, 1);
    for (final bad in [
      'DROP',
      'INSERT ',
      'UPDATE ',
      'DELETE ',
      'TRUNCATE',
      'ALTER TABLE',
      'CREATE TABLE',
      'POLICY',
      'OWNER TO',
    ]) {
      expect(sql.toUpperCase(), isNot(contains(bad)), reason: bad);
    }
  });

  test('every event type has its source and timestamp', () {
    const types = {
      "'player_joined'::text, p.created_at": 'FROM public.profiles p',
      "'venue_added'::text, v.created_at": 'FROM public.venues v',
      "'game_created'::text, g.created_at": 'FROM public.games g',
      "'game_started'::text, g.start_at": 'g.start_at <= now()',
      "'game_ended'::text, g.end_at": 'g.end_at <= now()',
      "'meetup_created'::text, m.created_at": 'FROM public.meetups m',
      "'meetup_started'::text, m.start_at": 'm.start_at <= now()',
      "'meetup_completed'::text, COALESCE(m.end_at, m.start_at)":
          'COALESCE(m.end_at, m.start_at) <= now()',
    };
    final s = sql
        .replaceAll(' AS event_type', '')
        .replaceAll(' AS event_at', '');
    types.forEach((sel, src) {
      expect(s, contains(sel), reason: sel);
      expect(s, contains(src), reason: src);
    });
    expect(RegExp(r'\bUNION ALL\b').allMatches(sql).length, 7);
  });

  test('security attributes and ACL', () {
    expect(
      sql,
      contains(
        "LANGUAGE sql STABLE SECURITY DEFINER SET search_path = 'public', 'pg_temp'",
      ),
    );
    expect(sql, contains('REVOKE ALL ON FUNCTION $_sig FROM PUBLIC, anon;'));
    expect(sql, contains('GRANT EXECUTE ON FUNCTION $_sig TO authenticated;'));
    expect(RegExp(r'GRANT[^;]*\banon\b').hasMatch(sql), isFalse);
    expect(sql, contains('prm.viewer IS NOT NULL'));
  });

  test('ordering, keyset, limit clamp, dedup', () {
    expect(
      sql,
      contains('ORDER BY f.event_at DESC, f.event_type DESC, f.entity_id DESC'),
    );
    expect(sql, contains('LEAST(GREATEST(COALESCE(p_limit, 30), 1), 50)'));
    expect(sql, contains('ev.event_at < p_before'));
    expect(
      sql,
      contains(
        '(ev.event_type, ev.entity_id) < (p_before_type, p_before_entity)',
      ),
    );
    expect(sql, contains('DISTINCT ON (ev.event_type, ev.entity_id)'));
  });

  test('filters: types subset and selected city, no coordinates', () {
    expect(sql, contains('ev.event_type = ANY (p_event_types)'));
    expect(sql, contains('lower(ev.city) = lower(prm.city)'));
    for (final bad in ['latitude', 'longitude', 'lat', 'lng', 'st_dwithin']) {
      expect(
        RegExp('\\b$bad\\b', caseSensitive: false).hasMatch(sql),
        isFalse,
        reason: bad,
      );
    }
  });

  test('visibility and block exclusion reuse existing predicates', () {
    expect(
      RegExp(r'NOT public\.is_blocked\(prm\.viewer, ').allMatches(sql).length,
      8,
    );
    expect(sql, contains('public._can_view_game(g.id)'));
    expect(
      sql,
      contains(
        'public.can_view_owner(m.creator_user_id, m.listing_visibility)',
      ),
    );
    expect(sql, contains('public.is_profile_publicly_visible(p.id)'));
    expect(sql, contains('v.is_active = true'));
    expect(RegExp(r'is_cancelled = false').allMatches(sql).length, 6);
  });

  test('no views/counters, posts, news or message content', () {
    for (final bad in [
      'view_count',
      'views',
      'like_count',
      'comment_count',
      'posts',
      'news',
      'msg_',
      'body',
    ]) {
      expect(sql.toLowerCase(), isNot(contains(bad)), reason: bad);
    }
  });

  test('probes: AUTHORED NOT RUN, begin/rollback, no commit, coverage', () {
    final p = File('$_pack/probes.sql').readAsStringSync();
    final heads = RegExp(
      r'^-- P\d+ \[(READ-ONLY|WRITE-IN-TRANSACTION-ROLLBACK)\] AUTHORED, NOT RUN\.',
      multiLine: true,
    ).allMatches(p).length;
    expect(heads, greaterThanOrEqualTo(12));
    final begins = RegExp(r'^BEGIN;$', multiLine: true).allMatches(p).length;
    final rbs = RegExp(r'^ROLLBACK;$', multiLine: true).allMatches(p).length;
    expect(begins, rbs);
    expect(p.toUpperCase(), isNot(contains('COMMIT')));
    for (final k in [
      'p1_newest_first',
      'p2_types_present',
      'p3_type_filter',
      'p4_city_only',
      'p4_null_city_superset',
      'p5_no_duplicates',
      'p6_blocker_side',
      'p7_blocked_side',
      'p8_private_excluded',
      'p8_cancelled_excluded',
      'p9_future_types',
      'p10_no_overlap',
      'p11_no_anon',
      'p12_no_viewer_no_rows',
    ]) {
      expect(p, contains(k), reason: k);
    }
  });

  test('rollback drops only this function', () {
    final r = _squash(_strip(File('$_pack/rollback.sql').readAsStringSync()));
    final drops = RegExp(r'\bDROP\b[^;]*;').allMatches(r).map((m) => m[0]);
    expect(drops, ['DROP FUNCTION IF EXISTS $_sig;']);
    expect(
      File('$_pack/README.md').readAsStringSync(),
      contains('Claude Design reference'),
    );
  });
}
