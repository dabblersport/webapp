import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';

/// A completed game the viewer took part in (created it or was on the
/// roster). Exposes exactly the fields the history cards render.
class PastGame {
  const PastGame({
    required this.id,
    required this.title,
    required this.sport,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.currentPlayers,
    required this.maxPlayers,
    this.venueName,
  });

  final String id;
  final String title;
  final String sport;
  final DateTime scheduledDate;
  final String startTime;
  final String endTime;
  final int currentPlayers;
  final int maxPlayers;
  final String? venueName;
}

/// The viewer's game history: ended (not cancelled) games they created or
/// played in, newest first. Reads v_game_card, whose per-viewer
/// is_creator / is_joined flags scope the result to "my" games — the old
/// implementation listed everyone's public games (and silently returned
/// nothing anyway: it read the RLS-locked games table directly).
final pastGamesProvider =
    FutureProvider.autoDispose<List<PastGame>>((ref) async {
  final supabase = Supabase.instance.client;
  if (supabase.auth.currentUser == null) return const [];

  final rows = await supabase
      .from(SupabaseConfig.vGameCardTable)
      .select('id, title, sport_name_en, start_at, end_at, is_cancelled, '
          'venue_name, area_name, capacity, roster_count, '
          'is_creator, is_joined')
      .or('is_creator.eq.true,is_joined.eq.true')
      .eq('is_cancelled', false)
      .lt('end_at', DateTime.now().toUtc().toIso8601String())
      .order('start_at', ascending: false)
      .limit(100) as List<dynamic>;

  final timeFormat = DateFormat('h:mm a');
  return rows.map((r) {
    final row = Map<String, dynamic>.from(r as Map);
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
  }).toList();
});
