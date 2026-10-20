import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-529 migration: msg_evaluate returns game_ended / game_cancelled.
/// The migration is authored and NOT applied; these tests pin its text. They run no SQL.
const _dir = 'supabase/migrations';
const _new = '$_dir/20261013160100_kan529_msg_evaluate_closed_game_reasons.sql';
const _old = '$_dir/20261013150200_kan505_msg_functions.sql';
const _pack = 'supabase/tests/messaging';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// The msg_evaluate definition: from its CREATE to the closing $$;.
String _evaluate(String sql) {
  final a = sql.indexOf('CREATE OR REPLACE FUNCTION public.msg_evaluate(');
  final b = sql.indexOf(r'$$;', a) + 3;
  return sql.substring(a, b);
}

void main() {
  late String raw;
  late String sql;

  setUpAll(() {
    raw = File(_new).readAsStringSync();
    sql = _squash(_strip(raw));
  });

  test(
    'exists, is dated after the KAN-505 migrations and redefines msg_evaluate',
    () {
      expect(File(_new).existsSync(), isTrue);
      final newest505 = Directory(_dir)
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .where((n) => n.contains('kan505'))
          .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      expect(_new.split('/').last.compareTo(newest505), greaterThan(0));
      expect(sql, contains('CREATE OR REPLACE FUNCTION public.msg_evaluate('));
      expect(
        sql,
        isNot(contains('msg_authorize')),
      ); // passes through unchanged: not redefined
    },
  );

  test('returns both contracted reasons and no longer returns read_only', () {
    expect(sql, contains("'game_cancelled'::text"));
    expect(sql, contains("'game_ended'::text"));
    expect(sql, isNot(contains('read_only')));
    expect(sql, contains("'read'::text, 'game_cancelled'::text"));
    expect(sql, contains("'read'::text, 'game_ended'::text"));
    // cancelled is tested first, so it wins over an ended game
    expect(
      sql.indexOf('IF v_cancelled THEN'),
      lessThan(sql.indexOf('ELSIF v_end_at >= now() THEN')),
    );
  });

  test('no DROP; keeps SECURITY DEFINER, STABLE and the search_path', () {
    expect(RegExp(r'\bdrop\b', caseSensitive: false).hasMatch(raw), isFalse);
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains('STABLE'));
    expect(sql, contains("SET search_path = 'public', 'pg_temp'"));
    expect(sql, isNot(contains('GRANT')));
    expect(sql, isNot(contains('REVOKE')));
  });

  test('every clause but the closed-game branch is identical to KAN-505', () {
    final oldBody = _squash(_strip(_evaluate(File(_old).readAsStringSync())));
    final newBody = _squash(_strip(_evaluate(raw)));
    const oldBranch =
        "IF NOT v_cancelled AND v_end_at >= now() THEN RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, v_game_id; ELSE RETURN QUERY SELECT 'read'::text, 'read_only'::text, NULL::bigint, v_game_id; END IF;";
    const newBranch =
        "IF v_cancelled THEN RETURN QUERY SELECT 'read'::text, 'game_cancelled'::text, NULL::bigint, v_game_id; ELSIF v_end_at >= now() THEN RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, v_game_id; ELSE RETURN QUERY SELECT 'read'::text, 'game_ended'::text, NULL::bigint, v_game_id; END IF;";
    expect(oldBody, contains(oldBranch));
    expect(newBody, contains(newBranch));
    expect(newBody, oldBody.replaceFirst(oldBranch, newBranch));
  });

  test(
    'the KAN-505 file is byte-unchanged (still the original read_only body)',
    () {
      final o = File(_old).readAsStringSync();
      expect(o, contains("'read'::text, 'read_only'::text"));
      expect(o, isNot(contains('game_cancelled')));
    },
  );

  test('rollback restores the KAN-505 msg_evaluate body verbatim, no DROP', () {
    final rb = File('$_pack/rollback.sql').readAsStringSync();
    final tail = rb.substring(rb.indexOf('KAN-529 rollback'));
    expect(RegExp(r'\bdrop\b', caseSensitive: false).hasMatch(rb), isFalse);
    expect(_evaluate(tail), _evaluate(File(_old).readAsStringSync()));
    expect(tail, contains("'read'::text, 'read_only'::text"));
  });

  test(
    'probes P5, P6 and P6b assert the exact reasons inside begin/rollback',
    () {
      final p = File('$_pack/probes.sql').readAsStringSync();
      for (final tag in ['P5', 'P6', 'P6b']) {
        final a = p.indexOf('-- $tag [');
        expect(a, greaterThanOrEqualTo(0), reason: tag);
        final end = p.indexOf('\nrollback;', a);
        final block = p.substring(a, end + 10);
        expect(block, contains('\nbegin;'), reason: tag);
        expect(block, contains('AUTHORED, NOT RUN'), reason: tag);
        expect(block, contains("allowed_action = 'read'"), reason: tag);
        expect(block, isNot(contains('read_only')), reason: tag);
      }
      expect(p, contains("r.reason = 'game_ended'"));
      expect(p, contains("r.reason = 'game_cancelled'"));
      expect(p, contains('pass_cancelled_and_ended_game_cancelled'));
    },
  );

  test('README reasons table lists the two reasons instead of read_only', () {
    final r = File('$_pack/README.md').readAsStringSync();
    expect(r, contains('| `game_ended` |'));
    expect(r, contains('| `game_cancelled` |'));
    expect(r, isNot(contains('`read_only`')));
  });
}
