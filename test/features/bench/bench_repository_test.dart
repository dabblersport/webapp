import 'dart:convert';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/bench/data/bench_repository.dart';
import 'package:dabbler/features/bench/data/bench_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';

void main() {
  late List<http.Request> seen;

  BenchRepository build(http.Response Function(http.Request) handler) {
    seen = [];
    return BenchRepository(
      buildTestSupabaseClient((r) async {
        seen.add(r);
        return handler(r);
      }),
    );
  }

  Map<String, dynamic> body() =>
      jsonDecode(seen.single.body) as Map<String, dynamic>;

  group('load', () {
    test('maps a benched user_status row', () async {
      final repo = build(
        (r) => jsonListResponse([
          {
            'is_benched': true,
            'benched_at': '2026-10-01T08:00:00Z',
            'reason': 'Exams',
            'bench_until': '2026-11-01T20:59:59Z',
            'hide_in_feed': true,
            'hide_in_search': false,
            'block_friend_requests': true,
            'suppress_social_notifications': true,
            'updated_at': '2026-10-01T08:00:00Z',
          },
        ], request: r),
      );

      final result = await repo.load();

      expect(seen.single.url.path, '/rest/v1/user_status');
      final BenchStatus status = (result as Ok<BenchStatus, dynamic>).value;
      expect(status.isBenched, isTrue);
      expect(status.reason, 'Exams');
      expect(status.benchedAt, DateTime.utc(2026, 10, 1, 8));
      expect(status.benchUntil, DateTime.utc(2026, 11, 1, 20, 59, 59));
      expect(status.hideInFeed, isTrue);
      expect(status.hideInSearch, isFalse);
      expect(status.blockFriendRequests, isTrue);
      expect(status.suppressSocialNotifications, isTrue);
    });

    test('no row maps to not benched with the default flags', () async {
      final repo = build((r) => jsonListResponse(const [], request: r));

      final result = await repo.load();

      final BenchStatus status = (result as Ok<BenchStatus, dynamic>).value;
      expect(status.isBenched, isFalse);
      expect(status.benchUntil, isNull);
      expect(status.reason, isNull);
      expect(status.hideInFeed, isTrue);
      expect(status.hideInSearch, isTrue);
      expect(status.blockFriendRequests, isTrue);
      expect(status.suppressSocialNotifications, isFalse);
    });
  });

  group('save', () {
    test('sends rpc_toggle_bench with the exact params map', () async {
      final repo = build((r) => jsonListResponse(const [], request: r));
      final until = DateTime(2026, 11, 1);

      final result = await repo.save(
        BenchSettings(
          reason: '  Exams  ',
          benchUntil: until,
          hideInFeed: true,
          hideInSearch: false,
          blockFriendRequests: true,
          suppressSocialNotifications: false,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(seen.single.method, 'POST');
      expect(seen.single.url.path, '/rest/v1/rpc/rpc_toggle_bench');
      expect(body(), {
        'p_is_benched': true,
        'p_reason': 'Exams',
        'p_bench_until': DateTime(
          2026,
          11,
          1,
          23,
          59,
          59,
        ).toUtc().toIso8601String(),
        'p_hide_in_feed': true,
        'p_hide_in_search': false,
        'p_block_friend_requests': true,
        'p_suppress_social_notifications': false,
      });
    });

    test('defaults send feed, search, friends on and notifications off, '
        'with null reason and no end', () async {
      final repo = build((r) => jsonListResponse(const [], request: r));

      await repo.save(const BenchSettings(reason: '   '));

      expect(body(), {
        'p_is_benched': true,
        'p_reason': null,
        'p_bench_until': null,
        'p_hide_in_feed': true,
        'p_hide_in_search': true,
        'p_block_friend_requests': true,
        'p_suppress_social_notifications': false,
      });
    });

    test('not_authenticated maps to a Failure and does not throw', () async {
      final repo = build(
        (r) => postgrestErrorResponse(
          message: 'not_authenticated',
          code: 'P0001',
          request: r,
        ),
      );

      final result = await repo.save(const BenchSettings());

      expect(result.isFailure, isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('not_authenticated')),
        (_) => fail('expected a Failure'),
      );
    });
  });

  group('end', () {
    test('calls rpc_end_bench', () async {
      final repo = build((r) => emptyOkResponse(request: r));

      final result = await repo.end();

      expect(result.isSuccess, isTrue);
      expect(seen.single.method, 'POST');
      expect(seen.single.url.path, '/rest/v1/rpc/rpc_end_bench');
    });

    test('not_authenticated maps to a Failure and does not throw', () async {
      final repo = build(
        (r) => postgrestErrorResponse(
          message: 'not_authenticated',
          code: 'P0001',
          request: r,
        ),
      );

      final result = await repo.end();

      expect(result.isFailure, isTrue);
    });
  });
}
