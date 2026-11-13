import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:dabbler/features/profile/presentation/providers/contributor_profile_provider.dart';

// The Played / Organised / Upcoming provider now reads the Contributor read
// model, so the owner and visitor screens share one source.
export 'package:dabbler/features/profile/presentation/providers/contributor_profile_provider.dart'
    show profileGameCountsProvider;

/// Whose games to count: the auth user and the profile they are seen as.
typedef ProfileGameCountsArgs = ContributorProfileArgs;

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
    final DateTime? start = DateTime.tryParse(row['start_at'] as String? ?? '');
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
