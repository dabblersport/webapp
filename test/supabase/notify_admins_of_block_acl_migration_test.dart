import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-523 migration and its probe pack. The migration is
/// authored and NOT applied; these tests pin its shape.
const _name = '20261013140000_revoke_public_notify_admins_of_block.sql';
const _path = 'supabase/migrations/$_name';
const _pack = 'supabase/tests/notify_admins_of_block_acl';

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
    test('sorts after 20261013120000 and after every other migration', () {
      expect(_name.compareTo('20261013120000'), greaterThan(0));
      final others =
          Directory('supabase/migrations')
              .listSync()
              .map((e) => e.uri.pathSegments.last)
              .where(
                (n) =>
                    RegExp(r'^\d{14}_').hasMatch(n) &&
                    n != _name &&
                    n.endsWith('.sql'),
              )
              .toList()
            ..sort();
      expect(_name.compareTo(others.last), greaterThan(0));
    });

    test('is exactly one REVOKE and one GRANT on the function', () {
      final statements = sql
          .split(';')
          .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((s) => s.isNotEmpty)
          .toList();
      expect(statements, [
        'REVOKE ALL ON FUNCTION public.notify_admins_of_block() '
            'FROM PUBLIC, anon, authenticated',
        'GRANT EXECUTE ON FUNCTION public.notify_admins_of_block() '
            'TO service_role',
      ]);
    });

    test('no DROP, no body or trigger edit, authenticated not granted', () {
      expect(sql, isNot(matches(RegExp(r'\bDROP\b', caseSensitive: false))));
      expect(
        sql,
        isNot(matches(RegExp(r'\bCREATE\b|\bALTER\b', caseSensitive: false))),
      );
      expect(sql, isNot(contains('TRIGGER')));
      expect(RegExp(r'TO\s+authenticated').hasMatch(sql), isFalse);
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
      expect(blocks, 6);
      expect(
        probes,
        isNot(matches(RegExp(r'^\s*commit\s*;', multiLine: true))),
      );
    });

    test('has pre- and post-apply sections, markers and the ACL checks', () {
      expect(probes, contains('A. PRE-APPLY'));
      expect(probes, contains('B. POST-APPLY'));
      expect(probes, contains('[READ-ONLY]'));
      expect(probes, contains('[WRITE-IN-TRANSACTION-ROLLBACK]'));
      for (final s in [
        "has_function_privilege('anon'",
        "has_function_privilege('authenticated'",
        "has_function_privilege('service_role'",
        'a.grantee = 0',
        'insufficient_privilege',
        'set local role anon',
        'set local role authenticated',
        'request.jwt.claims',
        'rpc_block_user(b)',
        'moderation.user_blocked',
        'app_admins',
        'trg_notify_admins_of_block',
      ]) {
        expect(probes, contains(s), reason: s);
      }
    });
  });

  group('notification probes are not vacuous', () {
    test('A3 and B3 judge only NEW rows, one per admin, no extras', () {
      for (final tag in ['A3', 'B3']) {
        expect(
          RegExp("'$tag FAIL: expected % NEW notifications").hasMatch(probes),
          isTrue,
          reason: tag,
        );
        expect(
          probes,
          contains("'$tag FAIL: the % new notifications reach only"),
        );
        expect(
          probes,
          contains("'$tag FAIL: % new notifications went to someone"),
        );
        expect(
          probes,
          contains("'$tag FAIL: % admins did not get exactly one new"),
        );
        expect(
          probes,
          contains("'$tag fixture: blocker=% blocked=% admins=%'"),
        );
      }
      expect(
        RegExp(
          "if admins < 1 then raise exception 'SETUP FAIL",
        ).allMatches(probes).length,
        2,
      );
      expect(
        RegExp(
          r'not \(n\.id::text = any \(before_ids\)\)',
        ).allMatches(probes).length,
        2,
      );
      expect(probes, contains('distinct active test users'));
      expect(readme, contains('not vacuous'));
      expect(readme, contains('Old rows for the same pair cannot satisfy'));
    });
  });

  group('rollback, README, callers', () {
    test('rollback re-grants PUBLIC and service_role, no DROP', () {
      expect(
        rollback,
        contains(
          'GRANT EXECUTE ON FUNCTION public.notify_admins_of_block() TO PUBLIC;',
        ),
      );
      expect(
        rollback,
        contains(
          'GRANT EXECUTE ON FUNCTION public.notify_admins_of_block() TO service_role;',
        ),
      );
      expect(
        _strip(rollback),
        isNot(matches(RegExp(r'\bDROP\b', caseSensitive: false))),
      );
      expect(rollback, contains('AUTHORED, NOT RUN'));
    });

    test('README states Memphis, no DROP and the stop condition', () {
      expect(readme, contains('Memphis'));
      expect(readme, contains('itself an apply'));
      expect(readme, contains('STOP'));
      expect(readme, contains('never DROP'));
    });

    test('the caller map names only the trigger as a user, with evidence', () {
      expect(callers, contains('git grep'));
      expect(callers, contains('trg_notify_admins_of_block'));
      expect(
        callers,
        contains('only user of the function is `trg_notify_admins_of_block`'),
      );
      for (final s in ['lib', 'supabase/functions', 'workers']) {
        expect(callers, contains(s), reason: s);
      }
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
