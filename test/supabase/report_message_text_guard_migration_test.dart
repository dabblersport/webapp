import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks over the KAN-530 migration: no free text in a message report. The migration is
/// authored and NOT applied; these tests pin its text. They run no SQL. They never assert that it
/// is the newest migration, only that it sorts after a fixed earlier cut-off.
const _dir = 'supabase/migrations';
const _name = '20261013160400_kan530_msg_no_free_text_in_message_reports.sql';
const _baseline = '$_dir/20260829080500_baseline_schema.sql';
const _pack = 'supabase/tests/messaging';

String _strip(String sql) => sql
    .split('\n')
    .map((l) {
      final i = l.indexOf('--');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

bool _hasDrop(String s) =>
    RegExp(r'\bdrop\b', caseSensitive: false).hasMatch(s);

void main() {
  late String raw;
  late String sql;
  late String baseline;

  setUpAll(() {
    raw = File('$_dir/$_name').readAsStringSync();
    sql = _squash(_strip(raw));
    baseline = File(_baseline).readAsStringSync();
  });

  test('exists and sorts after the fixed cut-off 20261013150300', () {
    expect(File('$_dir/$_name').existsSync(), isTrue);
    expect(_name.compareTo('20261013150300'), greaterThan(0));
  });

  test('redefines report_content with the baseline signature and attributes', () {
    expect(
      sql,
      contains('CREATE OR REPLACE FUNCTION "public"."report_content"('),
    );
    expect(
      sql,
      contains(
        '("p_target_type" "public"."mod_target", "p_target_id" "uuid", "p_reason" "public"."report_reason", "p_details" "text" DEFAULT NULL::"text", "p_snapshot" "jsonb" DEFAULT NULL::"jsonb") RETURNS "public"."moderation_reports" LANGUAGE "plpgsql" SECURITY DEFINER SET "search_path" TO \'public\'',
      ),
    );
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains('SET "search_path" TO \'public\''));
    expect(sql, isNot(contains('GRANT')));
    expect(sql, isNot(contains('REVOKE')));
    expect(
      sql,
      contains(
        "raise exception using errcode = 'P0001', message = 'auth_required'",
      ),
    );
  });

  test(
    'pins details to NULL for a message, in the insert and in the audit payload',
    () {
      const pin =
          "case when p_target_type = 'message' then null else p_details end";
      expect(RegExp(RegExp.escape(pin)).allMatches(sql).length, 2);
      expect(sql, contains('p_snapshot )'));
      expect(
        sql,
        contains("jsonb_build_object('reason', p_reason, 'details', $pin)"),
      );
    },
  );

  test('only the details value differs from the baseline function body', () {
    String body(String full) {
      final s = _strip(
        full,
      ); // the rollback in the header comment is not the live body
      final a = s.indexOf(
        'CREATE OR REPLACE FUNCTION "public"."report_content"(',
      );
      return _squash(s.substring(a, s.indexOf(r'$$;', a) + 3));
    }

    const pin =
        "case when p_target_type = 'message' then null else p_details end";
    final expected = body(baseline)
        .replaceFirst(
          'me, p_target_type, p_target_id, p_reason, p_details, p_snapshot',
          'me, p_target_type, p_target_id, p_reason, $pin, p_snapshot',
        )
        .replaceFirst("'details', p_details", "'details', $pin");
    expect(body(raw), expected);
  });

  test('adds exactly one NOT VALID CHECK and touches no policy', () {
    expect(RegExp(r'ADD CONSTRAINT').allMatches(sql).length, 1);
    expect(
      sql,
      contains(
        "ALTER TABLE public.moderation_reports ADD CONSTRAINT moderation_reports_message_no_details_check CHECK (target_type <> 'message' OR details IS NULL) NOT VALID;",
      ),
    );
    expect(sql, isNot(contains('POLICY')));
    expect(sql, isNot(contains('mr_self_insert')));
  });

  test('the forward migration contains no DROP', () {
    expect(
      _hasDrop(_strip(raw)),
      isFalse,
    ); // the rollback in the header comment is the only mention
  });

  test(
    'the baseline migration is unchanged (still pass-through, still mr_self_insert)',
    () {
      final b = _squash(baseline);
      expect(
        b,
        contains(
          'reporter_user_id, target_type, target_id, reason, details, content_snapshot ) values ( me, p_target_type, p_target_id, p_reason, p_details, p_snapshot )',
        ),
      );
      expect(
        b,
        contains(
          'CREATE POLICY "mr_self_insert" ON "public"."moderation_reports" FOR INSERT',
        ),
      );
      expect(
        baseline,
        isNot(contains('moderation_reports_message_no_details_check')),
      );
    },
  );

  test(
    'rollback (header comment) restores the baseline body, removes only the new CHECK',
    () {
      final lines = raw
          .split('\n')
          .where((l) => l.startsWith('--   '))
          .map((l) => l.substring(5))
          .join('\n');
      String fn(String t) {
        final a = t.indexOf(
          'CREATE OR REPLACE FUNCTION "public"."report_content"(',
        );
        return _squash(t.substring(a, t.indexOf(r'$$;', a) + 3));
      }

      expect(fn(lines), fn(baseline));
      final drops = RegExp(
        r'\bdrop\b[^;]*;',
        caseSensitive: false,
      ).allMatches(lines).map((m) => _squash(m.group(0)!)).toList();
      expect(drops, [
        'drop constraint if exists moderation_reports_message_no_details_check;',
      ]);
      // rollback.sql is untouched by this ticket and stays free of DROP
      expect(_hasDrop(File('$_pack/rollback.sql').readAsStringSync()), isFalse);
    },
  );

  test(
    'probes P11-P15 are marked, wrapped in begin/rollback and assert the five cases',
    () {
      final p = File('$_pack/probes.sql').readAsStringSync();
      for (final tag in ['P11', 'P12', 'P13', 'P14', 'P15']) {
        final a = p.indexOf('-- KAN-530 probe $tag [');
        expect(a, greaterThanOrEqualTo(0), reason: tag);
        final end = p.indexOf('\nROLLBACK;', a);
        final block = p.substring(a, end + 10);
        expect(block, contains('AUTHORED, NOT RUN'), reason: tag);
        expect(block, contains('\nBEGIN;'), reason: tag);
        expect(block, isNot(contains('commit;')), reason: tag);
      }
      for (final c in [
        'pass_message_details_pinned_null',
        'pass_post_details_unchanged',
        'pass_direct_message_with_details_refused',
        'pass_direct_post_with_details_ok',
        'pass_direct_message_null_details_ok',
      ]) {
        expect(p, contains(c), reason: c);
      }
      expect(_hasDrop(p), isFalse);
    },
  );

  test('README has a section for this ticket', () {
    final r = File('$_pack/README.md').readAsStringSync();
    expect(r, contains('## KAN-530'));
  });
}
