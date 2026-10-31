import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:dabbler/features/profile/presentation/models/contributor_profile_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whose Contributor profile to read: the auth user and the profile they are
/// seen as.
typedef ContributorProfileArgs = ({String userId, String profileId});

const String _gameColumns =
    'id, title, start_at, is_cancelled, is_creator, is_joined, '
    'creator_profile_id, sport_id';

const String _meetupColumns =
    'id, title, start_at, is_cancelled, creator_profile_id, creator_user_id, '
    'sport_id';

const ContributorGap _ownerPrivate = ContributorGap(
  'owner-private',
  'Organiser work queue is private to the owner and is never read for a '
      'visitor.',
);

/// The Contributor read model for [args]. One implementation serves the owner
/// and a visitor; the viewer is whoever is signed in.
final contributorProfileProvider = FutureProvider.autoDispose
    .family<ContributorProfileData, ContributorProfileArgs>((ref, args) async {
      final SupabaseClient supabase = Supabase.instance.client;
      final String? me = supabase.auth.currentUser?.id;
      if (me == null) {
        // Not a zero: nobody is signed in, so nothing can be read.
        throw StateError('Contributor profile needs a signed-in viewer');
      }
      return loadContributorProfile(
        supabase,
        viewerUserId: me,
        targetUserId: args.userId,
        profileId: args.profileId,
      );
    });

/// Reads each source on its own so one failure leaves the rest readable.
/// Counts come from the full result, never from the length of a first page.
Future<ContributorProfileData> loadContributorProfile(
  SupabaseClient supabase, {
  required String viewerUserId,
  required String targetUserId,
  required String profileId,
}) async {
  final bool isOwn = viewerUserId == targetUserId;

  final List<SourceState<Object>> read =
      await Future.wait(<Future<SourceState<Object>>>[
        _guard<List<ContributorEntity>>(
          () => _readGames(supabase, isOwn, targetUserId, profileId),
        ),
        _guard<List<ContributorEntity>>(
          () => _readMeetups(supabase, isOwn, profileId),
        ),
        _guard<List<ContributorSport>>(() => _readSports(supabase, profileId)),
      ]);

  return ContributorProfileData(
    profileId: profileId,
    isOwner: isOwn,
    games: read[0] as SourceState<List<ContributorEntity>>,
    meetups: read[1] as SourceState<List<ContributorEntity>>,
    sports: read[2] as SourceState<List<ContributorSport>>,
    needsAttention: isOwn
        ? const SourceGap<int>(ContributorGaps.needsAttention)
        : const SourceGap<int>(_ownerPrivate),
  );
}

Future<SourceState<Object>> _guard<T extends Object>(
  Future<T> Function() read,
) async {
  try {
    return SourceData<T>(await read());
  } catch (e) {
    return SourceFailed<T>(e);
  }
}

Future<List<ContributorEntity>> _readGames(
  SupabaseClient supabase,
  bool isOwn,
  String targetUserId,
  String profileId,
) async {
  final Set<String> rostered = <String>{};
  final String membershipOr;
  if (isOwn) {
    membershipOr = 'is_creator.eq.true,is_joined.eq.true';
  } else {
    final List<dynamic> rosterRows =
        await supabase
                .from(SupabaseConfig.gameRosterTable)
                .select('game_id')
                .eq('user_id', targetUserId)
                .eq('status', 'active')
            as List<dynamic>;
    for (final dynamic r in rosterRows) {
      rostered.add((r as Map)['game_id'] as String);
    }
    membershipOr = rostered.isEmpty
        ? 'creator_profile_id.eq.$profileId'
        : 'creator_profile_id.eq.$profileId,id.in.(${rostered.join(',')})';
  }
  final List<Map<String, dynamic>> rows = await supabase
      .from(SupabaseConfig.vGameCardTable)
      .select(_gameColumns)
      .or(membershipOr);
  return gameRowsToEntities(
    rows,
    isOwn: isOwn,
    profileId: profileId,
    rostered: rostered,
  );
}

Future<List<ContributorEntity>> _readMeetups(
  SupabaseClient supabase,
  bool isOwn,
  String profileId,
) async {
  // A visitor sees only what the view's visibility gate lets them see of
  // the meetups this profile hosts. Another profile's RSVPs are not exposed
  // by the view, so [ContributorGaps.visitorAttending] stands for them.
  final String membershipOr = isOwn
      ? 'creator_profile_id.eq.$profileId,my_rsvp_status.eq.going'
      : 'creator_profile_id.eq.$profileId';
  final List<Map<String, dynamic>> rows = await supabase
      .from(SupabaseConfig.vMeetupListView)
      .select(isOwn ? '$_meetupColumns, my_rsvp_status' : _meetupColumns)
      .or(membershipOr);
  return meetupRowsToEntities(rows, isOwn: isOwn, profileId: profileId);
}

Future<List<ContributorSport>> _readSports(
  SupabaseClient supabase,
  String profileId,
) async {
  final List<Map<String, dynamic>> rows = await supabase
      .from(SupabaseConfig.sportProfilesTable)
      .select('sport_id, sport')
      .eq('profile_id', profileId);
  return <ContributorSport>[
    for (final Map<String, dynamic> r in rows)
      if (r['sport_id'] is String)
        ContributorSport(
          sportId: r['sport_id'] as String,
          sportKey: r['sport'] as String?,
        ),
  ];
}

/// Maps `v_game_card` rows to entities. The owner reads the viewer-relative
/// flags; another profile matches the creator and the target's active roster.
List<ContributorEntity> gameRowsToEntities(
  List<Map<String, dynamic>> rows, {
  required bool isOwn,
  required String profileId,
  required Set<String> rostered,
}) {
  final List<ContributorEntity> out = <ContributorEntity>[];
  for (final Map<String, dynamic> row in rows) {
    final String? id = row['id'] as String?;
    final DateTime? start = DateTime.tryParse(row['start_at'] as String? ?? '');
    if (id == null || start == null) continue;
    out.add(
      ContributorEntity(
        kind: ContributorEntityKind.game,
        id: id,
        title: row['title'] as String?,
        startAt: start,
        sportId: row['sport_id'] as String?,
        isCancelled: row['is_cancelled'] == true,
        isOrganiser: isOwn
            ? row['is_creator'] == true
            : row['creator_profile_id'] == profileId,
        takesPart: isOwn ? row['is_joined'] == true : rostered.contains(id),
      ),
    );
  }
  return out;
}

/// Maps `v_meetup_list` rows. Hosting a meetup is organising; saying "going"
/// is taking part.
List<ContributorEntity> meetupRowsToEntities(
  List<Map<String, dynamic>> rows, {
  required bool isOwn,
  required String profileId,
}) {
  final List<ContributorEntity> out = <ContributorEntity>[];
  for (final Map<String, dynamic> row in rows) {
    final String? id = row['id'] as String?;
    final DateTime? start = DateTime.tryParse(row['start_at'] as String? ?? '');
    if (id == null || start == null) continue;
    out.add(
      ContributorEntity(
        kind: ContributorEntityKind.meetup,
        id: id,
        title: row['title'] as String?,
        startAt: start,
        sportId: row['sport_id'] as String?,
        isCancelled: row['is_cancelled'] == true,
        isOrganiser: row['creator_profile_id'] == profileId,
        takesPart: isOwn && row['my_rsvp_status'] == 'going',
      ),
    );
  }
  return out;
}

/// The Played / Organised / Upcoming figures both profile screens draw. A
/// failed games read throws so the tiles show their error state; it is never
/// turned into a zero.
final profileGameCountsProvider = FutureProvider.autoDispose
    .family<GameCounts, ContributorProfileArgs>((ref, args) async {
      final ContributorProfileData data = await ref.watch(
        contributorProfileProvider(args).future,
      );
      final SourceState<List<ContributorEntity>> games = data.games;
      if (games is SourceFailed<List<ContributorEntity>>) {
        throw games.error;
      }
      return data.scope()!.counts;
    });
