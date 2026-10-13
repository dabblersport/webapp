import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-499 migration and probe pack. The migration is authored and NOT
/// applied; these tests pin its shape, its order after KAN-497, the absence of any DROP, and the
/// properties the probes assert at run time later. They run no SQL.
const _name = '20261013120000_kan499_collapse_rpc_block_user_overload.sql';
const _kan497Names = <String>[
  '20261013100000_kan497_is_blocked_narrow_to_caller.sql',
  '20261013110000_kan497_revoke_anon_block_rpcs.sql',
];
const _dir = 'supabase/migrations';
const _packDir = 'supabase/tests/block_overload_collapse';

String _stripComments(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Problems with the order: the migration must sort strictly after every KAN-497 migration and
/// after every other migration in the directory. Empty means fine.
List<String> _orderProblems(String name, List<String> mustPrecede) {
  final problems = <String>[];
  for (final other in mustPrecede) {
    if (name.compareTo(other) <= 0) {
      problems.add('$name does not sort after $other');
    }
  }
  return problems;
}

/// Any DROP statement (functions, tables, policies, triggers, anything) in SQL with comments removed.
List<String> _dropProblems(String sqlWithoutComments) => RegExp(
  r'\bDROP\b',
  caseSensitive: false,
).allMatches(sqlWithoutComments).map((m) => 'DROP found').toList();

/// Splits probes.sql into blocks: marker comment line (`-- A1 [READ-ONLY] ...`) up to its `rollback;`.
List<({String id, String marker, String body})> _blocks(String probes) {
  final lines = probes.split('\n');
  final blocks = <({String id, String marker, String body})>[];
  final head = RegExp(
    r'^-- ([A-C]\d) \[(READ-ONLY|WRITE-IN-TRANSACTION-ROLLBACK)\]',
  );
  for (var i = 0; i < lines.length; i++) {
    final m = head.firstMatch(lines[i]);
    if (m == null) continue;
    var j = i + 1;
    while (j < lines.length && lines[j].trim() != 'rollback;') {
      j++;
    }
    blocks.add((
      id: m.group(1)!,
      marker: m.group(2)!,
      body: lines.sublist(i + 1, j + 1).join('\n'),
    ));
  }
  return blocks;
}

void main() {
  late String raw;
  late String sql; // comments stripped
  late String probes;
  late String rollbackRaw;
  late String rollback;
  late String readme;
  late String callers;

  setUpAll(() {
    raw = File('$_dir/$_name').readAsStringSync();
    sql = _stripComments(raw);
    probes = File('$_packDir/probes.sql').readAsStringSync();
    rollbackRaw = File('$_packDir/rollback.sql').readAsStringSync();
    rollback = _stripComments(rollbackRaw);
    readme = File('$_packDir/README.md').readAsStringSync();
    callers = File('$_packDir/CALLERS.md').readAsStringSync();
  });

  group('order (AC4)', () {
    test(
      'sorts strictly after KAN-497\'s migrations and after every other',
      () {
        final others =
            Directory(_dir)
                .listSync()
                .map((e) => e.uri.pathSegments.last)
                .where(
                  (n) =>
                      n.endsWith('.sql') &&
                      RegExp(r'^\d{14}_').hasMatch(n) &&
                      n != _name,
                )
                .toList()
              ..sort();
        expect(_orderProblems(_name, [..._kan497Names, others.last]), isEmpty);
      },
    );

    test('the order check fails when the order is reversed', () {
      // A KAN-499 file stamped before KAN-497's revoke must be flagged.
      expect(
        _orderProblems(
          '20261013100500_kan499_collapse_rpc_block_user_overload.sql',
          _kan497Names,
        ),
        isNotEmpty,
      );
      expect(_orderProblems(_kan497Names.last, _kan497Names), isNotEmpty);
    });

    test('exactly one new migration file for this ticket', () {
      final mine = Directory(_dir)
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .where((n) => n.contains('kan499'));
      expect(mine.toList(), [_name]);
    });
  });

  group('no DROP (AC2, AC4, AC7)', () {
    test('the migration contains no DROP', () {
      expect(_dropProblems(sql), isEmpty);
    });

    test('the DROP check fails on a DROP', () {
      expect(_dropProblems('drop function public.x();'), isNotEmpty);
      expect(_dropProblems('DROP TABLE public.restrictions;'), isNotEmpty);
      expect(_dropProblems('ALTER FUNCTION a() RENAME TO b;'), isEmpty);
    });

    test('rollback.sql contains no DROP either', () {
      expect(_dropProblems(rollback), isEmpty);
    });
  });

  group('migration shape (AC2, AC3)', () {
    String s() => _squash(sql);

    test('renames the 2-argument overload to rpc_block_user_legacy_v1', () {
      expect(
        s(),
        contains(
          'ALTER FUNCTION public.rpc_block_user(uuid, boolean) '
          'RENAME TO rpc_block_user_legacy_v1;',
        ),
      );
      expect(
        RegExp(r'ALTER FUNCTION', caseSensitive: false).allMatches(sql).length,
        1,
        reason: 'one ALTER FUNCTION only',
      );
    });

    test(
      'revokes ALL on the renamed function from PUBLIC, anon, authenticated',
      () {
        expect(
          s(),
          contains(
            'REVOKE ALL ON FUNCTION public.rpc_block_user_legacy_v1(uuid, boolean) '
            'FROM PUBLIC, anon, authenticated;',
          ),
        );
      },
    );

    test(
      'carries restrictions type blocked into user_blocks, ON CONFLICT DO NOTHING',
      () {
        expect(
          s(),
          contains(
            'INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) '
            'SELECT r.user_id, r.target_user_id FROM public.restrictions r '
            "WHERE r.type = 'blocked' "
            'ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING;',
          ),
        );
      },
    );

    test(
      'writes nothing to restrictions: no INSERT, UPDATE, DELETE or TRUNCATE on it',
      () {
        for (final bad in <RegExp>[
          RegExp(
            r'INSERT\s+INTO\s+(public\.)?"?restrictions',
            caseSensitive: false,
          ),
          RegExp(r'UPDATE\s+(public\.)?"?restrictions', caseSensitive: false),
          RegExp(
            r'DELETE\s+FROM\s+(public\.)?"?restrictions',
            caseSensitive: false,
          ),
          RegExp(r'TRUNCATE', caseSensitive: false),
          RegExp(r'ALTER\s+TABLE', caseSensitive: false),
        ]) {
          expect(bad.hasMatch(sql), isFalse, reason: bad.pattern);
        }
      },
    );

    test('touches no other function and edits no body', () {
      expect(
        RegExp(
          r'CREATE\s+(OR\s+REPLACE\s+)?FUNCTION',
          caseSensitive: false,
        ).hasMatch(sql),
        isFalse,
      );
      // Every function name in a statement is the renamed pair or the kept 2-arg original.
      final names = RegExp(
        r'public\.(\w+)\(',
      ).allMatches(sql).map((m) => m.group(1)).toSet();
      expect(names, {'rpc_block_user', 'rpc_block_user_legacy_v1'});
      expect(RegExp(r'\bGRANT\b', caseSensitive: false).hasMatch(sql), isFalse);
    });

    test('statement order: rename, revoke, carry-over', () {
      final a = sql.indexOf('RENAME TO');
      final b = sql.indexOf('REVOKE ALL');
      final c = sql.indexOf('INSERT INTO public.user_blocks');
      expect(a, greaterThanOrEqualTo(0));
      expect(b, greaterThan(a));
      expect(c, greaterThan(b));
    });

    test('header says AUTHORED, NOT APPLIED and names the rollback', () {
      expect(raw, contains('AUTHORED, NOT APPLIED'));
      expect(raw, contains('rollback.sql'));
    });
  });

  group('probes (AC5, AC8)', () {
    test('says AUTHORED, NOT RUN and never claims a run', () {
      expect(probes, contains('AUTHORED, NOT RUN'));
      for (final doc in <String>[probes, readme, callers, raw]) {
        expect(
          RegExp(
            r'(were|was|has been|have been) (run|executed|applied)\b(?! later| against any)',
            caseSensitive: false,
          ).allMatches(doc).where((m) {
            final ctx = doc.substring(
              (m.start - 40).clamp(0, doc.length),
              (m.end + 20).clamp(0, doc.length),
            );
            return !RegExp(
              r'\b(not|never|nothing|no probe|none)\b',
              caseSensitive: false,
            ).hasMatch(ctx);
          }),
          isEmpty,
        );
      }
    });

    test(
      'has pre-apply (A), post-apply (B) and post-rollback (C) sections',
      () {
        expect(probes, contains('A. PRE-APPLY'));
        expect(probes, contains('B. POST-APPLY'));
        expect(probes, contains('C. POST-ROLLBACK'));
      },
    );

    test('every block is marked and wrapped; READ-ONLY blocks write nothing', () {
      final blocks = _blocks(probes);
      expect(blocks.length, greaterThanOrEqualTo(12));
      for (final b in blocks) {
        final body = _stripComments(b.body);
        expect(body.trim().endsWith('rollback;'), isTrue, reason: b.id);
        if (b.marker == 'READ-ONLY') {
          expect(body, contains('begin read only;'), reason: b.id);
          expect(
            RegExp(
              r'\b(insert|update|delete|truncate|alter|create)\b|rpc_block_user\(|rpc_unblock_user\(',
              caseSensitive: false,
            ).hasMatch(body.replaceAll(RegExp(r"'[^']*'"), "''")),
            isFalse,
            reason: '${b.id} is READ-ONLY but looks like it writes',
          );
        } else {
          expect(body.trimLeft().startsWith('begin;'), isTrue, reason: b.id);
        }
      }
    });

    test('no write statement lies outside a BEGIN ... ROLLBACK wrapper', () {
      // Remove every wrapped block; nothing that writes may be left.
      var rest = _stripComments(probes);
      rest = rest.replaceAll(
        RegExp(r'begin( read only)?;.*?rollback;', dotAll: true),
        '',
      );
      expect(
        RegExp(
          r'\b(insert|update|delete|truncate|alter|create|drop|grant|revoke)\b',
          caseSensitive: false,
        ).hasMatch(rest),
        isFalse,
      );
    });

    test('runs as authenticated and anon with request.jwt.claims', () {
      expect(probes, contains('set local role authenticated'));
      expect(probes, contains('set local role anon'));
      expect(probes, contains('request.jwt.claims'));
    });

    test('covers the required behaviours', () {
      // the 2-arg call naming p_block no longer resolves
      expect(probes, contains('undefined_function'));
      expect(probes, contains('p_block => true'));
      // 1-arg block / unblock still work
      expect(probes, contains('public.rpc_block_user(b);'));
      expect(probes, contains('public.rpc_unblock_user(b);'));
      // a block still fires the admin-notify trigger
      expect(probes, contains('trg_notify_admins_of_block'));
      expect(probes, contains("kind_key = 'moderation.user_blocked'"));
      // nothing written to restrictions
      expect(probes, contains('B4 FAIL: block wrote restrictions'));
      expect(probes, contains('restrictions_rows'));
      // legacy ACL: false for anon, authenticated and PUBLIC
      expect(
        probes,
        contains("has_function_privilege('anon', p.oid, 'EXECUTE')"),
      );
      expect(
        probes,
        contains("has_function_privilege('authenticated', p.oid, 'EXECUTE')"),
      );
      expect(
        probes,
        contains("has_function_privilege('public', p.oid, 'EXECUTE')"),
      );
      expect(probes, contains('rpc_block_user_legacy_v1'));
      // dependents of the 2-arg overload read live
      expect(
        probes,
        contains(
          "refobjid = 'public.rpc_block_user(uuid, boolean)'::regprocedure",
        ),
      );
    });

    test('the carry-over statement in probes is the migration\'s own text', () {
      final carry = _squash(
        RegExp(
          r'INSERT INTO public\.user_blocks.*?DO NOTHING;',
          dotAll: true,
        ).firstMatch(sql)!.group(0)!,
      );
      expect(_squash(probes), contains(carry.replaceAll(';', '')));
    });
  });

  group('rollback (AC6)', () {
    test('renames back and re-grants, with no DROP', () {
      final s = _squash(rollback);
      expect(
        s,
        contains(
          'ALTER FUNCTION public.rpc_block_user_legacy_v1(uuid, boolean) '
          'RENAME TO rpc_block_user;',
        ),
      );
      expect(
        s,
        contains(
          'GRANT EXECUTE ON FUNCTION public.rpc_block_user(uuid, boolean) '
          'TO authenticated, service_role;',
        ),
      );
      expect(_dropProblems(rollback), isEmpty);
    });

    test(
      'says it is itself an apply that needs approval and re-opens the store',
      () {
        expect(rollbackRaw, contains('AUTHORED, NOT RUN'));
        expect(rollbackRaw, contains('APPLY'));
        expect(rollbackRaw, contains('CEO'));
        expect(rollbackRaw, contains('RE-OPENS the second block store'));
      },
    );
  });

  group('docs and safety (AC1, AC6, AC7, AC8)', () {
    test('CALLERS.md lists callers with their kinds and the app result', () {
      for (final kind in <String>[
        'app',
        'edge fn',
        'trigger',
        'view',
        'function',
        'migration-only',
      ]) {
        expect(callers, contains('| $kind |'), reason: kind);
      }
      expect(callers, contains('block_repository_impl.dart:24'));
      expect(callers, contains("{'p_peer': targetUserId}"));
      expect(callers, contains('**does not call it**'));
      expect(callers, contains('rpc_restrict_set'));
      expect(callers, contains('git grep'));
    });

    test(
      'README states the order, the approval and that nothing was applied or run',
      () {
        expect(readme, contains('AUTHORED, NOT APPLIED, NOT RUN'));
        expect(readme, contains('wtncuzcskpigqpmnxwws'));
        expect(readme, contains('KAN-497'));
        expect(readme, contains('no DROP'));
        expect(readme, contains("CEO's"));
        expect(readme, contains('rollback'));
        expect(readme, contains('re-opens'));
      },
    );

    test('no secret or other project reference in any file of this ticket', () {
      final files = <String>[
        raw,
        probes,
        rollbackRaw,
        readme,
        callers,
        File(
          'test/supabase/block_overload_collapse_migration_test.dart',
        ).readAsStringSync().replaceAll(RegExp(r"r'[^']*'"), ''),
      ];
      final secretLike = RegExp(
        r'(eyJ[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9]{20,}|sk_(live|test)_|service_role_key\s*[:=]|postgres(ql)?://\S+:\S+@|(?=[A-Za-z0-9]*\d)(?=[A-Za-z0-9]*[A-Z])(?=[A-Za-z0-9]*[a-z])[A-Za-z0-9]{40,})',
      );
      for (final f in files) {
        expect(secretLike.hasMatch(f), isFalse);
        final refs = RegExp(
          r'([a-z]{20})\.supabase\.co',
        ).allMatches(f).map((m) => m.group(1)).toSet();
        expect(refs.difference({'wtncuzcskpigqpmnxwws'}), isEmpty);
      }
    });
  });
}
