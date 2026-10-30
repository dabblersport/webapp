import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whose games to count: the auth user and the profile they are seen as.
typedef ProfileGameCountsArgs = ({String userId, String profileId});

const String _countColumns =
    'id, title, start_at, is_cancelled, is_creator, is_joined, '
    'creator_profile_id';

/// A user's Played / Organised / Upcoming figures, counted from `v_game_card`.
/// The view's visibility gate limits a visitor's figures to games the visitor
/// may see. A failed read throws; the profile then draws the tiles' error
/// state rather than a zero.
final profileGameCountsProvider = FutureProvider.autoDispose
    .family<GameCounts, ProfileGameCountsArgs>((ref, args) async {
      final SupabaseClient supabase = Supabase.instance.client;
      final String? me = supabase.auth.currentUser?.id;
      if (me == null) return const GameCounts(played: 0, organised: 0, upcoming: 0);
      final bool isOwn = me == args.userId;

      final Set<String> rostered = <String>{};
      final String membershipOr;
      if (isOwn) {
        membershipOr = 'is_creator.eq.true,is_joined.eq.true';
      } else {
        final List<dynamic> rosterRows =
            await supabase
                    .from(SupabaseConfig.gameRosterTable)
                    .select('game_id')
                    .eq('user_id', args.userId)
                    .eq('status', 'active')
                as List<dynamic>;
        for (final dynamic r in rosterRows) {
          rostered.add((r as Map)['game_id'] as String);
        }
        membershipOr = rostered.isEmpty
            ? 'creator_profile_id.eq.${args.profileId}'
            : 'creator_profile_id.eq.${args.profileId},id.in.(${rostered.join(',')})';
      }

      final List<Map<String, dynamic>> rows = await supabase
          .from(SupabaseConfig.vGameCardTable)
          .select(_countColumns)
          .or(membershipOr);

      return computeGameCounts(
        rowsToGameCountRows(
          rows,
          isOwn: isOwn,
          profileId: args.profileId,
          rostered: rostered,
        ),
      );
    });

/// Maps `v_game_card` rows to count rows. Own profile reads the viewer-
/// relative flags; another profile matches the creator and the target's
/// active roster ids.
List<GameCountRow> rowsToGameCountRows(
  List<Map<String, dynamic>> rows, {
  required bool isOwn,
  required String profileId,
  required Set<String> rostered,
}) {
  final List<GameCountRow> out = <GameCountRow>[];
  for (final Map<String, dynamic> row in rows) {
    final String? id = row['id'] as String?;
    final DateTime? start = DateTime.tryParse(
      row['start_at'] as String? ?? '',
    );
    if (id == null || start == null) continue;
    final bool organiser = isOwn
        ? row['is_creator'] == true
        : row['creator_profile_id'] == profileId;
    final bool joined = isOwn
        ? row['is_joined'] == true
        : rostered.contains(id);
    out.add(
      GameCountRow(
        id: id,
        title: row['title'] as String?,
        startAt: start,
        isCancelled: row['is_cancelled'] == true,
        isOrganiser: organiser,
        participation: joined ? GameParticipation.joined : null,
      ),
    );
  }
  return out;
}
