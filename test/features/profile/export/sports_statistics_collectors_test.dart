import 'dart:async';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/profile/services/export/sports_statistics_collectors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records every call on one `.from(table)` chain the collectors use:
/// `select` -> `eq`... -> optional `maybeSingle`, then `await`.
class _Calls {
  _Calls(this.table);

  final String table;
  String? selectColumns;
  final List<List<Object>> eqs = [];
  bool maybeSingle = false;
}

/// One awaitable stand-in for the filter builder. [maybeSingle] resolves
/// to the first canned row, or null when the table has none.
class _FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _FakeFilterBuilder(this._calls, this._rows);

  final _Calls _calls;
  final List<Map<String, dynamic>> _rows;

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) {
    _calls.eqs.add([column, value]);
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    _calls.maybeSingle = true;
    return _FakeSingleBuilder(
      Future<PostgrestMap?>.value(_rows.isEmpty ? null : _rows.first),
    );
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestList value) onValue, {
    Function? onError,
  }) => Future<PostgrestList>.value(_rows).then(onValue, onError: onError);
}

class _FakeSingleBuilder extends Fake
    implements PostgrestTransformBuilder<PostgrestMap?> {
  _FakeSingleBuilder(this._future);

  final Future<PostgrestMap?> _future;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestMap? value) onValue, {
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
    return _FakeFilterBuilder(_calls, _rows);
  }
}

class _FakeClient extends Fake implements SupabaseClient {
  _FakeClient({this.tables = const {}, this.error});

  /// Canned rows per table name.
  final Map<String, List<Map<String, dynamic>>> tables;
  final Object? error;
  final List<_Calls> calls = [];

  @override
  SupabaseQueryBuilder from(String table) {
    final c = _Calls(table);
    calls.add(c);
    if (error != null) throw error!;
    return _FakeQueryBuilder(c, tables[table] ?? const []);
  }
}

const _perSportColumns =
    'sport, skill_level, overall_level, xp_total, xp_level, '
    'matches_played, form_score, form_trend, last_5_matches, '
    'attendance_rate, cancellation_rate, punctuality_score, '
    'teamwork_score, reliability_score, rating_count, '
    'rating_total, performance_highlights, performance_by_venue';

Map<String, List<Map<String, dynamic>>> _oneProfileTwoSports() => {
  SupabaseConfig.usersTable: [
    {'id': 'profile-1'},
  ],
  SupabaseConfig.sportProfilesTable: [
    {'sport': 'football', 'matches_played': 3},
    {'sport': 'padel', 'matches_played': 7},
  ],
  SupabaseConfig.userReputationAggregateTable: [
    {'user_id': 'user-1', 'score': 4.5},
  ],
};

void _expectProfileLookup(_Calls c) {
  expect(c.table, SupabaseConfig.usersTable);
  expect(c.selectColumns, 'id');
  expect(c.eqs, [
    ['user_id', 'user-1'],
    ['profile_type', 'personal'],
  ]);
  expect(c.maybeSingle, isTrue);
}

void main() {
  group('collectSportsProfiles', () {
    test(
      'collectSportsProfiles C3: one profile with two sport rows -> two maps with row keys plus exactly the original added keys',
      () async {
        final client = _FakeClient(tables: _oneProfileTwoSports());

        final result = await collectSportsProfiles(client, 'user-1');

        expect(client.calls, hasLength(2));
        _expectProfileLookup(client.calls[0]);
        final sports = client.calls[1];
        expect(sports.table, SupabaseConfig.sportProfilesTable);
        expect(sports.selectColumns, '*');
        expect(sports.eqs, [
          ['profile_id', 'profile-1'],
        ]);
        expect(sports.maybeSingle, isFalse);

        expect(result, [
          {
            'sport': 'football',
            'matches_played': 3,
            'data_source': 'sport_profiles table',
            'purpose': 'Sports skill assessment and matching',
            'legal_basis': 'User consent and contract performance',
          },
          {
            'sport': 'padel',
            'matches_played': 7,
            'data_source': 'sport_profiles table',
            'purpose': 'Sports skill assessment and matching',
            'legal_basis': 'User consent and contract performance',
          },
        ]);
      },
    );

    test(
      'collectSportsProfiles C4: client throws -> returns null and does not throw',
      () async {
        final client = _FakeClient(error: Exception('boom'));

        final result = await collectSportsProfiles(client, 'user-1');

        expect(result, isNull);
      },
    );
  });

  group('collectStatistics', () {
    test(
      'collectStatistics C3: one profile with two sport rows -> map with exactly the original keys and values',
      () async {
        final client = _FakeClient(tables: _oneProfileTwoSports());

        final result = await collectStatistics(client, 'user-1');

        expect(client.calls, hasLength(3));
        _expectProfileLookup(client.calls[0]);
        final sports = client.calls[1];
        expect(sports.table, SupabaseConfig.sportProfilesTable);
        expect(sports.selectColumns, _perSportColumns);
        expect(sports.eqs, [
          ['profile_id', 'profile-1'],
        ]);
        final reputation = client.calls[2];
        expect(reputation.table, SupabaseConfig.userReputationAggregateTable);
        expect(reputation.selectColumns, '*');
        expect(reputation.eqs, [
          ['user_id', 'user-1'],
        ]);
        expect(reputation.maybeSingle, isTrue);

        expect(result, {
          'per_sport_performance': [
            {'sport': 'football', 'matches_played': 3},
            {'sport': 'padel', 'matches_played': 7},
          ],
          'reputation_aggregate': {'user_id': 'user-1', 'score': 4.5},
          'data_source':
              'sport_profiles (performance columns), user_reputation_aggregate tables',
          'purpose': 'Performance tracking and skill assessment',
          'legal_basis': 'User consent',
          'retention_period': '3 years or until consent withdrawal',
          'note':
              'There is no separate user_game_statistics/performance_metrics '
              'table - this reflects the actual gameplay performance and '
              'reputation data Dabbler stores about you.',
        });
      },
    );

    test(
      'collectStatistics C4: client throws -> returns null and does not throw',
      () async {
        final client = _FakeClient(error: Exception('boom'));

        final result = await collectStatistics(client, 'user-1');

        expect(result, isNull);
      },
    );
  });
}
