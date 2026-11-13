import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/domain/nearby_ranking.dart';
import 'package:dabbler/features/social/domain/nearby_ranking_config.dart';

/// Every post of the City created at or before [asOf], coordinates or not.
typedef NearbyCandidateFetch =
    Future<List<NearbyCandidate>> Function({
      required String? city,
      required DateTime asOf,
    });

typedef NearbyPostsByIds =
    Future<Result<List<Post>, Failure>> Function(List<String> ids);

/// KAN-594: one Nearby feed session. Page 1 (offset 0) fixes `as_of` and the
/// origin; every later page reuses them and continues after the (score, id)
/// cursor of the last row it returned, so a row never repeats and a new post
/// never shifts the list. Pull-to-refresh is a new offset 0.
class NearbyFeedLoader {
  NearbyFeedLoader({
    required NearbyCandidateFetch fetchCandidates,
    required NearbyPostsByIds postsByIds,
    this.config = NearbyRankingConfig.standard,
    DateTime Function()? clock,
  }) : _fetchCandidates = fetchCandidates,
       _postsByIds = postsByIds,
       _clock = clock ?? DateTime.now;

  final NearbyCandidateFetch _fetchCandidates;
  final NearbyPostsByIds _postsByIds;
  final NearbyRankingConfig config;
  final DateTime Function() _clock;

  DateTime? _asOf;
  NearbyOrigin? _origin;
  NearbyCursor? _cursor;
  String? _candidateCity;
  List<NearbyCandidate>? _candidates;

  Future<Result<List<Post>, Failure>> loadPage({
    required NearbyScope scope,
    required int limit,
    required int offset,
  }) async {
    if (offset == 0 || _asOf == null) {
      final now = _clock();
      _asOf = now;
      _origin = resolveNearbyOrigin(scope, now, config: config);
      _cursor = null;
      _candidates = null;
    }
    final asOf = _asOf!;

    // The City is the boundary and nothing is cut: with `as_of` fixed, the full
    // set is read once per session and every page continues after the cursor.
    final city = scope.city?.trim();
    if (city == null || city.isEmpty) return const Ok(<Post>[]);
    if (_candidates == null || _candidateCity != city) {
      try {
        _candidates = await _fetchCandidates(city: city, asOf: asOf);
        _candidateCity = city;
      } catch (e) {
        return Err(Failure.from(e));
      }
    }
    final candidates = _candidates!;

    final ranked = rankNearby(
      candidates,
      origin: _origin,
      asOf: asOf,
      config: config,
    );
    final page = afterNearbyCursor(ranked, _cursor).take(limit).toList();
    if (page.isEmpty) return const Ok(<Post>[]);

    final result = await _postsByIds([for (final r in page) r.candidate.id]);
    return result.fold((err) => Err(err), (posts) {
      _cursor = page.last.cursor;
      return Ok(posts);
    });
  }
}
