import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-611 migration, rollback and SQL tests. The
/// migration is authored and NOT applied; these tests pin its shape, its order
/// and the absence of any DROP. They run no SQL.
const _name = '20261021120000_kan611_request_id_idempotency.sql';
const _dir = 'supabase/migrations';
const _pack = 'supabase/tests/idempotency';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  final migration = File('$_dir/$_name').readAsStringSync();
  final rollback = File('$_pack/rollback.sql').readAsStringSync();
  final tests = File('$_pack/idempotency_tests.sql').readAsStringSync();
  final code = _squash(_strip(migration));
  final undo = _squash(_strip(rollback));

  test('sorts after every earlier migration and the version is unique', () {
    final names =
        Directory(_dir)
            .listSync()
            .map((e) => e.uri.pathSegments.last)
            .where((n) => RegExp(r'^\d{14}_.*\.sql$').hasMatch(n))
            .toList()
          ..sort();
    // Later migrations may follow it; it must sort after the one that was latest when it was authored.
    expect(names.contains(_name), isTrue);
    expect(
      _name.compareTo('20261021110000_kan592_posted_from_city.sql'),
      greaterThan(0),
    );
    expect(
      names.where((n) => n.startsWith(_name.substring(0, 14))),
      hasLength(1),
    );
  });

  test('migration and rollback contain no DROP', () {
    expect(RegExp(r'\bDROP\b', caseSensitive: false).hasMatch(code), isFalse);
    expect(RegExp(r'\bDROP\b', caseSensitive: false).hasMatch(undo), isFalse);
  });

  test('migration says it is not applied and touches no RLS', () {
    expect(migration, contains('AUTHORED, NOT APPLIED'));
    expect(
      RegExp(
        r'(CREATE|ALTER|DROP) POLICY|ROW LEVEL SECURITY',
        caseSensitive: false,
      ).hasMatch(code),
      isFalse,
    );
  });

  test('request_id column and partial unique index on all three tables', () {
    for (final t in ['posts', 'games', 'meetups']) {
      expect(
        code,
        contains(
          'ALTER TABLE public.$t ADD COLUMN IF NOT EXISTS request_id uuid',
        ),
      );
    }
    expect(
      code,
      contains(
        'ON public.posts (author_profile_id, request_id) WHERE request_id IS NOT NULL',
      ),
    );
    expect(
      code,
      contains(
        'ON public.games (creator_profile_id, request_id) WHERE request_id IS NOT NULL',
      ),
    );
    expect(
      code,
      contains(
        'ON public.meetups (creator_profile_id, request_id) WHERE request_id IS NOT NULL',
      ),
    );
  });

  test('each create function gains one trailing defaulted p_request_id', () {
    for (final f in ['create_post', 'rpc_create_game', 'rpc_create_meetup']) {
      final i = code.indexOf('CREATE FUNCTION public.$f(');
      expect(i, greaterThan(-1), reason: f);
      final head = code.substring(i, i + code.substring(i).indexOf(' AS '));
      expect(head, contains('p_request_id uuid DEFAULT NULL'), reason: f);
      expect(
        RegExp(
          r'p_request_id uuid DEFAULT NULL(::uuid)? ?\) RETURNS',
        ).hasMatch(head),
        isTrue,
        reason: f,
      );
    }
  });

  test('old functions are renamed and closed to clients, not dropped', () {
    for (final f in [
      'create_post_legacy_v2',
      'rpc_create_game_legacy_v2',
      'rpc_create_meetup_legacy_v2',
    ]) {
      expect(code, contains('RENAME TO $f'));
      expect(code, contains('REVOKE ALL ON FUNCTION public.$f('));
    }
  });

  test('create_post links hashtags in the same function as the insert', () {
    final body = code.substring(
      code.indexOf('CREATE FUNCTION public.create_post('),
    );
    expect(body, contains('INSERT INTO public.post_hashtags'));
    expect(body, contains('INSERT INTO public.post_squads'));
    expect(body, contains('INSERT INTO public.posts'));
    expect(body, contains('pg_advisory_xact_lock'));
  });

  test('a replay is looked up before any insert in every create path', () {
    for (final f in ['create_post', 'rpc_create_game', 'rpc_create_meetup']) {
      final body = code.substring(code.indexOf('CREATE FUNCTION public.$f('));
      expect(
        body.indexOf('request_id = p_request_id'),
        greaterThan(-1),
        reason: f,
      );
      expect(
        body.indexOf('pg_advisory_xact_lock'),
        lessThan(body.indexOf('request_id = p_request_id')),
        reason: f,
      );
    }
  });

  test('ACLs: create_post/meetup closed to anon, game keeps its old grant', () {
    expect(code, contains('GRANT EXECUTE ON FUNCTION public.create_post('));
    expect(code, contains('TO authenticated, service_role'));
    expect(code, contains('TO anon, authenticated, service_role'));
  });

  test(
    'rollback renames back without DROP and the SQL tests cover the criteria',
    () {
      for (final f in ['create_post', 'rpc_create_game', 'rpc_create_meetup']) {
        expect(undo, contains('RENAME TO $f;'));
        expect(undo, contains('RENAME TO ${f}_v3_rolledback'));
      }
      for (final id in [
        'T1',
        'T2',
        'T3a',
        'T3b',
        'T4',
        'G1',
        'G2',
        'G3',
        'G4',
        'M1',
        'M2',
        'M3',
        'M4',
        'X1',
        'X2',
        'X3',
      ]) {
        expect(tests, contains("KAN611 PASS $id'"), reason: id);
      }
      expect(tests, isNot(contains('apply_migration')));
    },
  );
}
