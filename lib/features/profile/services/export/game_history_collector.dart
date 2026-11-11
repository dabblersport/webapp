import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/features/profile/services/data_export_service.dart'
    show Logger;

/// KAN-892: the PDPL export's game-history collector, copied from
/// `DataExportService._getEnhancedGameHistoryData` (KAN-865) and the private
/// and `@visibleForTesting` helpers it calls (`_ownGameHistoryRows`,
/// `fetchOwnGameHistoryVia`, `mapLegacyGameRow`, `mapGameHistoryRow`).
///
/// The RPC scopes to auth.uid() (creator OR roster) and the creator-only rows
/// are dropped client-side, so [userId] is not sent, exactly as in the
/// original. On any failure the error is logged as the original logs it and
/// null is returned; nothing is thrown.
Future<List<Map<String, dynamic>>?> collectGameHistory(
  SupabaseClient client,
  String userId,
) async {
  try {
    return await _fetchOwnGameHistoryVia(
      (fn, params) async => client.rpc(fn, params: params),
    );
  } catch (e) {
    Logger.warning('Could not fetch game history data', e);
    return null;
  }
}

// Defined by supabase/migrations/20261105130000_kan865_export_own_game_history.sql.
// No SupabaseConfig constant exists for it yet and lib/core is outside this
// ticket's scope, so the name is held here, as data_export_service.dart does.
const String _exportOwnGameHistoryRpc = 'export_own_game_history';

Future<List<Map<String, dynamic>>> _ownGameHistoryRows(
  Future<dynamic> Function(String fn, Map<String, dynamic> params) rpc,
) async {
  final response = await rpc(_exportOwnGameHistoryRpc, const {});
  return (response as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();
}

/// Keeps only the rows where the caller has a roster row and maps each with
/// [_mapGameHistoryRow], keeping the RPC's created_at DESC order.
Future<List<Map<String, dynamic>>> _fetchOwnGameHistoryVia(
  Future<dynamic> Function(String fn, Map<String, dynamic> params) rpc,
) async => [
  for (final row in await _ownGameHistoryRows(rpc))
    if (row['my_roster'] != null) _mapGameHistoryRow(row),
];

/// Strips the two RPC-only keys so a row carries exactly the old `games.*`
/// key set.
Map<String, dynamic> _mapLegacyGameRow(Map<String, dynamic> row) =>
    Map<String, dynamic>.of(row)
      ..remove('my_roster')
      ..remove('event_type');

/// `my_roster` goes back into `game_roster` (a one-row list) and
/// `event_type`, which games.* never had, is not exported.
Map<String, dynamic> _mapGameHistoryRow(Map<String, dynamic> row) {
  final myRoster = row['my_roster'];
  return {
    ..._mapLegacyGameRow(row),
    'game_roster': [
      if (myRoster != null) Map<String, dynamic>.from(myRoster as Map),
    ],
    'data_source': 'games, game_roster tables',
    'purpose': 'Game history and social interaction tracking',
    'legal_basis': 'Contract performance and legitimate interest',
  };
}
