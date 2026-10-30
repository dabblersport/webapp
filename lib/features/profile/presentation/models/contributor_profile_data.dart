import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';

/// The kind of thing a Contributor did or will do. Ids are only unique within
/// a kind, so every merge keys on kind AND id.
enum ContributorEntityKind { game, meetup }

/// One game or meetup in a Contributor's history or schedule.
class ContributorEntity {
  const ContributorEntity({
    required this.kind,
    required this.id,
    required this.startAt,
    this.title,
    this.sportId,
    this.isOrganiser = false,
    this.takesPart = false,
    this.isCancelled = false,
  });

  final ContributorEntityKind kind;
  final String id;
  final String? title;
  final DateTime startAt;
  final String? sportId;
  final bool isOrganiser;
  final bool takesPart;
  final bool isCancelled;

  String get key => '${kind.name}:$id';

  ContributorEntity merge(ContributorEntity other) => ContributorEntity(
    kind: kind,
    id: id,
    title: title ?? other.title,
    startAt: startAt,
    sportId: sportId ?? other.sportId,
    isOrganiser: isOrganiser || other.isOrganiser,
    takesPart: takesPart || other.takesPart,
    isCancelled: isCancelled && other.isCancelled,
  );
}

/// A data element the profile design draws that has no populated backend
/// source yet. [id] names the gap so it can be tracked; it is never a number.
class ContributorGap {
  const ContributorGap(this.id, this.description);
  final String id;
  final String description;
}

/// The state of one source of profile data. A section is either read
/// ([SourceData]), unreadable ([SourceFailed]) or has no source at all
/// ([SourceGap]). A zero is only ever a [SourceData] holding a real zero.
sealed class SourceState<T> {
  const SourceState();
}

class SourceData<T> extends SourceState<T> {
  const SourceData(this.value);
  final T value;
}

class SourceFailed<T> extends SourceState<T> {
  const SourceFailed(this.error);
  final Object error;
}

class SourceGap<T> extends SourceState<T> {
  const SourceGap(this.gap);
  final ContributorGap gap;
}

extension SourceStateX<T> on SourceState<T> {
  T? get valueOrNull => switch (this) {
    SourceData<T>(:final value) => value,
    _ => null,
  };
  bool get isFailed => this is SourceFailed<T>;
  bool get isGap => this is SourceGap<T>;
}

/// The named backend gaps. Each is a design element with no populated source
/// today; none is approximated.
abstract final class ContributorGaps {
  static const ContributorGap showUpRate = ContributorGap(
    'attendance-record',
    'No per-game attended / no-show record exists; '
        'sport_profiles.attendance_rate defaults to 1 and is not measured.',
  );
  static const ContributorGap minutesPlayed = ContributorGap(
    'attendance-record',
    'Minutes played needs a record of who attended; '
        'game_roster holds joined/left only.',
  );
  static const ContributorGap partners = ContributorGap(
    'partners-source',
    'No query returns the people a Contributor has played with.',
  );
  static const ContributorGap needsAttention = ContributorGap(
    'needs-attention-source',
    'No query returns pending items for the organiser (requests, unpaid, '
        'unconfirmed).',
  );
  static const ContributorGap mutuals = ContributorGap(
    'mutuals-source',
    'No query returns mutual connections between viewer and profile.',
  );
  static const ContributorGap sportTiers = ContributorGap(
    'sport-tier-source',
    'sport_profiles has no Primary / Practicing / Following tier column.',
  );
  static const ContributorGap visitorAttending = ContributorGap(
    'visitor-meetup-attending',
    'v_meetup_list exposes RSVPs for the viewer only, so another profile\'s '
        'attended meetups cannot be read.',
  );
}

/// What one sport selection yields. [sportId] null is "all sports".
class ContributorScope {
  const ContributorScope({
    required this.sportId,
    required this.counts,
    required this.activity,
    required this.upcoming,
    required this.organisedGames,
  });

  final String? sportId;

  /// Played / Organised / Upcoming for the scope, counted from distinct games.
  final GameCounts counts;

  /// Everything the Contributor did or organised in the scope, past and
  /// future, deduplicated by kind+id, most recent first. Feeds the hero.
  final List<ContributorEntity> activity;

  /// Games and meetups still to come, deduplicated by kind+id, soonest first.
  final List<ContributorEntity> upcoming;

  /// Games the Contributor organises, soonest first.
  final List<ContributorEntity> organisedGames;

  /// The Contributor has no history at all in this scope.
  bool get hasNoHistory => activity.isEmpty;
}

/// A sport the Contributor has a sport profile for.
class ContributorSport {
  const ContributorSport({required this.sportId, this.sportKey});
  final String sportId;
  final String? sportKey;
}

/// The one Contributor read model. Owner and visitor build it the same way;
/// [isOwner] says which fields were read with owner authority.
///
/// Sections are independent: one source failing leaves the others readable.
class ContributorProfileData {
  const ContributorProfileData({
    required this.profileId,
    required this.isOwner,
    required this.games,
    required this.meetups,
    required this.sports,
    this.showUpRate = const SourceGap<double>(ContributorGaps.showUpRate),
    this.minutesPlayed = const SourceGap<int>(ContributorGaps.minutesPlayed),
    this.partners = const SourceGap<int>(ContributorGaps.partners),
    this.mutuals = const SourceGap<int>(ContributorGaps.mutuals),
    this.needsAttention = const SourceGap<int>(ContributorGaps.needsAttention),
    this.sportTiers = const SourceGap<Object>(ContributorGaps.sportTiers),
  });

  final String profileId;
  final bool isOwner;

  /// Games, as entities. Failed or data; there is no gap.
  final SourceState<List<ContributorEntity>> games;

  /// Meetups the profile hosts (visible to the reader) plus, for the owner,
  /// those they said they are going to.
  final SourceState<List<ContributorEntity>> meetups;

  final SourceState<List<ContributorSport>> sports;

  /// Never derived from the reliability heuristic.
  final SourceState<double> showUpRate;
  final SourceState<int> minutesPlayed;

  /// Owner-private: pending organiser work, never shown to a visitor.
  final SourceState<int> needsAttention;

  /// Visitor-facing connection facts.
  final SourceState<int> partners;
  final SourceState<int> mutuals;
  final SourceState<Object> sportTiers;

  /// Why the whole profile cannot be scoped: both event sources failed.
  bool get eventsUnavailable => games.isFailed && meetups.isFailed;

  /// The scoped view. Null while neither events source could be read, so a
  /// failed read never renders as a zero.
  ContributorScope? scope({String? sportId, DateTime? now}) {
    final List<ContributorEntity>? g = games.valueOrNull;
    final List<ContributorEntity>? m = meetups.valueOrNull;
    if (g == null && m == null) return null;
    return buildContributorScope(
      games: g ?? const <ContributorEntity>[],
      meetups: m ?? const <ContributorEntity>[],
      sportId: sportId,
      now: now,
    );
  }

  /// A Contributor with a source that read cleanly, an empty history, and
  /// sport profiles still has a Primary sport to show.
  List<ContributorSport> get sportsOrEmpty =>
      sports.valueOrNull ?? const <ContributorSport>[];
}

/// Merges [games] and [meetups] by kind+id and scopes them to [sportId].
ContributorScope buildContributorScope({
  required List<ContributorEntity> games,
  required List<ContributorEntity> meetups,
  String? sportId,
  DateTime? now,
}) {
  final DateTime at = now ?? DateTime.now();
  final Map<String, ContributorEntity> byKey = <String, ContributorEntity>{};
  for (final ContributorEntity e in <ContributorEntity>[...games, ...meetups]) {
    if (sportId != null && e.sportId != sportId) continue;
    final ContributorEntity? seen = byKey[e.key];
    byKey[e.key] = seen == null ? e : seen.merge(e);
  }
  final List<ContributorEntity> live = byKey.values
      .where((ContributorEntity e) => !e.isCancelled)
      .toList();

  // Played / Organised / Upcoming count games only; meetups are not games.
  final GameCounts counts = computeGameCounts(
    live
        .where((ContributorEntity e) => e.kind == ContributorEntityKind.game)
        .map(
          (ContributorEntity e) => GameCountRow(
            id: e.id,
            title: e.title,
            startAt: e.startAt,
            isCancelled: false,
            isOrganiser: e.isOrganiser,
            participation: e.takesPart ? GameParticipation.joined : null,
          ),
        ),
    now: at,
  );

  final List<ContributorEntity> activity =
      live.where((ContributorEntity e) => e.isOrganiser || e.takesPart).toList()
        ..sort(
          (ContributorEntity a, ContributorEntity b) =>
              b.startAt.compareTo(a.startAt),
        );
  final List<ContributorEntity> upcoming =
      activity.where((ContributorEntity e) => e.startAt.isAfter(at)).toList()
        ..sort(
          (ContributorEntity a, ContributorEntity b) =>
              a.startAt.compareTo(b.startAt),
        );
  final List<ContributorEntity> organised =
      live
          .where(
            (ContributorEntity e) =>
                e.kind == ContributorEntityKind.game && e.isOrganiser,
          )
          .toList()
        ..sort(
          (ContributorEntity a, ContributorEntity b) =>
              a.startAt.compareTo(b.startAt),
        );

  return ContributorScope(
    sportId: sportId,
    counts: counts,
    activity: activity,
    upcoming: upcoming,
    organisedGames: organised,
  );
}
