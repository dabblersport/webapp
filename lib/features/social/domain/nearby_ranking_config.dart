/// KAN-594: the Nearby feed ranking values. Product ruling (AC3, 2026-10-22):
/// H = 24 h, D = 5 km, missing coordinates = distance 2 x D, no radius cap
/// (the selected City is the boundary), last-known origin valid for 24 h.
///
/// These are the only place the ranking numbers live: change them here, never
/// in the ranker, the repository or a provider.
class NearbyRankingConfig {
  const NearbyRankingConfig({
    this.recencyHalfLifeHours = 24,
    this.distanceScaleMeters = 5000,
    this.missingCoordinateDistanceFactor = 2,
    this.lastKnownMaxAgeHours = 24,
  });

  /// H, in hours: a post loses half its recency weight every H.
  final int recencyHalfLifeHours;

  Duration get recencyHalfLife => Duration(hours: recencyHalfLifeHours);

  /// D: at this distance the distance factor is 0.5.
  final double distanceScaleMeters;

  /// A post without coordinates counts as this many D away (2 x D = 0.33).
  final double missingCoordinateDistanceFactor;

  /// A last-known origin older than this many hours is ignored (City-only,
  /// newest first).
  final int lastKnownMaxAgeHours;

  Duration get lastKnownMaxAge => Duration(hours: lastKnownMaxAgeHours);

  static const NearbyRankingConfig standard = NearbyRankingConfig();
}
