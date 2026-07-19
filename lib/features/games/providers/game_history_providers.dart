import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/explore/presentation/screens/sports_history_screen.dart'
    show PastGame;

/// Family key for a user's game history within a single sport.
/// [sportId] is the sports-table UUID stored in games.sport_id.
typedef SportGameHistoryArgs = ({String userId, String sportId});

/// Upcoming + past joined/created games for one sport.
typedef SportGameHistory = ({List<PastGame> upcoming, List<PastGame> past});

const _historyColumns =
    'id, title, sport_name_en, start_at, end_at, is_cancelled, '
    'venue_name, area_name, capacity, roster_count';

PastGame _rowToGame(Map<String, dynamic> row) {
  final timeFormat = DateFormat('h:mm a');
  final startAt =
      DateTime.tryParse(row['start_at'] as String? ?? '') ?? DateTime.now();
  final endAt = DateTime.tryParse(row['end_at'] as String? ?? '');
  return PastGame(
    id: row['id'] as String,
    title: row['title'] as String? ?? 'Untitled Game',
    sport: row['sport_name_en'] as String? ?? 'Sport',
    scheduledDate: startAt,
    startTime: timeFormat.format(startAt),
    endTime: endAt != null ? timeFormat.format(endAt) : '',
    currentPlayers: row['roster_count'] as int? ?? 0,
    maxPlayers: row['capacity'] as int? ?? 0,
    venueName: (row['venue_name'] ?? row['area_name']) as String?,
  );
}

/// Game history for one sport — created or joined games from v_game_card,
/// split into upcoming (soonest first) and past (most recent first).
///
/// Works for any profile: for the viewer's own history it uses the
/// per-viewer is_creator / is_joined flags; for someone else's profile it
/// matches games that user created or is rostered on. Either way,
/// v_game_card's visibility gate limits results to games the VIEWER is
/// allowed to see (public / followers / participant), so private games
/// never leak into someone else's profile view.
///
/// Replaces the old getMyGames-based implementation, which filtered on a
/// nonexistent games.host_user_id column and read the RLS-locked games
/// table directly — it never returned anything.
final sportGameHistoryProvider = FutureProvider.autoDispose
    .family<SportGameHistory, SportGameHistoryArgs>((ref, args) async {
  final supabase = Supabase.instance.client;
  if (supabase.auth.currentUser == null) {
    return (upcoming: const <PastGame>[], past: const <PastGame>[]);
  }

  final isOwn = supabase.auth.currentUser!.id == args.userId;
  final nowIso = DateTime.now().toUtc().toIso8601String();

  // Membership filter. Own profile: the view's viewer-relative flags.
  // Other profiles: creator match + the target's active roster game ids
  // (the game_roster SELECT policy already trims those to games the viewer
  // can see).
  final String membershipOr;
  if (isOwn) {
    membershipOr = 'is_creator.eq.true,is_joined.eq.true';
  } else {
    final rosterRows = await supabase
        .from(SupabaseConfig.gameRosterTable)
        .select('game_id')
        .eq('user_id', args.userId)
        .eq('status', 'active') as List<dynamic>;
    final ids = rosterRows
        .map((r) => (r as Map)['game_id'] as String)
        .toSet()
        .join(',');
    membershipOr = ids.isEmpty
        ? 'creator_user_id.eq.${args.userId}'
        : 'creator_user_id.eq.${args.userId},id.in.($ids)';
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> base() => supabase
      .from(SupabaseConfig.vGameCardTable)
      .select(_historyColumns)
      .or(membershipOr)
      .eq('sport_id', args.sportId)
      .eq('is_cancelled', false);

  final results = await Future.wait([
    base().gte('end_at', nowIso).order('start_at', ascending: true).limit(10),
    base().lt('end_at', nowIso).order('start_at', ascending: false).limit(10),
  ]);

  List<PastGame> mapRows(List<Map<String, dynamic>> rows) =>
      rows.map(_rowToGame).toList();

  return (upcoming: mapRows(results[0]), past: mapRows(results[1]));
});
