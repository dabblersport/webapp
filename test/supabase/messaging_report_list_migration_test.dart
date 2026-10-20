import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-551 (Messaging launch M1a) report-list migration and probe pack.
/// The migration is authored and NOT applied; these tests pin its shape. They run no SQL.
const _dir = 'supabase/migrations';
const _packDir = 'supabase/tests/messaging';
const _file = '20261013161100_kan551_msg_report_list.sql';
const _cutoff = '20261013161000_kan555_msg_my_conversations_dm.sql';
const _sig = 'public.msg_list_message_reports(integer)';

String _stripComments(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

bool _hasDrop(String text) =>
    RegExp(r'\bdrop\b', caseSensitive: false).hasMatch(text);

void main() {
  late String raw;
  late String sql;
  late String probes;
  late String rollback;

  setUpAll(() {
    raw = File('$_dir/$_file').readAsStringSync();
    sql = _squash(_stripComments(raw));
    probes = File('$_packDir/msg_report_list_probes.sql').readAsStringSync();
    rollback = File(
      '$_packDir/msg_report_list_rollback.sql',
    ).readAsStringSync();
  });

  test('one msg_report_list migration, later than the fixed cut-off', () {
    final present = Directory(_dir)
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((n) => n.contains('msg_report_list'))
        .toList();
    expect(present, [_file]);
    expect(_file.compareTo(_cutoff), greaterThan(0));
  });

  test('signature and the six columns, nothing else returned', () {
    expect(
      sql,
      contains(
        'CREATE OR REPLACE FUNCTION public.msg_list_message_reports(p_limit integer DEFAULT 50)',
      ),
    );
    expect(
      sql,
      contains(
        'RETURNS TABLE ( report_id uuid, reason public.report_reason, '
        'created_at timestamptz, status public.report_status, '
        'target_message_id uuid, conversation_id uuid )',
      ),
    );
  });

  test('admin gate, definer, pinned search_path', () {
    expect(sql, contains('IF NOT public.is_admin() THEN'));
    expect(
      sql,
      contains(
        "RAISE EXCEPTION USING ERRCODE = 'P0001', MESSAGE = 'forbidden'",
      ),
    );
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains('SET search_path = public, pg_temp'));
    expect(raw, contains('admin_resolve_report'));
  });

  test('message reports only, newest first, clamped', () {
    expect(sql, contains("WHERE r.target_type = 'message'::public.mod_target"));
    expect(sql, contains('ORDER BY r.created_at DESC, r.id DESC'));
    expect(
      sql,
      contains('LIMIT least(greatest(coalesce(p_limit, 50), 1), 100)'),
    );
  });

  test('no text-bearing columns read', () {
    for (final w in [
      'details',
      'content_snapshot',
      'username',
      'display_name',
      'resolution',
      'body',
    ]) {
      expect(sql.contains(w), isFalse, reason: w);
    }
    expect(sql, isNot(contains('CREATE TABLE')));
    expect(sql, isNot(matches(RegExp('ADD COLUMN', caseSensitive: false))));
  });

  test('grants: revoke PUBLIC and anon, EXECUTE to authenticated only', () {
    expect(sql, contains('REVOKE ALL ON FUNCTION $_sig FROM PUBLIC, anon;'));
    final grants = RegExp(
      r'GRANT EXECUTE[^;]*;',
    ).allMatches(sql).map((m) => m.group(0)).toList();
    expect(grants, ['GRANT EXECUTE ON FUNCTION $_sig TO authenticated;']);
  });

  test('notify function untouched', () {
    expect(sql, isNot(contains('notify_admins_of_report')));
    expect(raw, contains('baseline_schema.sql:9323'));
  });

  test('no destructive keyword in any new file', () {
    expect(_hasDrop(raw), isFalse);
    expect(_hasDrop(probes), isFalse);
    expect(_hasDrop(rollback), isFalse);
  });

  test('probes AUTHORED, NOT RUN, each block BEGIN..ROLLBACK', () {
    expect(probes, contains('AUTHORED, NOT RUN'));
    final body = _stripComments(probes).toLowerCase();
    final begins = RegExp(r'^begin;', multiLine: true).allMatches(body).length;
    final rollbacks = RegExp(
      r'^rollback;',
      multiLine: true,
    ).allMatches(body).length;
    expect(begins, greaterThanOrEqualTo(7));
    expect(rollbacks, begins);
    expect(body, isNot(contains('commit')));
    expect(
      body,
      isNot(matches(RegExp(r'insert into public\.(app_admins|role_grants)'))),
    );
  });

  test('rollback only revokes and says it needs approval', () {
    final body = _squash(_stripComments(rollback));
    expect(
      body,
      contains('REVOKE EXECUTE ON FUNCTION $_sig FROM authenticated;'),
    );
    expect(body, isNot(contains('CREATE')));
    expect(rollback, contains('needs explicit approval'));
  });
}
