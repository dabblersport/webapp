import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/social/domain/nearby_area.dart';
import 'package:dabbler/features/social/domain/nearby_ranking.dart';
import 'package:dabbler/features/social/domain/posted_from.dart';

/// KAN-594: the Nearby candidate set. Original, non-system, public posts the
/// scope owns, created at or before `as_of`, newest first. Coordinates are NOT
/// required: a post without them stays a candidate and ranks by recency. A
/// legacy post (`posted_from_city` NULL) belongs to Dubai.
/// No followed-sports filter: only the Following tab uses one (KAN-955).
///
/// KAN-962: the [NearbyArea] widens the scope. [NearbyArea.city] reads the
/// whole City (no row-count cap; the City is the boundary) in range pages;
/// [NearbyArea.country] reads every City of the country (`areas.country_code`)
/// the same way; [NearbyArea.anywhere] drops the City filter and reads one
/// page, newest first, capped at [_pageSize].
class NearbyCandidateSource {
  NearbyCandidateSource(this._db);

  final SupabaseClient _db;

  /// Rows per round trip. Below PostgREST's default response limit (1000), so a
  /// full page always means "maybe more" and a short page means "done".
  static const int _pageSize = 1000;

  Future<List<NearbyCandidate>> fetch({
    required String? city,
    required DateTime asOf,
    NearbyArea? area,
    String? countryCode,
  }) async {
    final cityName = city?.trim();
    // Never an unscoped query: without a City there is nothing to rank.
    if (cityName == null || cityName.isEmpty) return const [];

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

    if (area == NearbyArea.anywhere) {
      final rows = await q
          .order('created_at', ascending: false)
          .order('id')
          .range(0, _pageSize - 1);
      return [for (final r in rows) _candidate(r)];
    }

    final code = countryCode?.trim();
    final cities = area == NearbyArea.country && code != null && code.isNotEmpty
        ? await _citiesOf(code, cityName)
        : <String>[cityName];
    // Same match as the City-only feed (KAN-588): case-insensitive, with the
    // pattern characters escaped; Dubai also owns rows with no posting City.
    final legacy = cities.any(
      (c) => c.toLowerCase() == kLegacyPostedFromCity.toLowerCase(),
    );
    if (cities.length == 1 && !legacy) {
      q = q.ilike('posted_from_city', _escape(cities.single));
    } else {
      q = q.or(
        <String>[
          for (final c in cities) 'posted_from_city.ilike.${_orValue(c)}',
          if (legacy) 'posted_from_city.is.null',
        ].join(','),
      );
    }

    // `as_of` freezes the set and (created_at desc, id) is a total order, so
    // range pages neither repeat nor skip a row.
    final out = <NearbyCandidate>[];
    for (var from = 0; ; from += _pageSize) {
      final rows = await q
          .order('created_at', ascending: false)
          .order('id')
          .range(from, from + _pageSize - 1);
      out.addAll([for (final r in rows) _candidate(r)]);
      if (rows.length < _pageSize) return out;
    }
  }

  /// The distinct active City names of [countryCode], always including
  /// [cityName] (the listing City), sorted for a stable query.
  Future<List<String>> _citiesOf(String countryCode, String cityName) async {
    final rows = await _db
        .from(SupabaseConfig.areasTable)
        .select('city')
        .eq('country_code', countryCode)
        .eq('is_active', true);
    final byKey = <String, String>{cityName.toLowerCase(): cityName};
    for (final r in rows) {
      final c = (r['city'] as String?)?.trim();
      if (c != null && c.isNotEmpty)
        byKey.putIfAbsent(c.toLowerCase(), () => c);
    }
    return byKey.values.toList()..sort();
  }

  static String _escape(String v) =>
      v.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');

  /// [v] escaped for an `ilike` inside a PostgREST `or=(...)` list: the
  /// pattern characters, then double-quoted when it holds a character the
  /// list reserves, so a comma or parenthesis stays part of the value.
  static String _orValue(String v) {
    final e = _escape(v);
    if (!RegExp(r'[,()"]').hasMatch(e)) return e;
    return '"${e.replaceAll('"', '\\"')}"';
  }

  static NearbyCandidate _candidate(Map<String, dynamic> r) => NearbyCandidate(
    id: r['id'] as String,
    createdAt: DateTime.parse(r['created_at'] as String),
    lat: (r['geo_lat'] as num?)?.toDouble(),
    lng: (r['geo_lng'] as num?)?.toDouble(),
  );
}
