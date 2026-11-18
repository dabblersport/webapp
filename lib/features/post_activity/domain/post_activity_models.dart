// KAN-1000 (G-02, G-03): what rpc_rating_get and rpc_result_get return,
// parsed. The server decides every state; the client only reads it.

import 'package:dabbler/core/utils/instant.dart';
import 'package:flutter/foundation.dart';

/// rpc_rating_get `state`.
enum RatingFlowState {
  notEligible,
  notOpen,
  closed,
  notStarted,
  partlySaved,
  submitted;

  static RatingFlowState parse(Object? v) => switch (v) {
    'not_eligible' => notEligible,
    'closed' => closed,
    'not_started' => notStarted,
    'partly_saved' => partlySaved,
    'submitted' => submitted,
    _ => notOpen,
  };
}

Map<String, int> _scores(Object? v) => v is Map
    ? {
        for (final e in v.entries)
          if (e.value is num) '${e.key}': (e.value as num).round(),
      }
    : const <String, int>{};

/// One person or the venue to rate, with the caller's own given scores.
@immutable
class RatingTarget {
  const RatingTarget({required this.id, this.name, this.mine = const {}});

  final String id;

  /// As entered by the user or the venue; never translated.
  final String? name;
  final Map<String, int> mine;

  RatingTarget named(String? n) => RatingTarget(id: id, name: n, mine: mine);
}

@immutable
class RatingFlow {
  const RatingFlow({
    required this.state,
    this.closesAt,
    this.players = const [],
    this.organiser,
    this.venue,
    this.isOrganiser = false,
  });

  factory RatingFlow.fromJson(Map<String, dynamic> j) {
    RatingTarget? one(Object? v, String idKey) {
      if (v is! Map || v[idKey] == null) return null;
      return RatingTarget(id: '${v[idKey]}', mine: _scores(v['mine']));
    }

    return RatingFlow(
      state: RatingFlowState.parse(j['state']),
      closesAt: parseInstantLocal(j['closes_at']),
      players: [
        for (final p in (j['players'] as List? ?? const []))
          if (one(p, 'user_id') case final t?) t,
      ],
      organiser: one(j['organiser'], 'user_id'),
      venue: one(j['venue'], 'venue_id'),
      isOrganiser: j['is_organiser'] == true,
    );
  }

  final RatingFlowState state;

  /// rpc_rating_get `is_organiser`: the caller organised this event, on
  /// every event type.
  final bool isOrganiser;
  final DateTime? closesAt;
  final List<RatingTarget> players;
  final RatingTarget? organiser;
  final RatingTarget? venue;

  RatingFlow withNames(Map<String, String> people, String? venueName) =>
      RatingFlow(
        state: state,
        closesAt: closesAt,
        players: [for (final p in players) p.named(people[p.id])],
        organiser: organiser?.named(people[organiser!.id]),
        venue: venue?.named(venueName),
        isOrganiser: isOrganiser,
      );
}

/// What a rating dimension applies to.
enum RatingSubject { player, organiser, venue }

@immutable
class RatingDimension {
  const RatingDimension({
    required this.key,
    required this.labelEn,
    required this.labelAr,
    required this.subjects,
  });

  final String key;
  final String labelEn;
  final String labelAr;
  final Set<RatingSubject> subjects;

  String label(String languageCode) =>
      languageCode == 'ar' && labelAr.isNotEmpty ? labelAr : labelEn;
}

/// rpc_result_get `state`.
enum ResultState {
  waiting,
  majorityReady,
  approved,
  rejected,
  autoConfirmed,
  closedNoResult,
  tie;

  static ResultState parse(Object? v) => switch (v) {
    'majority_ready' => majorityReady,
    'approved' => approved,
    'rejected' => rejected,
    '24h_passed' => autoConfirmed,
    'closed_no_result' => closedNoResult,
    'tie' => tie,
    _ => waiting,
  };

  bool get isFinal =>
      this == approved ||
      this == rejected ||
      this == autoConfirmed ||
      this == closedNoResult;
}

@immutable
class Score {
  const Score(this.a, this.b, {this.votes = 0});

  static Score? parse(Object? v) => v is Map && v['score_a'] is num
      ? Score(
          (v['score_a'] as num).toInt(),
          (v['score_b'] as num).toInt(),
          votes: (v['votes'] as num?)?.toInt() ?? 0,
        )
      : null;

  final int a;
  final int b;
  final int votes;

  @override
  bool operator ==(Object other) =>
      other is Score && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);
}

/// The caller's own submission: the score and the side they played on.
@immutable
class MyScore {
  const MyScore(this.score, this.side);
  final Score score;

  /// `a` or `b`.
  final String side;
}

@immutable
class ResultTally {
  const ResultTally({
    required this.competitive,
    this.state = ResultState.waiting,
    this.deadlineAt,
    this.provisional,
    this.votes = 0,
    this.submissions = 0,
    this.eligible = 0,
    this.spread = const [],
    this.finalScore,
    this.mine,
    this.isOrganiser = false,
  });

  factory ResultTally.fromJson(Map<String, dynamic> j) {
    if (j['competitive'] != true) return const ResultTally(competitive: false);
    final mine = Score.parse(j['mine']);
    return ResultTally(
      competitive: true,
      state: ResultState.parse(j['state']),
      deadlineAt: parseInstantLocal(j['deadline_at']),
      provisional: Score.parse(j['provisional']),
      votes: (j['votes'] as num?)?.toInt() ?? 0,
      submissions: (j['submissions'] as num?)?.toInt() ?? 0,
      eligible: (j['eligible'] as num?)?.toInt() ?? 0,
      spread: [
        for (final s in (j['spread'] as List? ?? const []))
          if (Score.parse(s) case final v?) v,
      ],
      finalScore: Score.parse(j['final']),
      mine: mine == null
          ? null
          : MyScore(mine, '${(j['mine'] as Map)['side'] ?? 'a'}'),
      isOrganiser: j['is_organiser'] == true,
    );
  }

  final bool competitive;
  final ResultState state;
  final DateTime? deadlineAt;
  final Score? provisional;
  final int votes;
  final int submissions;
  final int eligible;

  /// Every submitted score with its votes, most common first.
  final List<Score> spread;
  final Score? finalScore;
  final MyScore? mine;
  final bool isOrganiser;

  /// The score step takes a submission (open and not past the deadline).
  bool get open => competitive && !state.isFinal;
}

/// Whole hours left until [deadline], rounded up; 0 once passed.
int hoursUntil(DateTime deadline, DateTime now) {
  final m = minutesUntil(deadline, now);
  if (m <= 0) return 0;
  return (m + 59) ~/ 60;
}

/// Whole minutes left until [deadline], rounded up; 0 once passed.
int minutesUntil(DateTime deadline, DateTime now) {
  final s = deadline.difference(now).inSeconds;
  if (s <= 0) return 0;
  return (s + 59) ~/ 60;
}
