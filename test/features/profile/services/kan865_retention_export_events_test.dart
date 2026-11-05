// KAN-865 (F10c): game retention and game-history export move off the
// `games` table onto owner-scoped RPCs (CTO ruling dreq-5087907b).
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/profile/services/data_export_service.dart';
import 'package:dabbler/features/profile/services/data_retention_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every `games` column at Alpha HEAD, written down from the migrations the
/// OLD `.from(games).select('*, game_roster!inner(...)')` read:
/// baseline_schema.sql CREATE TABLE games (33), plus price_aed (20261008140000),
/// request_id (20261021120000), series_id (20261027120000) and event_id
/// (20261101140000 kan710:276). KAN-719 Z01 drops are authored, not applied.
const _oldGamesColumns = <String>[
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
  'event_id',
];

/// The OLD game-history entry: `{...games.*, game_roster, data_source,
/// purpose, legal_basis}` (data_export_service.dart:646-664 before KAN-865).
final _oldGameHistoryKeys = <String>[
  ..._oldGamesColumns,
  'game_roster',
  'data_source',
  'purpose',
  'legal_basis',
]..sort();

Map<String, dynamic> _fakeRpcRow({Map<String, dynamic>? myRoster}) => {
  for (final c in _oldGamesColumns) c: 'v-$c',
  'event_type': 'game',
  'my_roster': myRoster,
};

void main() {
  group(
    'retention: game history goes through retention_cleanup_own_events',
    () {
      test(
        'calls the RPC with p_cutoff about 730 days ago, ISO-8601 UTC',
        () async {
          String? calledFn;
          Map<String, dynamic>? calledParams;
          final now = DateTime.utc(2026, 11, 4, 12);

          await DataRetentionService.cleanupOwnEventsVia((fn, params) async {
            calledFn = fn;
            calledParams = params;
            return 3;
          }, now: now);

          expect(calledFn, 'retention_cleanup_own_events');
          expect(calledFn, SupabaseConfig.retentionCleanupOwnEventsRpc);
          expect(calledParams!.keys, ['p_cutoff']);
          final raw = calledParams!['p_cutoff'] as String;
          expect(raw.endsWith('Z'), isTrue, reason: 'UTC ISO-8601');
          final cutoff = DateTime.parse(raw);
          expect(now.difference(cutoff).inDays, 730);
        },
      );

      test('passes the RPC integer through as the count', () async {
        final count = await DataRetentionService.cleanupOwnEventsVia(
          (_, _) async => 17,
        );
        expect(count, 17);
      });

      test('an RPC error returns 0', () async {
        final count = await DataRetentionService.cleanupOwnEventsVia(
          (_, _) async => throw Exception('28000 not authenticated'),
        );
        expect(count, 0);
      });
    },
  );

  group('export: game history goes through export_own_game_history', () {
    test('calls export_own_game_history with no params', () async {
      String? calledFn;
      Map<String, dynamic>? calledParams;
      await DataExportService.fetchOwnGameHistoryVia((fn, params) async {
        calledFn = fn;
        calledParams = params;
        return <dynamic>[];
      });
      expect(calledFn, 'export_own_game_history');
      expect(calledParams, isEmpty);
    });

    test('a roster row yields exactly the OLD key list', () {
      final mapped = DataExportService.mapGameHistoryRow(
        _fakeRpcRow(
          myRoster: {
            'user_id': 'u1',
            'joined_at': '2026-01-01T00:00:00Z',
            'status': 'confirmed',
            'role': 'player',
          },
        ),
      );
      expect(mapped.keys.toList()..sort(), _oldGameHistoryKeys);
      expect(mapped['game_roster'], [
        {
          'user_id': 'u1',
          'joined_at': '2026-01-01T00:00:00Z',
          'status': 'confirmed',
          'role': 'player',
        },
      ]);
      expect(mapped['data_source'], 'games, game_roster tables');
      expect(mapped['purpose'], 'Game history and social interaction tracking');
      expect(
        mapped['legal_basis'],
        'Contract performance and legitimate interest',
      );
      expect(mapped['event_id'], 'v-event_id');
    });

    test('creator-only row (my_roster null) yields the OLD key list with an '
        'empty game_roster', () {
      final mapped = DataExportService.mapGameHistoryRow(_fakeRpcRow());
      expect(mapped.keys.toList()..sort(), _oldGameHistoryKeys);
      expect(mapped['game_roster'], isEmpty);
    });

    test('fetch maps every rostered row, preserving the RPC order', () async {
      final rows = await DataExportService.fetchOwnGameHistoryVia(
        (_, _) async => [
          {..._fakeRpcRow(myRoster: _roster), 'id': 'newer'},
          {..._fakeRpcRow(myRoster: _roster), 'id': 'older'},
        ],
      );
      expect(rows.map((r) => r['id']), ['newer', 'older']);
      expect(rows.first.keys.toList()..sort(), _oldGameHistoryKeys);
    });

    test('creator-only rows are excluded, as the OLD game_roster!inner '
        'join excluded them', () async {
      final rows = await DataExportService.fetchOwnGameHistoryVia(
        (_, _) async => [
          {..._fakeRpcRow(myRoster: _roster), 'id': 'rostered'},
          {..._fakeRpcRow(), 'id': 'creator-only'},
        ],
      );
      expect(rows.map((r) => r['id']), ['rostered']);
    });
  });

  group('legacy export: games list goes through export_own_game_history', () {
    test('a row yields exactly the OLD games.* key list', () {
      final mapped = DataExportService.mapLegacyGameRow(
        _fakeRpcRow(myRoster: _roster),
      );
      expect(mapped.keys.toList()..sort(), [..._oldGamesColumns]..sort());
    });

    test('fetch keeps creator AND participant rows (OLD or-filter)', () async {
      String? calledFn;
      final rows = await DataExportService.fetchLegacyGamesVia((
        fn,
        params,
      ) async {
        calledFn = fn;
        return [
          {..._fakeRpcRow(myRoster: _roster), 'id': 'played'},
          {..._fakeRpcRow(), 'id': 'created'},
        ];
      });
      expect(calledFn, 'export_own_game_history');
      expect(rows.map((r) => r['id']), ['played', 'created']);
    });
  });
}

const _roster = <String, dynamic>{
  'user_id': 'u1',
  'joined_at': '2026-01-01T00:00:00Z',
  'status': 'confirmed',
  'role': 'player',
};
