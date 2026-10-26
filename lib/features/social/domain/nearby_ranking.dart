import 'dart:math' as math;

import 'package:dabbler/features/social/domain/nearby_ranking_config.dart';

/// KAN-594: Nearby feed ranking. Pure: no I/O, the clock is [asOf].
///
/// score = 0.5^(age / H) x 1 / (1 + distance / D), higher first, id ascending
/// as the tiebreak. Without an origin (City-only) the order is newest first.

/// A post as the ranker sees it.
class NearbyCandidate {
  const NearbyCandidate({
    required this.id,
    required this.createdAt,
    this.lat,
    this.lng,
  });

  final String id;
  final DateTime createdAt;
  final double? lat;
  final double? lng;

  bool get hasCoordinates => lat != null && lng != null;
}

class NearbyOrigin {
  const NearbyOrigin(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// The device location as the Nearby feed needs it.
class NearbyScope {
  const NearbyScope({
    this.city,
    this.lat,
    this.lng,
    this.lastKnown = false,
    this.fixedAt,
  });

  final String? city;
  final double? lat;
  final double? lng;

  /// Auto is unavailable and the point is the last one a fix produced.
  final bool lastKnown;
  final DateTime? fixedAt;

  @override
  bool operator ==(Object other) =>
      other is NearbyScope &&
      other.city == city &&
      other.lat == lat &&
      other.lng == lng &&
      other.lastKnown == lastKnown &&
      other.fixedAt == fixedAt;

  @override
  int get hashCode => Object.hash(city, lat, lng, lastKnown, fixedAt);
}

/// The origin to rank from, or null for City-only (newest first). A
/// last-known point older than [NearbyRankingConfig.lastKnownMaxAge] (or with
/// no timestamp) is dropped.
NearbyOrigin? resolveNearbyOrigin(
  NearbyScope scope,
  DateTime now, {
  NearbyRankingConfig config = NearbyRankingConfig.standard,
}) {
  final lat = scope.lat;
  final lng = scope.lng;
  if (lat == null || lng == null) return null;
  if (scope.lastKnown) {
    final at = scope.fixedAt;
    if (at == null || now.difference(at) > config.lastKnownMaxAge) return null;
  }
  return NearbyOrigin(lat, lng);
}

/// Great-circle distance in metres.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(a.toDouble()));
}

/// The position of a post in the ranking: [score] descending, then [id].
class NearbyCursor {
  const NearbyCursor(this.score, this.id);
  final double score;
  final String id;
}

class ScoredNearby {
  const ScoredNearby(this.candidate, this.score);
  final NearbyCandidate candidate;
  final double score;
  NearbyCursor get cursor => NearbyCursor(score, candidate.id);
}

/// The score of [c]. With an [origin]: recency x distance. Without: the
/// creation time in microseconds, so newest sorts first on the same axis.
double scoreNearby(
  NearbyCandidate c, {
  required NearbyOrigin? origin,
  required DateTime asOf,
  NearbyRankingConfig config = NearbyRankingConfig.standard,
}) {
  if (origin == null) return c.createdAt.microsecondsSinceEpoch.toDouble();
  final ageHours = math.max(
    0,
    asOf.difference(c.createdAt).inMicroseconds / Duration.microsecondsPerHour,
  );
  final halfLifeHours =
      config.recencyHalfLife.inMicroseconds / Duration.microsecondsPerHour;
  final recency = math.pow(0.5, ageHours / halfLifeHours).toDouble();
  final distance = c.hasCoordinates
      ? haversineMeters(origin.lat, origin.lng, c.lat!, c.lng!)
      : config.distanceScaleMeters * config.missingCoordinateDistanceFactor;
  return recency / (1 + distance / config.distanceScaleMeters);
}

/// Candidates ranked best first, each id once. Posts created after [asOf] are
/// left out, so a post that arrives mid-scroll never shifts a later page.
List<ScoredNearby> rankNearby(
  Iterable<NearbyCandidate> candidates, {
  required NearbyOrigin? origin,
  required DateTime asOf,
  NearbyRankingConfig config = NearbyRankingConfig.standard,
}) {
  final seen = <String>{};
  final scored = <ScoredNearby>[
    for (final c in candidates)
      if (!c.createdAt.isAfter(asOf) && seen.add(c.id))
        ScoredNearby(
          c,
          scoreNearby(c, origin: origin, asOf: asOf, config: config),
        ),
  ];
  scored.sort((a, b) {
    final bySore = b.score.compareTo(a.score);
    return bySore != 0 ? bySore : a.candidate.id.compareTo(b.candidate.id);
  });
  return scored;
}

/// The rows strictly after [cursor] in ranking order (all rows when null).
List<ScoredNearby> afterNearbyCursor(
  List<ScoredNearby> ranked,
  NearbyCursor? cursor,
) {
  if (cursor == null) return ranked;
  return [
    for (final r in ranked)
      if (r.score < cursor.score ||
          (r.score == cursor.score && r.candidate.id.compareTo(cursor.id) > 0))
        r,
  ];
}
