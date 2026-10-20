import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-580 migration (msg_receipts, msg_ack_receipt,
/// msg_receipt_summary), its probe pack and rollback. Authored and NOT
/// applied/run; these tests run no SQL.
const _dir = 'supabase/migrations';
const _name = '20261020150000_kan580_msg_receipts.sql';
const _packDir = 'supabase/tests/messaging';
const _ack = 'public.msg_ack_receipt(uuid, text, bigint, text)';
const _sum = 'public.msg_receipt_summary(uuid, bigint[], text)';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  late String sql;

  setUpAll(() {
    sql = _squash(_strip(File('$_dir/$_name').readAsStringSync()));
  });

  test('sorts after the latest migration; unique version', () {
    expect(_name.compareTo('20261020140000'), greaterThan(0));
    final same = Directory(_dir)
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((n) => n.startsWith(_name.substring(0, 14)));
    expect(same.length, 1);
  });

  test('no DROP, DELETE, TRUNCATE; data is written only by the ack upsert', () {
    final up = sql.toUpperCase();
    for (final bad in ['DROP ', 'DELETE ', 'TRUNCATE']) {
      expect(up.contains(bad), isFalse, reason: bad);
    }
    expect(RegExp('INSERT INTO').allMatches(up).length, 1);
    expect(up.contains('INSERT INTO PUBLIC.MSG_RECEIPTS'), isTrue);
  });

  test('table: watermarks, seen <= delivered, RLS on, closed to API roles', () {
    expect(sql, contains('CREATE TABLE IF NOT EXISTS public.msg_receipts'));
    expect(sql, contains('CHECK (seen_seq <= delivered_seq)'));
    expect(sql, contains('PRIMARY KEY (conversation_id, user_id)'));
    expect(sql, contains('ALTER TABLE public.msg_receipts ENABLE ROW LEVEL SECURITY'));
    expect(
      sql,
      contains('REVOKE ALL ON TABLE public.msg_receipts FROM PUBLIC, anon, authenticated'),
    );
    expect(sql.toUpperCase().contains('CREATE POLICY'), isFalse);
    // Identifiers and integers only: no body, text or preview column.
    final table = sql.substring(
      sql.indexOf('CREATE TABLE IF NOT EXISTS public.msg_receipts'),
      sql.indexOf('COMMENT ON TABLE public.msg_receipts'),
    );
    for (final bad in ['body', 'text ', 'preview', 'content']) {
      expect(table.contains(bad), isFalse, reason: bad);
    }
  });

  test('ack is monotonic, definer, identity from auth.uid(), membership gated', () {
    expect(sql, contains('CREATE OR REPLACE FUNCTION public.msg_ack_receipt('));
    expect(sql, contains('GREATEST(r.delivered_seq, EXCLUDED.delivered_seq)'));
    expect(sql, contains('GREATEST(r.seen_seq, EXCLUDED.seen_seq)'));
    expect(sql, contains('WHERE EXCLUDED.delivered_seq > r.delivered_seq OR EXCLUDED.seen_seq > r.seen_seq'));
    expect(sql, contains('v_uid uuid := auth.uid()'));
    expect(sql, contains('public.msg_evaluate(p_conversation_id, v_uid, p_access_mode)'));
    expect(sql, contains('LEAST(v_through, v_eval.left_at_seq)'));
    expect(sql, contains("p_state NOT IN ('delivered', 'seen')"));
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains('SET search_path = public, pg_temp'));
    // Never takes a user id from the caller.
    expect(sql.contains('p_user_id'), isFalse);
  });

  test('summary counts distinct recipients over the current member set', () {
    expect(sql, contains('CREATE OR REPLACE FUNCTION public.msg_receipt_summary('));
    expect(sql, contains('public.msg_authorize(p_conversation_id, p_access_mode)'));
    expect(sql, contains('SELECT DISTINCT m AS user_id FROM unnest(v_auth.member_user_ids)'));
    expect(sql, contains('WHERE m <> v_uid'));
    expect(sql, contains('public.user_blocks b WHERE b.blocker_user_id = m AND b.blocked_user_id = v_uid'));
    expect(sql, contains('cardinality(p_seqs) > 100'));
  });

  test('grants: nothing for anon or PUBLIC; authenticated only', () {
    for (final sig in [_ack, _sum]) {
      expect(sql, contains('REVOKE ALL ON FUNCTION $sig FROM PUBLIC, anon'));
      expect(sql, contains('GRANT EXECUTE ON FUNCTION $sig TO authenticated'));
    }
  });

  test('payload and logs: no realtime send, no notice of any value', () {
    expect(sql.contains('realtime.send'), isFalse);
    expect(sql.contains('RAISE'), isFalse);
  });

  test('probe pack: every block rolls back and is marked not run', () {
    final p = File('$_packDir/receipts_probes.sql').readAsStringSync();
    expect(p, contains('AUTHORED, NOT RUN'));
    final begins = RegExp(r'^BEGIN;', multiLine: true).allMatches(p).length;
    final rollbacks = RegExp(r'^ROLLBACK;', multiLine: true).allMatches(p).length;
    expect(begins, greaterThanOrEqualTo(10));
    expect(rollbacks, begins);
    expect(p.contains('COMMIT'), isFalse);
    for (final n in ['R1', 'R3', 'R4', 'R6', 'R8', 'R9', 'R11']) {
      expect(p, contains('-- $n '));
    }
  });

  test('rollback revokes only: no drop, no delete', () {
    final r = _squash(_strip(File('$_packDir/receipts_rollback.sql').readAsStringSync())).toUpperCase();
    expect(r, contains('REVOKE ALL ON FUNCTION PUBLIC.MSG_ACK_RECEIPT'));
    expect(r, contains('REVOKE ALL ON FUNCTION PUBLIC.MSG_RECEIPT_SUMMARY'));
    for (final bad in ['DROP ', 'DELETE ', 'TRUNCATE', 'ALTER TABLE']) {
      expect(r.contains(bad), isFalse, reason: bad);
    }
  });
}
