import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-524 migration and probe pack. The migration is
/// authored and NOT applied; these tests pin its shape, its order, the absence
/// of any DROP, and the probes. They run no SQL.
const _name = '20261013150000_create_post_keeps_place.sql';
const _dir = 'supabase/migrations';
const _pack = 'supabase/tests/create_post_place';
const _baseline = 'supabase/migrations/20260829080500_baseline_schema.sql';

const _sig15 =
    'text, text, text, text, text, text, jsonb, text[], uuid, uuid, uuid, uuid[], uuid[], uuid[], uuid[]';
const _sig20 = '$_sig15, uuid, text, double precision, double precision, uuid';

const _oldParams = <String>[
  'p_kind',
  'p_visibility',
  'p_post_type',
  'p_origin_type',
  'p_body',
  'p_sport',
  'p_media',
  'p_tags',
  'p_game_id',
  'p_location_tag_id',
  'p_primary_vibe_id',
  'p_vibe_ids',
  'p_circle_ids',
  'p_squad_ids',
  'p_mention_profile_ids',
];
const _newParams = <String>[
  'p_venue_id',
  'p_location_name',
  'p_geo_lat',
  'p_geo_lng',
  'p_area_id',
];

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

List<String> _dropProblems(String sqlWithoutComments) => RegExp(
  r'\bDROP\b',
  caseSensitive: false,
).allMatches(sqlWithoutComments).map((m) => 'DROP found').toList();

List<String> _orderProblems(String name, List<String> mustPrecede) => [
  for (final o in mustPrecede)
    if (name.compareTo(o) <= 0) '$name does not sort after $o',
];

List<({String id, String marker, String body})> _blocks(String probes) {
  final lines = probes.split('\n');
  final out = <({String id, String marker, String body})>[];
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
    out.add((
      id: m.group(1)!,
      marker: m.group(2)!,
      body: lines.sublist(i + 1, j + 1).join('\n'),
    ));
  }
  return out;
}

void main() {
  late String raw;
  late String sql;
  late String probes;
  late String rollbackRaw;
  late String rollback;
  late String readme;
  late String callers;

  setUpAll(() {
    raw = File('$_dir/$_name').readAsStringSync();
    sql = _strip(raw);
    probes = File('$_pack/probes.sql').readAsStringSync();
    rollbackRaw = File('$_pack/rollback.sql').readAsStringSync();
    rollback = _strip(rollbackRaw);
    readme = File('$_pack/README.md').readAsStringSync();
    callers = File('$_pack/CALLERS.md').readAsStringSync();
  });

  group('order', () {
    test('sorts after KAN-497 and KAN-499 (20261013120000); not required to '
        'stay the newest migration', () {
      expect(
        _orderProblems(_name, [
          '20261013100000_',
          '20261013110000_',
          '20261013120000_',
        ]),
        isEmpty,
      );
    });

    test('the order check fails when the order is reversed', () {
      expect(
        _orderProblems('20261013110500_x.sql', ['20261013120000_']),
        isNotEmpty,
      );
    });

    test('exactly one new migration for this ticket', () {
      final mine = Directory(_dir)
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .where((n) => n.contains('create_post_keeps_place'));
      expect(mine.toList(), [_name]);
    });
  });

  group('no DROP', () {
    test('neither the migration nor the rollback contains a DROP', () {
      expect(_dropProblems(sql), isEmpty);
      expect(_dropProblems(rollback), isEmpty);
    });

    test('the DROP check fails on a DROP', () {
      expect(_dropProblems('drop function public.x();'), isNotEmpty);
      expect(_dropProblems('ALTER FUNCTION a() RENAME TO b;'), isEmpty);
    });
  });

  group('migration shape', () {
    String s() => _squash(sql);

    test('renames the 15-argument function to create_post_legacy_v1', () {
      expect(
        s(),
        contains(
          'ALTER FUNCTION public.create_post($_sig15) RENAME TO create_post_legacy_v1;',
        ),
      );
    });

    test('revokes the legacy function from PUBLIC, anon, authenticated', () {
      expect(
        s(),
        contains(
          'REVOKE ALL ON FUNCTION public.create_post_legacy_v1($_sig15) '
          'FROM PUBLIC, anon, authenticated;',
        ),
      );
    });

    test('the new create_post has the 15 old parameters first, in order, '
        'then the five defaulted new ones', () {
      final head = RegExp(
        r'CREATE FUNCTION public\.create_post\((.*?)\) RETURNS jsonb',
        dotAll: true,
      ).firstMatch(sql)!.group(1)!;
      final names = RegExp(
        r'\b(p_\w+)\s+[a-z]',
      ).allMatches(head).map((m) => m.group(1)!).toList();
      expect(names, [..._oldParams, ..._newParams]);
      // the five new ones all default to NULL
      for (final p in _newParams) {
        expect(
          RegExp('$p \\w+(?: \\w+)? DEFAULT NULL').hasMatch(head),
          isTrue,
          reason: p,
        );
      }
      // the old parameters keep the baseline defaults
      final baseline = File(_baseline).readAsStringSync();
      final bHead = RegExp(
        r'CREATE OR REPLACE FUNCTION "public"\."create_post"\((.*?)\) RETURNS',
        dotAll: true,
      ).firstMatch(baseline)!.group(1)!;
      final bNames = RegExp(
        r'"(p_\w+)"',
      ).allMatches(bHead).map((m) => m.group(1)!).toList();
      expect(bNames, _oldParams);
      expect(
        RegExp(r'DEFAULT').allMatches(bHead).length,
        RegExp(r'DEFAULT').allMatches(head).length - _newParams.length,
      );
    });

    test('SECURITY DEFINER, search_path public, pg_temp, owner postgres', () {
      expect(s(), contains('LANGUAGE plpgsql SECURITY DEFINER'));
      expect(s(), contains("SET search_path TO 'public', 'pg_temp'"));
      expect(s(), contains('OWNER TO postgres;'));
    });

    test('the INSERT stores the five new columns from the five parameters', () {
      final q = s();
      expect(
        q,
        contains(
          'venue_id, location_name, geo_lat, geo_lng, area_id ) VALUES (',
        ),
      );
      expect(
        q,
        contains(
          'p_venue_id, p_location_name, p_geo_lat, p_geo_lng, p_area_id ) RETURNING id INTO v_post_id;',
        ),
      );
    });

    test('the body is the baseline body except the INSERT and the guard', () {
      final baseline = File(_baseline).readAsStringSync();
      String bodyOf(String text, String open) {
        final a = text.indexOf('DECLARE', text.indexOf(open));
        return text.substring(a, text.indexOf(r'$$;', a));
      }

      final b = bodyOf(
        baseline,
        'CREATE OR REPLACE FUNCTION "public"."create_post"(',
      );
      final n = bodyOf(raw, 'CREATE FUNCTION public.create_post(');
      final expected = b
          .replaceFirst(
            'vibe_id, persona_type_snapshot\n  ) VALUES (',
            'vibe_id, persona_type_snapshot,\n    venue_id, location_name, geo_lat, geo_lng, area_id\n  ) VALUES (',
          )
          .replaceFirst(
            'p_primary_vibe_id, v_profile.persona_type\n  ) RETURNING',
            'p_primary_vibe_id, v_profile.persona_type,\n    p_venue_id, p_location_name, p_geo_lat, p_geo_lng, p_area_id\n  ) RETURNING',
          );
      final guard = RegExp(
        r"-- Half a point is never stored \(KAN-524\)\.\s*IF \(p_geo_lat IS NULL\) <> \(p_geo_lng IS NULL\) THEN\s*RAISE EXCEPTION USING errcode = 'P0001', message = 'geo_incomplete';\s*END IF;",
      );
      expect(guard.hasMatch(n), isTrue);
      expect(_squash(n.replaceFirst(guard, '')), _squash(expected));
      // the DEBUG circle exception and the junction inserts are kept verbatim
      for (final keep in [
        "RAISE EXCEPTION 'DEBUG: circle insert failed.",
        'INSERT INTO public.post_circles (post_id, circle_id)',
        'INSERT INTO public.post_squads (post_id, squad_id)',
        'INSERT INTO public.post_mentions (post_id, mentioned_profile_id)',
        "IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;",
      ]) {
        expect(_squash(n), contains(_squash(keep)), reason: keep);
        expect(_squash(b), contains(_squash(keep)), reason: 'baseline $keep');
      }
    });

    test('geo_incomplete guard rejects half a point with errcode P0001', () {
      expect(
        s(),
        contains('IF (p_geo_lat IS NULL) <> (p_geo_lng IS NULL) THEN'),
      );
      expect(
        s(),
        contains(
          "RAISE EXCEPTION USING errcode = 'P0001', message = 'geo_incomplete';",
        ),
      );
      // the guard runs before the INSERT
      expect(
        sql.indexOf('geo_incomplete'),
        lessThan(sql.indexOf('INSERT INTO public.posts')),
      );
    });

    test('restores the baseline ACL on the new function', () {
      expect(
        s(),
        contains(
          'REVOKE ALL ON FUNCTION public.create_post($_sig20) FROM PUBLIC, anon;',
        ),
      );
      expect(
        s(),
        contains(
          'GRANT EXECUTE ON FUNCTION public.create_post($_sig20) TO authenticated, service_role;',
        ),
      );
      expect(
        RegExp(r'\bTO\s+anon\b', caseSensitive: false).hasMatch(sql),
        isFalse,
      );
    });

    test('touches no other function, table or trigger', () {
      expect(
        RegExp(
          r'CREATE\s+(OR\s+REPLACE\s+)?FUNCTION',
          caseSensitive: false,
        ).allMatches(sql).length,
        1,
      );
      for (final bad in [
        RegExp(r'ALTER\s+TABLE', caseSensitive: false),
        RegExp(r'CREATE\s+(OR\s+REPLACE\s+)?TRIGGER', caseSensitive: false),
        RegExp(r'trgfn_posts_set_geo', caseSensitive: false),
        RegExp(r'TRUNCATE', caseSensitive: false),
        RegExp(r'\bUPDATE\s+public\.', caseSensitive: false),
        RegExp(r'\bDELETE\s+FROM\b', caseSensitive: false),
      ]) {
        expect(bad.hasMatch(sql), isFalse, reason: bad.pattern);
      }
    });

    test('statement order: rename, revoke legacy, create, owner, acl', () {
      final idx = [
        sql.indexOf('RENAME TO create_post_legacy_v1'),
        sql.indexOf('FROM PUBLIC, anon, authenticated'),
        sql.indexOf('CREATE FUNCTION public.create_post('),
        sql.indexOf('OWNER TO postgres'),
        sql.indexOf('GRANT EXECUTE'),
      ];
      for (var i = 0; i < idx.length; i++) {
        expect(idx[i], greaterThanOrEqualTo(0));
        if (i > 0) expect(idx[i], greaterThan(idx[i - 1]));
      }
    });

    test('header says AUTHORED, NOT APPLIED', () {
      expect(raw, contains('AUTHORED, NOT APPLIED'));
    });
  });

  group('callers', () {
    test(
      'CALLERS.md lists every caller with its kind and says all are named',
      () {
        for (final kind in [
          'app',
          'edge fn',
          'trigger / view / policy',
          'function',
          'migration-only',
        ]) {
          expect(callers, contains('| $kind |'), reason: kind);
        }
        expect(callers, contains('post_repository_impl.dart:882'));
        expect(callers, contains(':984'));
        expect(callers, contains(':1107'));
        expect(callers, contains('named parameters only'));
        expect(callers, contains('git grep'));
      },
    );

    test(
      'the repo really has only those three calls, all with named params',
      () {
        final src = File(
          'lib/data/repositories/post_repository_impl.dart',
        ).readAsStringSync();
        final calls = RegExp(
          r"rpc\(\s*'create_post',\s*params:\s*\{",
        ).allMatches(src).length;
        expect(calls, 3);
        expect(RegExp(r"rpc\(\s*'create_post'\s*\)").hasMatch(src), isFalse);
      },
    );
  });

  group('probes', () {
    test('says AUTHORED, NOT RUN', () {
      expect(probes, contains('AUTHORED, NOT RUN'));
      expect(readme, contains('AUTHORED, NOT APPLIED, NOT RUN'));
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
      expect(blocks.length, greaterThanOrEqualTo(10));
      for (final b in blocks) {
        final body = _strip(b.body);
        expect(body.trim().endsWith('rollback;'), isTrue, reason: b.id);
        if (b.marker == 'READ-ONLY') {
          expect(body, contains('begin read only;'), reason: b.id);
          expect(
            RegExp(
              r'\b(insert|update|delete|truncate|alter|create)\b|create_post\(',
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
      var rest = _strip(probes);
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

    test('covers every required probe', () {
      expect(probes, contains('set local role authenticated'));
      expect(probes, contains('set local role anon'));
      expect(probes, contains('request.jwt.claims'));
      // old-argument call still returns a post
      expect(probes, contains("p_body => 'kan524 old args'"));
      // venue stored
      expect(probes, contains('p_venue_id => v'));
      expect(probes, contains('row_.venue_id is distinct from v'));
      // lat/lng, name, area stored
      expect(probes, contains('p_geo_lat => 25.2048'));
      expect(probes, contains('p_area_id => ar'));
      expect(probes, contains("'KAN-524 point label'"));
      // half a point
      expect(probes, contains('P0001:geo_incomplete'));
      // acl
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
      expect(probes, contains('create_post_legacy_v1'));
      // post_circles row
      expect(
        probes,
        contains(
          'from public.post_circles where post_id = p and circle_id = c',
        ),
      );
    });
  });

  group('rollback and docs', () {
    test('renames the new function away, restores the legacy one and the ACL', () {
      final r = _squash(rollback);
      final a = r.indexOf('RENAME TO create_post_v2_rolledback');
      final b = r.indexOf('RENAME TO create_post;');
      expect(a, greaterThanOrEqualTo(0));
      expect(b, greaterThan(a));
      expect(
        r,
        contains(
          'ALTER FUNCTION public.create_post($_sig20) RENAME TO create_post_v2_rolledback;',
        ),
      );
      expect(
        r,
        contains(
          'ALTER FUNCTION public.create_post_legacy_v1($_sig15) RENAME TO create_post;',
        ),
      );
      expect(
        r,
        contains(
          'REVOKE ALL ON FUNCTION public.create_post($_sig15) FROM PUBLIC, anon;',
        ),
      );
      expect(
        r,
        contains(
          'GRANT EXECUTE ON FUNCTION public.create_post($_sig15) TO authenticated, service_role;',
        ),
      );
    });

    test('README states the rollback order, that it needs Memphis, and the '
        'trigger facts', () {
      expect(rollbackRaw, contains('AUTHORED, NOT RUN'));
      expect(readme, contains('Rollback is itself an apply and needs Memphis'));
      expect(readme, contains('trg_posts_set_geo'));
      expect(readme, contains('OVERWRITTEN'));
      expect(readme, contains('supplied `area_id`'));
      expect(readme, contains('never rejects a supplied `area_id`'));
      expect(readme, contains('wtncuzcskpigqpmnxwws'));
    });

    test('no secret or other project reference in any file of this ticket', () {
      final secretLike = RegExp(
        r'(eyJ[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9]{20,}|sk_(live|test)_|postgres(ql)?://\S+:\S+@|(?=[A-Za-z0-9]*\d)(?=[A-Za-z0-9]*[A-Z])(?=[A-Za-z0-9]*[a-z])[A-Za-z0-9]{40,})',
      );
      for (final f in [raw, probes, rollbackRaw, readme, callers]) {
        expect(secretLike.hasMatch(f), isFalse);
        final refs = RegExp(
          r'([a-z]{20})\.supabase\.co',
        ).allMatches(f).map((m) => m.group(1)).toSet();
        expect(refs.difference({'wtncuzcskpigqpmnxwws'}), isEmpty);
      }
    });
  });
}
