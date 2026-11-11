// KAN-892: collectGameHistory is a copy of DataExportService
// ._getEnhancedGameHistoryData. No network: the client is a Fake.
import 'dart:async';

import 'package:dabbler/features/profile/services/export/game_history_collector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Rows<T> extends Fake implements PostgrestFilterBuilder<T> {
  _Rows(this._value);
  final Object _value;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) => Future<T>.value(_value as T).then(onValue, onError: onError);
}

class _FakeClient extends Fake implements SupabaseClient {
  _FakeClient({this.rows, this.error});
  final List<Map<String, dynamic>>? rows;
  final Object? error;
  final calls = <String>[];

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get = false,
  }) {
    calls.add(fn);
    if (error != null) throw error!;
    return _Rows<T>(rows!);
  }
}

Map<String, dynamic> _rpcRow(String id) => {
  'event_id': id,
  'event_type': 'game',
  'id': id,
  'game_type': 'pickup',
  'title': 'T',
  'creator_profile_id': 'p',
  'creator_user_id': 'u',
  'venue_space_id': null,
  'start_at': null,
  'end_at': null,
  'capacity': 10,
  'listing_visibility': 'public',
  'join_policy': 'open',
  'allow_spectators': true,
  'min_skill': null,
  'max_skill': null,
  'rules': null,
  'is_cancelled': false,
  'cancelled_at': null,
  'cancelled_reason': null,
  'created_at': null,
  'updated_at': null,
  'squad_id': null,
  'search_tsv': null,
  'sport_specific_data': null,
  'allows_waitlist': false,
  'sport_id': null,
  'geo_location_id': null,
  'area_id': null,
  'venue_id': null,
  'sport_variant_id': null,
  'bench_slots': 0,
  'joining_rule': null,
  'cost_cover': null,
  'price_aed': null,
  'request_id': null,
  'series_id': null,
  'my_roster': {
    'user_id': 'u',
    'joined_at': null,
    'status': 'confirmed',
    'role': 'player',
  },
};

const _expectedKeys = <String>[
  'event_id',
  'id',
  'game_type',
  'title',
  'creator_profile_id',
  'creator_user_id',
  'venue_space_id',
  'start_at',
  'end_at',
  'capacity',
  'listing_visibility',
  'join_policy',
  'allow_spectators',
  'min_skill',
  'max_skill',
  'rules',
  'is_cancelled',
  'cancelled_at',
  'cancelled_reason',
  'created_at',
  'updated_at',
  'squad_id',
  'search_tsv',
  'sport_specific_data',
  'allows_waitlist',
  'sport_id',
  'geo_location_id',
  'area_id',
  'venue_id',
  'sport_variant_id',
  'bench_slots',
  'joining_rule',
  'cost_cover',
  'price_aed',
  'request_id',
  'series_id',
  'game_roster',
  'data_source',
  'purpose',
  'legal_basis',
];

void main() {
  test('two RPC rows map to two maps with the original output keys', () async {
    final client = _FakeClient(rows: [_rpcRow('g1'), _rpcRow('g2')]);

    final result = await collectGameHistory(client, 'u');

    expect(client.calls, ['export_own_game_history']);
    expect(result, hasLength(2));
    for (final map in result!) {
      expect(map.keys.toSet(), _expectedKeys.toSet());
      expect(map.keys, hasLength(_expectedKeys.length));
    }
    expect(result.map((m) => m['id']), ['g1', 'g2']);
  });

  test('a throwing client yields null and nothing escapes', () async {
    final client = _FakeClient(error: Exception('boom'));

    await expectLater(collectGameHistory(client, 'u'), completion(isNull));
  });
}
