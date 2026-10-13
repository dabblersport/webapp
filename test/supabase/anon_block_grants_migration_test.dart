import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-497 migrations and probe pack. Both migrations are
/// authored and NOT applied; these tests pin their shape, their order and the
/// properties the probes assert at run time later.
const _narrowName = '20261013100000_kan497_is_blocked_narrow_to_caller.sql';
const _revokeName = '20261013110000_kan497_revoke_anon_block_rpcs.sql';
const _dir = 'supabase/migrations';
const _packDir = 'supabase/tests/anon_block_grants';
const _baselinePath = 'supabase/migrations/20260829080500_baseline_schema.sql';

const _inScope = <String>[
  'public.rpc_block_user(uuid)',
  'public.rpc_block_user(uuid, boolean)',
  'public.rpc_unblock_user(uuid)',
  'public.rpc_unfollow_user(uuid)',
];

String _stripComments(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// The narrowing must sort strictly before the revoke, and the revoke must not
/// carry the narrowing. Returns the problems found (empty means fine).
List<String> _orderProblems(
  String narrowName,
  String revokeName,
  String revokeSql,
) {
  final problems = <String>[];
  if (narrowName.compareTo(revokeName) >= 0) {
    problems.add('narrowing does not sort strictly before the revoke');
  }
  if (RegExp(
    r'CREATE\s+(OR\s+REPLACE\s+)?FUNCTION',
    caseSensitive: false,
  ).hasMatch(revokeSql)) {
    problems.add('the revoke file also defines a function');
  }
  return problems;
}

void main() {
  late String narrowRaw;
  late String narrow; // comments stripped
  late String revokeRaw;
  late String revoke; // comments stripped
  late String probes;
  late String rollback;
  late String readme;
  late String callers;

  setUpAll(() {
    narrowRaw = File('$_dir/$_narrowName').readAsStringSync();
    narrow = _stripComments(narrowRaw);
    revokeRaw = File('$_dir/$_revokeName').readAsStringSync();
    revoke = _stripComments(revokeRaw);
    probes = File('$_packDir/probes.sql').readAsStringSync();
    rollback = File('$_packDir/rollback.sql').readAsStringSync();
    readme = File('$_packDir/README.md').readAsStringSync();
    callers = File('$_packDir/CALLERS.md').readAsStringSync();
  });

  group('order', () {
    test('both files sort after the migrations that existed when authored', () {
      // Later migrations (KAN-499 and on) may sort after these two by design.
      const existedWhenAuthored = <String>[
        '20260829080500_baseline_schema.sql',
        '20261008180000_revoke_legacy_and_anon_update_game.sql',
      ];
      for (final earlier in existedWhenAuthored) {
        expect(
          File('$_dir/$earlier').existsSync(),
          isTrue,
          reason: '$earlier must still exist',
        );
        expect(_narrowName.compareTo(earlier), greaterThan(0));
        expect(_revokeName.compareTo(earlier), greaterThan(0));
      }
    });

    test('the narrowing sorts strictly before the revoke', () {
      expect(_orderProblems(_narrowName, _revokeName, revoke), isEmpty);
    });

    test('the order check fails when the files are reversed or merged', () {
      expect(_orderProblems(_revokeName, _narrowName, revoke), isNotEmpty);
      expect(_orderProblems(_narrowName, _revokeName, narrow), isNotEmpty);
    });
  });

  group('narrowing migration (AC2)', () {
    test('defines exactly is_blocked, with CREATE OR REPLACE and no DROP', () {
      final creates = RegExp(
        r'CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\s+([\w.]+)\s*\(',
        caseSensitive: false,
      ).allMatches(narrow).toList();
      expect(creates, hasLength(1));
      expect(creates.single.group(1), isNotNull, reason: 'OR REPLACE');
      expect(creates.single.group(2), 'public.is_blocked');
      expect(narrow, contains('public.is_blocked(user_a uuid, user_b uuid)'));
      expect(narrow, isNot(matches(RegExp(r'\bDROP\b', caseSensitive: false))));
    });

    test('changes no grant and touches no other object', () {
      expect(
        narrow,
        isNot(matches(RegExp(r'\b(GRANT|REVOKE)\b', caseSensitive: false))),
      );
      expect(
        narrow,
        isNot(
          matches(
            RegExp(
              r'\b(ALTER|INSERT|UPDATE|DELETE|TRUNCATE)\b',
              caseSensitive: false,
            ),
          ),
        ),
      );
      expect(narrow, isNot(contains('rpc_')));
    });

    test(
      'keeps SECURITY DEFINER, STABLE, LANGUAGE sql and the search_path',
      () {
        final sql = _squash(narrow);
        expect(sql, contains('LANGUAGE sql'));
        expect(sql, contains('STABLE SECURITY DEFINER'));
        expect(sql, contains("SET search_path TO 'public', 'pg_temp'"));
        expect(sql, contains('RETURNS boolean'));
      },
    );

    test('is false when auth.uid() is NULL or is neither argument', () {
      final sql = _squash(narrow);
      expect(sql, contains('WHEN auth.uid() IS NULL THEN false'));
      expect(
        sql,
        contains(
          'WHEN auth.uid() IS DISTINCT FROM user_a '
          'AND auth.uid() IS DISTINCT FROM user_b THEN false',
        ),
      );
      // The false branches come before the real answer.
      expect(
        sql.indexOf('IS NULL THEN false'),
        lessThan(sql.indexOf('ELSE EXISTS')),
      );
    });

    test('the caller\'s own pairs use the baseline lookup unchanged', () {
      final baseline = File(_baselinePath).readAsStringSync();
      final start = baseline.indexOf(
        'CREATE OR REPLACE FUNCTION "public"."is_blocked"',
      );
      expect(start, greaterThanOrEqualTo(0));
      final body = baseline.substring(start, baseline.indexOf(r'$$;', start));
      final baseLookup = RegExp(
        r'SELECT 1 FROM public\.user_blocks\s+WHERE .*?\)\s*\)',
        dotAll: true,
      ).firstMatch(body);
      expect(baseLookup, isNotNull);
      final newLookup = RegExp(
        r'SELECT 1 FROM public\.user_blocks\s+WHERE .*?\)\s*\)',
        dotAll: true,
      ).firstMatch(narrow);
      expect(newLookup, isNotNull);
      expect(_squash(newLookup!.group(0)!), _squash(baseLookup!.group(0)!));
    });

    test('says it was not applied', () {
      expect(narrowRaw, contains('AUTHORED, NOT APPLIED'));
    });
  });

  group('revoke migration (AC5, decision 5)', () {
    test('revokes FROM PUBLIC, anon on exactly the four in-scope signatures', () {
      final revokes = RegExp(
        r'REVOKE\s+EXECUTE\s+ON\s+FUNCTION\s+([^;]+?)\s+FROM\s+PUBLIC,\s*anon\s*;',
        caseSensitive: false,
      ).allMatches(revoke).map((m) => m.group(1)!).toList();
      expect(revokes, _inScope);
      // No REVOKE of any other shape (e.g. anon alone).
      expect(
        RegExp(r'\bREVOKE\b', caseSensitive: false).allMatches(revoke).length,
        _inScope.length,
      );
    });

    test('grants EXECUTE to authenticated and service_role only', () {
      final grants = RegExp(
        r'GRANT\s+EXECUTE\s+ON\s+FUNCTION\s+([^;]+?)\s+TO\s+([^;]+?)\s*;',
        caseSensitive: false,
      ).allMatches(revoke).toList();
      expect(grants.map((m) => m.group(1)).toList(), _inScope);
      for (final m in grants) {
        expect(m.group(2), 'authenticated, service_role');
      }
      expect(
        RegExp(r'\bGRANT\b', caseSensitive: false).allMatches(revoke).length,
        _inScope.length,
      );
    });

    test('holds is_blocked out and touches nothing else', () {
      expect(revoke, isNot(contains('is_blocked')));
      expect(revoke, isNot(matches(RegExp(r'\bDROP\b', caseSensitive: false))));
      expect(revoke, isNot(contains('CREATE')));
      for (final other in <String>[
        'notify_admins_of_block',
        'rpc_remove_player',
        'can_view_with_scope',
      ]) {
        expect(revokeRaw, isNot(contains(other)), reason: other);
      }
      // Every function named in a statement is one of the four.
      final named = RegExp(
        r'public\.(\w+)\(',
      ).allMatches(revoke).map((m) => m.group(1)).toSet();
      expect(named, {
        'rpc_block_user',
        'rpc_unblock_user',
        'rpc_unfollow_user',
      });
    });

    test('says it was not applied and that the narrowing comes first', () {
      expect(revokeRaw, contains('AUTHORED, NOT APPLIED'));
      expect(revokeRaw, contains('Apply ONLY after the'));
      expect(revokeRaw, contains('narrowing migration is applied'));
    });
  });

  group('probe pack (AC4, AC8)', () {
    test('states AUTHORED, NOT RUN and never claims it was run', () {
      expect(probes, contains('AUTHORED, NOT RUN'));
      expect(readme, contains('NOT APPLIED, NOT RUN'));
      expect(probes, isNot(matches(RegExp(r'(was|were|has been) run\b'))));
    });

    test('every statement sits inside BEGIN ... ROLLBACK', () {
      var depth = 0;
      var blocks = 0;
      for (final raw in probes.split('\n')) {
        final line = raw.trim();
        if (line.isEmpty || line.startsWith('--')) continue;
        if (line == 'begin;' || line == 'begin read only;') {
          expect(depth, 0, reason: 'nested begin');
          depth = 1;
          blocks++;
          continue;
        }
        if (line == 'rollback;') {
          expect(depth, 1, reason: 'rollback outside a block');
          depth = 0;
          continue;
        }
        expect(depth, 1, reason: 'statement outside a rollback wrapper: $line');
      }
      expect(depth, 0);
      expect(blocks, greaterThanOrEqualTo(12));
      expect(
        probes,
        isNot(
          matches(
            RegExp(r'^\s*commit\s*;', multiLine: true, caseSensitive: false),
          ),
        ),
      );
    });

    test(
      'has pre-apply and post-apply sections with READ-ONLY / WRITE markers',
      () {
        expect(probes, contains('A. PRE-APPLY'));
        expect(probes, contains('B. POST-NARROWING'));
        expect(probes, contains('C. POST-REVOKE'));
        expect(probes, contains('[READ-ONLY]'));
        expect(probes, contains('[WRITE-IN-TRANSACTION-ROLLBACK]'));
        expect(probes, contains('begin read only;'));
      },
    );

    test('runs as anon, authenticated and a no-JWT role with jwt claims', () {
      expect(probes, contains('set local role anon'));
      expect(probes, contains('set local role authenticated'));
      expect(probes, contains('set local role service_role'));
      expect(probes, contains('request.jwt.claims'));
    });

    test('covers T-A1..T-A4 and the is_blocked cases', () {
      for (final id in ['T-A1', 'T-A2', 'T-A3', 'T-A4']) {
        expect(probes, contains(id), reason: id);
      }
      expect(probes, contains("has_function_privilege('anon'"));
      expect(probes, contains('aclexplode'));
      expect(probes, contains('a.grantee = 0'));
      expect(probes, contains('trg_notify_admins_of_block'));
      expect(probes, contains('moderation.user_blocked'));
      expect(probes, contains('insufficient_privilege'));
      // anon and a third party get false for a blocked pair; both parties get true.
      expect(probes, contains('third party learned'));
      expect(probes, contains('anon learned'));
      expect(probes, contains('blocked party asking'));
      for (final target in [
        'v_game_card',
        'v_meetup_list',
        'rpc_get_nearby_games',
        'get_feed',
        'rpc_meetup_card',
        'rpc_meetup_attendees',
        'can_current_user_rsvp_meetup',
      ]) {
        expect(probes, contains(target), reason: target);
      }
    });

    test(
      'the held is_blocked revoke is in section D, never in a migration',
      () {
        expect(probes, contains('D. HELD'));
        expect(
          readme,
          contains('REVOKE EXECUTE ON FUNCTION public.is_blocked'),
        );
        expect(revoke, isNot(contains('is_blocked')));
      },
    );
  });

  group('rollback and README (AC6, AC9)', () {
    test('rollback restores the baseline body and the grants, no DROP', () {
      final baseline = File(_baselinePath).readAsStringSync();
      final start = baseline.indexOf(
        'CREATE OR REPLACE FUNCTION "public"."is_blocked"',
      );
      final baseBody = baseline.substring(
        start,
        baseline.indexOf(r'$$;', start) + 3,
      );
      expect(_squash(rollback), contains(_squash(baseBody)));
      expect(
        _stripComments(rollback),
        isNot(matches(RegExp(r'\bDROP\b', caseSensitive: false))),
      );
      for (final sig in ['public.is_blocked(uuid, uuid)', ..._inScope]) {
        expect(
          RegExp(
            'GRANT EXECUTE ON FUNCTION ${RegExp.escape(sig)}\\s+TO PUBLIC, anon, authenticated, service_role;',
          ).hasMatch(rollback),
          isTrue,
          reason: sig,
        );
      }
      // The revoke is undone before the narrowing.
      expect(
        rollback.indexOf('GRANT EXECUTE'),
        lessThan(rollback.indexOf('CREATE OR REPLACE FUNCTION')),
      );
    });

    test(
      'README states order, approval, no DROP, last resort and live gate',
      () {
        expect(readme, contains('undo the revoke first, then the'));
        expect(readme, contains('needs the CEO\'s explicit approval'));
        expect(readme, contains('uses no DROP'));
        expect(readme, contains('last resort'));
        expect(readme, contains('The live gates were NOT run'));
        expect(readme, contains('runs'));
        expect(readme, contains('in CI after apply'));
      },
    );

    test('the caller map names every in-scope function and the app result', () {
      for (final f in [
        'is_blocked',
        'rpc_block_user',
        'rpc_unblock_user',
        'rpc_unfollow_user',
        'block_repository_impl.dart',
        'App-code result',
        'anon-reachable',
      ]) {
        expect(callers, contains(f), reason: f);
      }
    });
  });

  group('hygiene (AC7)', () {
    test('no secret-like string in any authored file', () {
      final all = [
        narrowRaw,
        revokeRaw,
        probes,
        rollback,
        readme,
        callers,
      ].join('\n');
      for (final bad in [
        RegExp(r'eyJ[A-Za-z0-9_-]{10,}'),
        RegExp(r'postgres(ql)?://'),
        RegExp(r'sb_secret'),
        RegExp(r'supabase\.co'),
        RegExp(r'SERVICE_ROLE_KEY', caseSensitive: false),
        RegExp(r'password\s*=', caseSensitive: false),
      ]) {
        expect(bad.hasMatch(all), isFalse, reason: bad.pattern);
      }
    });
  });
}
