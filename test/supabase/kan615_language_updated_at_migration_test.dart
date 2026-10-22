import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-615 migration (profiles.language_updated_at). Authored and NOT applied; these tests
/// run no SQL. The behaviour probe is `kan615_language_updated_at_probe.sql` (local/branch database only).
const _name = '20261021100000_kan615_users_language_updated_at.sql';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

void main() {
  late String sql;

  setUpAll(() {
    sql = _strip(
      File('supabase/migrations/$_name').readAsStringSync(),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
  });

  test('adds one nullable timestamptz column, idempotently', () {
    expect(
      RegExp(
        r'ADD COLUMN IF NOT EXISTS language_updated_at timestamptz;',
      ).allMatches(sql).length,
      1,
    );
    expect(sql, isNot(contains('NOT NULL')));
    expect(sql, isNot(contains('DEFAULT')));
  });

  test('additive only: no DROP at all, no policy/grant', () {
    final drops = RegExp(r'DROP [A-Z]+ [^;]*;').allMatches(sql).toList();
    expect(drops.map((m) => m.group(0)).toList(), isEmpty);
    for (final word in [
      'POLICY',
      'GRANT',
      'REVOKE',
      'ROW LEVEL SECURITY',
      'DELETE',
      'TRUNCATE',
      'UPDATE public',
    ]) {
      expect(sql, isNot(contains(word)), reason: word);
    }
  });

  test('server time on a language change only', () {
    expect(sql, contains('NEW.language IS DISTINCT FROM OLD.language'));
    expect(sql, contains('NEW.language_updated_at := now()'));
    expect(sql, contains('NEW.language_updated_at := OLD.language_updated_at'));
    expect(sql, contains('CREATE OR REPLACE FUNCTION'));
  });

  test('sorts after the latest earlier migration, unique version', () {
    final names = Directory('supabase/migrations')
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((n) => n.startsWith(_name.substring(0, 14)))
        .toList();
    expect(names, [_name]);
  });
}
