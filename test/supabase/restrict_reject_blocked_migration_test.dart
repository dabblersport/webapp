import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-522 migration and its probe pack. The migration is
/// authored and NOT applied; these tests pin its shape.
const _name = '20261013130000_restrict_rpcs_reject_blocked.sql';
const _path = 'supabase/migrations/$_name';
const _pack = 'supabase/tests/restrict_reject_blocked';
const _baseline = 'supabase/migrations/20260829080500_baseline_schema.sql';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// The text of `CREATE OR REPLACE FUNCTION public.<name>(` up to `$function$;`.
String _fn(String sql, String name) {
  final start = RegExp(
    'CREATE OR REPLACE FUNCTION public\\.$name\\(',
  ).firstMatch(sql);
  expect(start, isNotNull, reason: '$name must be redefined');
  final end = sql.indexOf(r'$function$;', start!.start);
  return sql.substring(start.start, end + 11);
}

void main() {
  late String raw;
  late String sql;
  late String probes;
  late String rollback;
  late String readme;
  late String callers;

  setUpAll(() {
    raw = File(_path).readAsStringSync();
    sql = _strip(raw);
    probes = File('$_pack/probes.sql').readAsStringSync();
    rollback = File('$_pack/rollback.sql').readAsStringSync();
    readme = File('$_pack/README.md').readAsStringSync();
    callers = File('$_pack/CALLERS.md').readAsStringSync();
  });

  group('migration', () {
    test('sorts after 20261013120000 (KAN-499) and the earlier migrations', () {
      // Later migrations (KAN-523 and on) may sort after this one by design.
      expect(_name.compareTo('20261013120000'), greaterThan(0));
      expect(_name.compareTo('20261013110000'), greaterThan(0));
      expect(
        _name.compareTo('20260829080500_baseline_schema.sql'),
        greaterThan(0),
      );
    });

    test(
      'redefines exactly the two functions, no DROP, no other statement',
      () {
        final creates = RegExp(
          r'CREATE\s+OR\s+REPLACE\s+FUNCTION\s+([\w.]+)\s*\(',
        ).allMatches(sql).map((m) => m.group(1)).toList();
        expect(creates, [
          'public.rpc_restrict_set',
          'public.rpc_restrict_clear',
        ]);
        expect(sql, isNot(matches(RegExp(r'\bDROP\b', caseSensitive: false))));
        expect(
          sql,
          isNot(matches(RegExp(r'\bALTER\s+TABLE\b', caseSensitive: false))),
        );
        expect(sql, isNot(contains('public.rpc_block_user')));
        expect(sql, isNot(contains('public.rpc_unblock_user')));
      },
    );

    test('keeps signature, SECURITY DEFINER and search_path', () {
      for (final f in ['rpc_restrict_set', 'rpc_restrict_clear']) {
        final b = _squash(_fn(sql, f));
        expect(b, contains('(p_target uuid, p_type text)'));
        expect(b, contains('RETURNS void'));
        expect(b, contains('LANGUAGE plpgsql SECURITY DEFINER'));
        expect(b, contains("SET search_path TO 'public'"));
      }
    });

    test("'blocked' raises the typed errors with errcode P0001", () {
      final set = _squash(_fn(sql, 'rpc_restrict_set'));
      final clear = _squash(_fn(sql, 'rpc_restrict_clear'));
      expect(
        set,
        contains(
          "if p_type = 'blocked' then raise exception using errcode='P0001', "
          "message='use_rpc_block_user'; end if;",
        ),
      );
      expect(
        clear,
        contains(
          "if p_type = 'blocked' then raise exception using errcode='P0001', "
          "message='use_rpc_unblock_user'; end if;",
        ),
      );
      // The rejection comes before the generic type check.
      expect(
        set.indexOf("message='use_rpc_block_user'"),
        lessThan(set.indexOf("message='invalid_type'")),
      );
      expect(
        clear.indexOf("message='use_rpc_unblock_user'"),
        lessThan(clear.indexOf("message='invalid_type'")),
      );
    });

    test("'hidden' path and the guards are the baseline's, verbatim", () {
      final base = File(_baseline).readAsStringSync();
      for (final line in [
        "if me is null then raise exception using errcode='P0001', message='not_authenticated'; end if;",
        "if p_target is null or p_target = me then raise exception using errcode='P0001', message='invalid_target'; end if;",
        'insert into public.restrictions(user_id, target_user_id, type)',
        'values (me, p_target, p_type)',
        'on conflict (user_id, target_user_id, type) do nothing;',
        'delete from public.restrictions',
        'where user_id = me and target_user_id = p_target and type = p_type;',
      ]) {
        expect(_squash(base), contains(_squash(line)), reason: 'baseline');
        expect(_squash(sql), contains(_squash(line)), reason: line);
      }
      expect(sql, contains("p_type not in ('hidden')"));
    });

    test('writes nothing to user_blocks and no longer touches friendships', () {
      expect(sql, isNot(contains('user_blocks')));
      expect(sql, isNot(contains('friendships')));
      expect(sql, isNot(contains("'blocked')\n")));
    });

    test('revokes PUBLIC and anon, grants authenticated and service_role', () {
      for (final sig in [
        'public.rpc_restrict_set(uuid, text)',
        'public.rpc_restrict_clear(uuid, text)',
      ]) {
        final s = RegExp.escape(sig);
        expect(
          RegExp(
            'REVOKE EXECUTE ON FUNCTION $s FROM PUBLIC, anon;',
          ).hasMatch(sql),
          isTrue,
          reason: sig,
        );
        expect(
          RegExp(
            'GRANT\\s+EXECUTE ON FUNCTION $s TO authenticated, service_role;',
          ).hasMatch(sql),
          isTrue,
          reason: sig,
        );
      }
      expect(RegExp(r'\bREVOKE\b').allMatches(sql).length, 2);
      expect(RegExp(r'\bGRANT\b').allMatches(sql).length, 2);
    });

    test('says it was not applied', () {
      expect(raw, contains('AUTHORED, NOT APPLIED'));
    });
  });

  group('probe pack', () {
    test('states AUTHORED, NOT RUN and never claims a run', () {
      expect(probes, contains('AUTHORED, NOT RUN'));
      expect(readme, contains('NOT APPLIED, NOT RUN'));
      expect(probes, isNot(matches(RegExp(r'(was|were|has been) run\b'))));
    });

    test('every statement sits inside BEGIN ... ROLLBACK', () {
      var depth = 0;
      var blocks = 0;
      for (final l in probes.split('\n')) {
        final line = l.trim();
        if (line.isEmpty || line.startsWith('--')) continue;
        if (line == 'begin;' || line == 'begin read only;') {
          expect(depth, 0, reason: 'nested begin');
          depth = 1;
          blocks++;
          continue;
        }
        if (line == 'rollback;') {
          expect(depth, 1);
          depth = 0;
          continue;
        }
        expect(depth, 1, reason: 'outside a rollback wrapper: $line');
      }
      expect(depth, 0);
      expect(blocks, greaterThanOrEqualTo(10));
      expect(
        probes,
        isNot(matches(RegExp(r'^\s*commit\s*;', multiLine: true))),
      );
    });

    test('has pre-apply and post-apply blocks with markers', () {
      expect(probes, contains('A. PRE-APPLY'));
      expect(probes, contains('B. POST-APPLY'));
      expect(probes, contains('[READ-ONLY]'));
      expect(probes, contains('[WRITE-IN-TRANSACTION-ROLLBACK]'));
      expect(probes, contains('begin read only;'));
    });

    test('covers the required cases', () {
      expect(probes, contains('set local role authenticated'));
      expect(probes, contains('set local role anon'));
      expect(probes, contains('request.jwt.claims'));
      for (final s in [
        "rpc_restrict_set(b, 'blocked')",
        'use_rpc_block_user',
        "rpc_restrict_clear(b, 'blocked')",
        'use_rpc_unblock_user',
        "rpc_restrict_set(b, 'hidden')",
        "rpc_restrict_clear(b, 'hidden')",
        'is_hidden',
        "has_function_privilege('anon'",
        'a.grantee = 0',
        'insufficient_privilege',
        'rpc_block_user(b)',
        'user_blocks',
      ]) {
        expect(probes, contains(s), reason: s);
      }
    });
  });

  group('rollback, README, callers', () {
    test('rollback restores the baseline bodies and ACL with no DROP', () {
      final base = File(_baseline).readAsStringSync();
      for (final name in ['rpc_restrict_clear', 'rpc_restrict_set']) {
        final start = base.indexOf(
          'CREATE OR REPLACE FUNCTION "public"."$name"',
        );
        expect(start, greaterThanOrEqualTo(0));
        final body = base.substring(start, base.indexOf(r'$$;', start) + 3);
        expect(_squash(rollback), contains(_squash(body)), reason: name);
      }
      expect(
        _strip(rollback),
        isNot(matches(RegExp(r'\bDROP\b', caseSensitive: false))),
      );
      expect(
        rollback,
        contains(
          'GRANT EXECUTE ON FUNCTION public.rpc_restrict_set(uuid, text)   '
          'TO PUBLIC, anon, authenticated, service_role;',
        ),
      );
      expect(rollback, contains('AUTHORED, NOT RUN'));
    });

    test('README states Memphis, reopened store, old rows and no claim', () {
      expect(readme, contains('Memphis'));
      expect(readme, contains('reopens the second block store'));
      expect(readme, contains('itself an apply'));
      expect(readme, contains('can no longer clear an old'));
      expect(readme, contains('KAN-499'));
      expect(readme, contains('no DROP'));
    });

    test('the caller map reports none, with the evidence', () {
      expect(callers, contains('No caller'));
      expect(callers, contains('git grep'));
      expect(callers, contains('lib/'));
      expect(callers, contains('supabase/functions/'));
      expect(callers, contains('workers/'));
    });
  });

  test('no secret-like string in any authored file', () {
    final all = [raw, probes, rollback, readme, callers].join('\n');
    for (final bad in [
      RegExp(r'eyJ[A-Za-z0-9_-]{10,}'),
      RegExp(r'postgres(ql)?://'),
      RegExp(r'supabase\.co'),
      RegExp(r'service_role_key', caseSensitive: false),
    ]) {
      expect(bad.hasMatch(all), isFalse, reason: bad.pattern);
    }
  });
}
