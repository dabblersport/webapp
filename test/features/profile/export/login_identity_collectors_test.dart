import 'dart:async';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/profile/services/export/login_identity_collectors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An awaitable stand-in for the builder `SupabaseClient.rpc` returns.
/// Awaiting a [PostgrestFilterBuilder] only calls [then], so that is all
/// the collectors need.
class _FakeRpcBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  _FakeRpcBuilder(this._future);

  final Future<T> _future;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => _future.then(onValue, onError: onError);
}

class _FakeClient extends Fake implements SupabaseClient {
  _FakeClient({this.rows, this.error});

  final List<Map<String, dynamic>>? rows;
  final Object? error;

  String? calledFn;
  Map<String, dynamic>? calledParams;

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get = false,
  }) {
    calledFn = fn;
    calledParams = params;
    if (error != null) throw error!;
    return _FakeRpcBuilder<T>(Future<T>.value(rows as T));
  }
}

const _rowKeys = {'id', 'created_at'};

List<Map<String, dynamic>> _twoRows() => [
  {'id': 'a', 'created_at': '2026-11-01T00:00:00Z'},
  {'id': 'b', 'created_at': '2026-11-02T00:00:00Z'},
];

void main() {
  group('collectLoginHistory', () {
    test(
      'C3: two rows -> two maps with row keys plus exactly the original added keys',
      () async {
        final client = _FakeClient(rows: _twoRows());

        final result = await collectLoginHistory(client, 'user-1');

        expect(client.calledFn, SupabaseConfig.getMyLoginHistoryFn);
        expect(client.calledParams!['p_limit'], 1000);
        final since = DateTime.parse(client.calledParams!['p_since'] as String);
        final days = DateTime.now().difference(since).inDays;
        expect(days, inInclusiveRange(179, 180));

        expect(result, hasLength(2));
        for (final map in result!) {
          expect(map.keys.toSet(), {
            ..._rowKeys,
            'data_source',
            'purpose',
            'legal_basis',
            'retention_period',
          });
          expect(
            map['data_source'],
            'auth.audit_log_entries (via get_my_login_history)',
          );
          expect(map['purpose'], 'Security monitoring and fraud prevention');
          expect(map['legal_basis'], 'Legitimate interest (security)');
          expect(map['retention_period'], '6 months');
        }
        expect(result[0]['id'], 'a');
        expect(result[1]['id'], 'b');
      },
    );

    test('C4: rpc throws -> returns null and does not throw', () async {
      final client = _FakeClient(error: Exception('boom'));

      final result = await collectLoginHistory(client, 'user-1');

      expect(result, isNull);
    });
  });

  group('collectLinkedIdentities', () {
    test(
      'C3: two rows -> two maps with row keys plus exactly the original added keys',
      () async {
        final client = _FakeClient(rows: _twoRows());

        final result = await collectLinkedIdentities(client, 'user-1');

        expect(client.calledFn, SupabaseConfig.getMyLinkedIdentitiesFn);
        expect(client.calledParams, isNull);

        expect(result, hasLength(2));
        for (final map in result!) {
          expect(map.keys.toSet(), {
            ..._rowKeys,
            'data_source',
            'purpose',
            'legal_basis',
            'note',
          });
          expect(
            map['data_source'],
            'auth.identities (via get_my_linked_identities)',
          );
          expect(
            map['purpose'],
            'Sign-in method management and account security',
          );
          expect(map['legal_basis'], 'User consent');
          expect(
            map['note'],
            'Third-party data is not stored - only connection metadata',
          );
        }
        expect(result[0]['id'], 'a');
        expect(result[1]['id'], 'b');
      },
    );

    test('C4: rpc throws -> returns null and does not throw', () async {
      final client = _FakeClient(error: Exception('boom'));

      final result = await collectLinkedIdentities(client, 'user-1');

      expect(result, isNull);
    });
  });
}
