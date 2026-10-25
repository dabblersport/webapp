import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/data/repositories/following_sport_filter.dart';
import 'package:dabbler/features/social/domain/nearby_ranking.dart';
import 'package:dabbler/features/social/domain/posted_from.dart';

/// KAN-594: the Nearby candidate set. Original, non-system, public posts the
/// City owns, created at or before `as_of`, newest first. The whole City is
/// read (no row-count cap; the selected City is the boundary), in keyset-free
/// range pages because PostgREST truncates one response. Coordinates
/// are NOT required: a post without them stays a candidate and ranks by
/// recency. A legacy post (`posted_from_city` NULL) belongs to Dubai.
/// Same Following filter as the other discovery feeds (KAN-593).
class NearbyCandidateSource {
  NearbyCandidateSource(this._db, {required this.personaType});

  final SupabaseClient _db;
  final String? personaType;

  /// Rows per round trip. Below PostgREST's default response limit (1000), so a
  /// full page always means "maybe more" and a short page means "done".
  static const int _pageSize = 1000;

  Future<List<NearbyCandidate>> fetch({
    required String? city,
    required DateTime asOf,
  }) async {
    final cityName = city?.trim();
    // Never an unscoped query: without a City there is nothing to rank.
    if (cityName == null || cityName.isEmpty) return const [];

    final followOr = followedSportsOrFilter(
      await loadViewerFollowedSportIds(_db, personaType: personaType),
    );

    var q = _db
        .from(SupabaseConfig.postsTable)
        .select('id, created_at, geo_lat, geo_lng')
        .eq('kind', 'original')
        .neq('origin_type', 'system')
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false)
        // Discovery shows public posts only: a private, followers-only, circle,
        // squad or link post never enters the candidate set (RLS stays on top).
        .eq('visibility', 'public')
        .lte('created_at', asOf.toUtc().toIso8601String());
    if (followOr != null) q = q.or(followOr);
    // Same match as the City-only feed (KAN-588): case-insensitive, with the
    // pattern characters escaped.
    q = cityName.toLowerCase() == kLegacyPostedFromCity.toLowerCase()
        ? q.or(
            'posted_from_city.ilike.$kLegacyPostedFromCity,'
            'posted_from_city.is.null',
          )
        : q.ilike(
            'posted_from_city',
            cityName
                .replaceAll('\\', '\\\\')
                .replaceAll('%', '\\%')
                .replaceAll('_', '\\_'),
          );

    // `as_of` freezes the set and (created_at desc, id) is a total order, so
    // range pages neither repeat nor skip a row.
    final out = <NearbyCandidate>[];
    for (var from = 0; ; from += _pageSize) {
      final rows = await q
          .order('created_at', ascending: false)
          .order('id')
          .range(from, from + _pageSize - 1);
      for (final r in rows) {
        out.add(
          NearbyCandidate(
            id: r['id'] as String,
            createdAt: DateTime.parse(r['created_at'] as String),
            lat: (r['geo_lat'] as num?)?.toDouble(),
            lng: (r['geo_lng'] as num?)?.toDouble(),
          ),
        );
      }
      if (rows.length < _pageSize) return out;
    }
  }
}
