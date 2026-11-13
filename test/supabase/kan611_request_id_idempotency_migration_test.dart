import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the four KAN-611 migrations, the rollback and the SQL
/// probes. The migrations are authored and NOT applied; these tests pin their
/// shape, order, ACL and the absence of any DROP. They run no SQL.
const _dir = 'supabase/migrations';
const _pack = 'supabase/tests/idempotency';
const _cols = '20261021120000_kan611_request_id_columns.sql';
const _post = '20261021120100_kan611_create_post_request_id.sql';
const _game = '20261021120200_kan611_rpc_create_game_request_id.sql';
const _meet = '20261021120300_kan611_rpc_create_meetup_request_id.sql';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String _code(String name) =>
    _squash(_strip(File('$_dir/$name').readAsStringSync()));

int _at(String hay, String needle) {
  final i = hay.indexOf(needle);
  expect(i, greaterThanOrEqualTo(0), reason: 'missing: $needle');
  return i;
}

void main() {
  final cols = _code(_cols);
  final post = _code(_post);
  final game = _code(_game);
  final meet = _code(_meet);
  final undo = _squash(
    _strip(File('$_pack/rollback.sql').readAsStringSync()),
  );
  final probes = File('$_pack/idempotency_tests.sql').readAsStringSync();
  final all = {_cols: cols, _post: post, _game: game, _meet: meet};

  test('four files exist, sort in order, the old single file is gone', () {
    expect(File('$_dir/20261021120000_kan611_request_id_idempotency.sql')
        .existsSync(), isFalse);
    final names = Directory(_dir)
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((n) => n.contains('kan611'))
        .toList()
      ..sort();
    expect(names, [_cols, _post, _game, _meet]);
  });

  test('no DROP statement in any migration or the rollback', () {
    final drop = RegExp(r'\bDROP\b', caseSensitive: false);
    for (final e in all.entries) {
      expect(drop.hasMatch(e.value), isFalse, reason: e.key);
    }
    expect(drop.hasMatch(undo), isFalse);
  });

  test('every file is marked not applied and touches no RLS', () {
    for (final n in all.keys) {
      expect(File('$_dir/$n').readAsStringSync(),
          contains('AUTHORED, NOT APPLIED'));
      expect(
        RegExp(r'(CREATE|ALTER) POLICY|ROW LEVEL SECURITY',
                caseSensitive: false)
            .hasMatch(all[n]!),
        isFalse,
        reason: n,
      );
    }
  });

  test('request_id columns and partial unique indexes on owner user ids', () {
    for (final t in ['posts', 'games', 'meetups']) {
      expect(cols,
          contains('ALTER TABLE public.$t ADD COLUMN IF NOT EXISTS request_id uuid'));
    }
    expect(cols, contains(
        'CREATE UNIQUE INDEX IF NOT EXISTS posts_author_user_request_id_key ON public.posts (author_user_id, request_id) WHERE request_id IS NOT NULL'));
    expect(cols, contains(
        'CREATE UNIQUE INDEX IF NOT EXISTS games_creator_user_request_id_key ON public.games (creator_user_id, request_id) WHERE request_id IS NOT NULL'));
    expect(cols, contains(
        'CREATE UNIQUE INDEX IF NOT EXISTS meetups_creator_user_request_id_key ON public.meetups (creator_user_id, request_id) WHERE request_id IS NOT NULL'));
    expect(cols.contains('_profile_id'), isFalse);
    expect(cols, contains('CREATE OR REPLACE TRIGGER trg_games_stamp_request_id'));
    expect(cols, contains('CREATE OR REPLACE TRIGGER trg_meetups_stamp_request_id'));
  });

  for (final c in [
    (_post, 'create_post'),
    (_game, 'rpc_create_game'),
    (_meet, 'rpc_create_meetup'),
  ]) {
    final file = c.$1;
    final fn = c.$2;
    test('$fn: pre-check, rename, revoke legacy, create, ACL, post-check in order', () {
      final s = all[file]!;
      final pre = _at(s, "p.proname = '$fn') <> 1");
      final preLegacy = _at(s, "p.proname = '${fn}_legacy_v2'");
      final rename = _at(s, 'RENAME TO ${fn}_legacy_v2');
      final revoke = _at(s, 'REVOKE ALL ON FUNCTION public.${fn}_legacy_v2(');
      final create = _at(s, 'CREATE FUNCTION public.$fn(');
      final acl = _at(s, 'GRANT EXECUTE ON FUNCTION public.$fn(');
      final postCheck = _at(s, 'aclexplode');
      expect(pre < rename && preLegacy < rename, isTrue);
      expect(rename < revoke && revoke < create && create < acl, isTrue);
      expect(acl < postCheck, isTrue);
      expect(s.substring(revoke).split(';').first,
          endsWith('FROM PUBLIC, anon, authenticated'));
    });

    test('$fn: new function revoked from PUBLIC and anon, granted only to authenticated + service_role', () {
      final s = all[file]!;
      final grants = RegExp('GRANT [^;]*ON FUNCTION public\\.$fn\\([^;]*;')
          .allMatches(s)
          .map((m) => m.group(0)!)
          .toList();
      expect(grants, hasLength(1));
      expect(grants.single, endsWith('TO authenticated, service_role;'));
      expect(grants.single.contains('anon'), isFalse);
      expect(grants.single.contains('PUBLIC'), isFalse);
      expect(RegExp('REVOKE ALL ON FUNCTION public\\.$fn\\([^;]*\\) FROM PUBLIC, anon;')
          .hasMatch(s), isTrue);
      expect(s, contains("a.grantee = 0 OR a.grantee = 'anon'::regrole"));
    });

    test('$fn: p_request_id is the only new parameter', () {
      final s = all[file]!;
      final sig = s.substring(_at(s, 'CREATE FUNCTION public.$fn('));
      final params = sig.substring(0, sig.indexOf(' RETURNS '));
      expect(RegExp(r'\bp_\w+').allMatches(params).map((m) => m.group(0)).last,
          'p_request_id');
      expect(params, contains('p_request_id uuid DEFAULT NULL'));
      expect(RegExp(r'p_hashtags|p_request_key').hasMatch(s), isFalse);
    });

    test('$fn: request-id lookup runs before guards and the create', () {
      final s = all[file]!;
      final body = s.substring(_at(s, 'CREATE FUNCTION public.$fn('));
      final lookup = _at(body, 'request_id = p_request_id');
      if (fn == 'create_post') {
        expect(lookup < _at(body, 'geo_incomplete'), isTrue);
        expect(lookup < _at(body, 'INSERT INTO public.posts'), isTrue);
        expect(lookup < _at(body, 'FROM public.profiles'), isTrue);
        expect(body, contains('author_user_id = v_uid AND request_id = p_request_id'));
      } else {
        expect(body, contains('public.effective_actor_uid()'));
        final call = body.indexOf('public.${fn}_legacy_v2(', _at(body, 'END IF;'));
        expect(lookup < call, isTrue);
        expect(lookup < _at(body, 'set_config'), isTrue);
      }
    });

    test('$fn: unique_violation handler checks the index name then re-raises', () {
      final s = all[file]!;
      final idx = {
        'create_post': 'posts_author_user_request_id_key',
        'rpc_create_game': 'games_creator_user_request_id_key',
        'rpc_create_meetup': 'meetups_creator_user_request_id_key',
      }[fn]!;
      final h = s.substring(_at(s, 'EXCEPTION WHEN unique_violation THEN'));
      expect(h, contains('GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME'));
      expect(h, contains("'$idx'"));
      expect(h, contains('RAISE;'));
    });
  }

  test('create_post carries no hashtag code', () {
    expect(RegExp(r'hashtag', caseSensitive: false).hasMatch(post), isFalse);
  });

  test('rollback renames to _v3_rolledback, restores legacy names and grants, keeps columns', () {
    for (final fn in ['create_post', 'rpc_create_game', 'rpc_create_meetup']) {
      final away = _at(undo, 'RENAME TO ${fn}_v3_rolledback');
      final back = _at(undo, 'public.${fn}_legacy_v2(');
      expect(away < back, isTrue);
      expect(RegExp('REVOKE ALL ON FUNCTION public\\.${fn}_v3_rolledback\\([^;]*\\) FROM PUBLIC, anon, authenticated;')
          .hasMatch(undo), isTrue);
      expect(RegExp('GRANT EXECUTE ON FUNCTION public\\.$fn\\([^;]*\\) TO authenticated, service_role;')
          .hasMatch(undo), isTrue);
    }
    final raw = File('$_pack/rollback.sql').readAsStringSync();
    expect(raw, contains('No DROP'));
    expect(raw, contains('Left in place on purpose'));
  });

  test('probes: not run, P0 and X1, rollback batches, no hashtag probes', () {
    expect(probes, contains('AUTHORED NOT RUN'));
    expect(probes, contains('KAN611 PASS P0'));
    expect(probes, contains('KAN611 PASS X1'));
    expect(probes, contains("a.grantee = 'anon'::regrole"));
    expect(RegExp(r'hashtag', caseSensitive: false).hasMatch(probes), isFalse);
    final begins = RegExp(r'^begin( read only)?;', multiLine: true).allMatches(probes).length;
    final rollbacks =
        RegExp(r'^rollback;', multiLine: true).allMatches(probes).length;
    expect(begins, rollbacks);
    expect(RegExp(r'^commit', multiLine: true, caseSensitive: false)
        .hasMatch(probes), isFalse);
  });
}
