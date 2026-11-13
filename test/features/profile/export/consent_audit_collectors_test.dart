import 'dart:async';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/profile/services/export/consent_audit_collectors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records every call on the `.from(table)` chain the collectors use:
/// `select` -> `eq` / `gte` -> `order` -> `limit`, then `await`.
class _Calls {
  String? table;
  String? selectColumns;
  final List<List<Object>> eqs = [];
  final List<List<Object>> gtes = [];
  final List<List<Object>> orders = [];
  final List<int> limits = [];
}

/// One awaitable stand-in for both the filter and transform builders.
/// [PostgrestFilterBuilder] extends [PostgrestTransformBuilder], so
/// `order` and `limit` can return `this`.
class _FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  _FakeFilterBuilder(this._calls, this._future);

  final _Calls _calls;
  final Future<T> _future;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    _calls.eqs.add([column, value]);
    return this;
  }

  @override
  PostgrestFilterBuilder<T> gte(String column, Object value) {
    _calls.gtes.add([column, value]);
    return this;
  }

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    _calls.orders.add([column, ascending]);
    return this;
  }

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) {
    _calls.limits.add(count);
    return this;
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => _future.then(onValue, onError: onError);
}

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this._calls, this._rows);

  final _Calls _calls;
  final List<Map<String, dynamic>> _rows;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    _calls.selectColumns = columns;
    return _FakeFilterBuilder<PostgrestList>(
      _calls,
      Future<PostgrestList>.value(_rows),
    );
  }
}

class _FakeClient extends Fake implements SupabaseClient {
  _FakeClient({this.rows = const [], this.error});

  final List<Map<String, dynamic>> rows;
  final Object? error;
  final _Calls calls = _Calls();

  @override
  SupabaseQueryBuilder from(String table) {
    calls.table = table;
    if (error != null) throw error!;
    return _FakeQueryBuilder(calls, rows);
  }
}

const _rowKeys = {'id', 'created_at'};

List<Map<String, dynamic>> _twoRows() => [
  {'id': 'a', 'created_at': '2026-11-01T00:00:00Z'},
  {'id': 'b', 'created_at': '2026-11-02T00:00:00Z'},
];

void main() {
  group('collectConsentHistory', () {
    test(
      'collectConsentHistory C3: two rows -> two maps with row keys plus exactly the original added keys',
      () async {
        final client = _FakeClient(rows: _twoRows());

        final result = await collectConsentHistory(client, 'user-1');

        final calls = client.calls;
        expect(calls.table, SupabaseConfig.consentRecordsTable);
        expect(calls.selectColumns, '*');
        expect(calls.eqs, [
          ['user_id', 'user-1'],
        ]);
        expect(calls.gtes, isEmpty);
        expect(calls.orders, [
          ['created_at', false],
        ]);
        expect(calls.limits, isEmpty);

        expect(result, hasLength(2));
        for (final map in result!) {
          expect(map.keys.toSet(), {
            ..._rowKeys,
            'data_source',
            'purpose',
            'legal_basis',
          });
          expect(map['data_source'], 'consent_records table');
          expect(map['purpose'], 'Legal compliance and consent tracking');
          expect(map['legal_basis'], 'Legal obligation (GDPR Article 7)');
        }
        expect(result[0]['id'], 'a');
        expect(result[1]['id'], 'b');
      },
    );

    test(
      'collectConsentHistory C4: client throws -> returns null and does not throw',
      () async {
        final client = _FakeClient(error: Exception('boom'));

        final result = await collectConsentHistory(client, 'user-1');

        expect(result, isNull);
      },
    );
  });

  group('collectAuditLogs', () {
    test(
      'collectAuditLogs C3: two rows -> two maps with row keys plus exactly the original added keys',
      () async {
        final client = _FakeClient(rows: _twoRows());

        final result = await collectAuditLogs(client, 'user-1');

        final calls = client.calls;
        expect(calls.table, SupabaseConfig.auditEventsTable);
        expect(calls.selectColumns, '*');
        expect(calls.eqs, [
          ['actor_user_id', 'user-1'],
        ]);
        expect(calls.gtes, hasLength(1));
        expect(calls.gtes.single[0], 'created_at');
        final since = DateTime.parse(calls.gtes.single[1] as String);
        expect(
          DateTime.now().difference(since).inDays,
          inInclusiveRange(729, 730),
        );
        expect(calls.orders, [
          ['created_at', false],
        ]);
        expect(calls.limits, [5000]);

        expect(result, hasLength(2));
        for (final map in result!) {
          expect(map.keys.toSet(), {
            ..._rowKeys,
            'data_source',
            'purpose',
            'legal_basis',
            'retention_period',
          });
          expect(map['data_source'], 'audit_events table');
          expect(map['purpose'], 'Security monitoring and compliance');
          expect(map['legal_basis'], 'Legitimate interest (security)');
          expect(map['retention_period'], '2 years');
        }
        expect(result[0]['id'], 'a');
        expect(result[1]['id'], 'b');
      },
    );

    test(
      'collectAuditLogs C4: client throws -> returns null and does not throw',
      () async {
        final client = _FakeClient(error: Exception('boom'));

        final result = await collectAuditLogs(client, 'user-1');

        expect(result, isNull);
      },
    );
  });
}
