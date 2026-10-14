import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-527 migration and its probe pack. The migration is
/// authored and NOT applied. No test here asserts that it is the newest migration.
const _name = '20261013135000_revoke_public_anon_trigger_functions.sql';
const _path = 'supabase/migrations/$_name';
const _pack = 'supabase/tests/trigger_functions_acl';

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
  late List<String> revoked;
  late String doc;
  late String probes;
  late String rollback;
  late String readme;

  setUpAll(() {
    raw = File(_path).readAsStringSync();
    sql = _strip(raw);
    doc = File('$_pack/TRIGGER_FUNCTIONS.md').readAsStringSync();
    probes = File('$_pack/probes.sql').readAsStringSync();
    rollback = File('$_pack/rollback.sql').readAsStringSync();
    readme = File('$_pack/README.md').readAsStringSync();
    revoked = RegExp(
      r'^REVOKE EXECUTE ON FUNCTION (public\.\w+\(\)) FROM PUBLIC, anon;$',
      multiLine: true,
    ).allMatches(sql).map((m) => m.group(1)!).toList();
  });

  group('migration', () {
    test(
      'sorts after 20261013125000 and 20261013130000, not after 20261013140000',
      () {
        for (final other in ['20261013125000', '20261013130000']) {
          expect(_name.compareTo(other), greaterThan(0), reason: other);
        }
        // KAN-523's migration stays the newest and is not collided with.
        expect(_name.compareTo('20261013140000'), lessThan(0));
      },
    );

    test(
      'is only explicit REVOKE EXECUTE ... FROM PUBLIC, anon statements',
      () {
        final statements = sql
            .split(';')
            .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
            .where((s) => s.isNotEmpty)
            .toList();
        expect(statements.length, revoked.length);
        for (final s in statements) {
          expect(
            RegExp(
              r'^REVOKE EXECUTE ON FUNCTION public\.\w+\(\) FROM PUBLIC, anon$',
            ).hasMatch(s),
            isTrue,
            reason: s,
          );
        }
        expect(
          sql,
          isNot(matches(RegExp(r'\bGRANT\b|\bDROP\b|\bCREATE\b|\bALTER\b'))),
        );
      },
    );

    test('173 distinct functions, none excluded, matching the list doc', () {
      expect(revoked.length, 173);
      expect(revoked.toSet().length, 173);
      for (final f in revoked) {
        expect(doc, contains('`$f`'), reason: f);
      }
      expect(revoked, isNot(contains('public.notify_admins_of_block()')));
      expect(revoked.where((f) => f.contains('msg_')), isEmpty);
    });

    test('every listed function returns trigger in the repo', () {
      final all = [
        for (final e in Directory('supabase/migrations').listSync())
          if (e.path.endsWith('.sql')) File(e.path).readAsStringSync(),
      ].join('\n');
      for (final f in revoked) {
        final name = f.substring('public.'.length, f.length - 2);
        expect(
          RegExp(
            'CREATE (OR REPLACE )?FUNCTION "?public"?\\."?$name"?\\(\\)\\s+RETURNS "?trigger"?',
          ).hasMatch(all),
          isTrue,
          reason: '$f must be a trigger function',
        );
      }
    });

    test('says it was not applied', () {
      expect(raw, contains('AUTHORED, NOT APPLIED'));
    });
  });

  group('list doc', () {
    test('states source, count, ACL and caller evidence', () {
      expect(doc, contains('KAN-498'));
      expect(doc, contains('173'));
      expect(doc, contains('174'));
      expect(doc, contains('notify_admins_of_block'));
      expect(doc, contains('Granted via'));
      expect(doc, contains('Expected current proacl'));
      expect(
        RegExp(
          r'\{=X/postgres,postgres=X/postgres,service_role=X/postgres\}',
        ).allMatches(doc).length,
        greaterThanOrEqualTo(172),
      );
      expect(doc, contains('git grep'));
      for (final s in ['lib', 'supabase/functions', 'workers']) {
        expect(doc, contains(s), reason: s);
      }
      expect(
        RegExp(
          r'^\| \d+ \| `public\.\w+\(\)`',
          multiLine: true,
        ).allMatches(doc).length,
        173,
      );
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
          expect(depth, 0);
          depth = 1;
          blocks++;
          continue;
        }
        if (line == 'rollback;') {
          expect(depth, 1);
          depth = 0;
          continue;
        }
        expect(depth, 1, reason: 'outside a wrapper: $line');
      }
      expect(depth, 0);
      expect(blocks, 9);
      expect(
        probes,
        isNot(matches(RegExp(r'^\s*commit\s*;', multiLine: true))),
      );
    });

    test(
      'covers ACL, block trigger fixture, geo, posts and a second table',
      () {
        expect(probes, contains('A. PRE-APPLY'));
        expect(probes, contains('B. POST-APPLY'));
        expect(probes, contains('[READ-ONLY]'));
        expect(probes, contains('[WRITE-IN-TRANSACTION-ROLLBACK]'));
        for (final s in [
          "has_function_privilege('anon'",
          'a.grantee = 0',
          'set local role authenticated',
          'request.jwt.claims',
          'insert into public.app_admins',
          'rpc_block_user(b)',
          'moderation.user_blocked',
          'fn_sync_geo_fields',
          'profile_locations',
          'trg_posts_updated_at',
          'fn_likes_sync',
          'trg_posts_set_geo',
          'geo_location_id',
          'do not grant',
        ]) {
          expect(probes, contains(s), reason: s);
        }
      },
    );
  });

  group('rollback and README', () {
    test('rollback re-grants PUBLIC on exactly the listed functions', () {
      final granted = RegExp(
        r'^GRANT EXECUTE ON FUNCTION (public\.\w+\(\)) TO PUBLIC;$',
        multiLine: true,
      ).allMatches(rollback).map((m) => m.group(1)).toList();
      expect(granted, revoked);
      expect(_strip(rollback), isNot(matches(RegExp(r'\bDROP\b'))));
      expect(
        rollback,
        contains(
          'GRANT EXECUTE ON FUNCTION public.trg_welcome_notify() TO anon;',
        ),
      );
      expect(rollback, contains('AUTHORED, NOT RUN'));
    });

    test('README states Memphis, rollback is an apply, and the stop rule', () {
      expect(readme, contains('Memphis'));
      expect(readme, contains('itself an apply'));
      expect(readme, contains('do not grant'));
      expect(readme, contains('never DROP'));
    });
  });

  test('no secret-like string in any authored file', () {
    final all = [raw, doc, probes, rollback, readme].join('\n');
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
