/// KAN-593 — "Following" sport filter for DISCOVERY feeds only.
///
/// Mapping (verified against supabase/migrations/20260829080500_baseline_schema.sql):
/// - Following = `profiles.interests`, type `uuid[]` — each element is a
///   `sports.id` UUID (written by `rpc_onboard_profile(p_interests uuid[])`
///   and the Profile > Sports screen). Dart reads it as `List<String>?`.
/// - A post's sport tag = `posts.sport_id`, type `uuid` (FK to `sports.id`);
///   Dart reads it as `Post.sportId` (`@JsonKey(name: 'sport_id')`).
/// - So the match is `posts.sport_id ∈ profiles.interests` — UUID to UUID.
///   No `sport_key` and no `profiles.primary_sport` is involved.
///
/// Rules (orchestrator ruling under D-035):
/// - untagged posts (`sport_id` null/empty) are always shown;
/// - a viewer whose Following is NULL or empty gets NO filter (an empty
///   Following must never empty the feed);
/// - search, profile post lists, sport overview and post-by-id/direct links
///   never call this filter.
library;

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Normalises a raw `profiles.interests` value into a set of sport UUIDs.
///
/// Returns `null` (meaning "do not filter") when the value is NULL, not a
/// list, or contains no usable id. UUIDs are lower-cased so a mixed-case
/// value still matches Postgres' canonical lower-case text form.
Set<String>? parseFollowedSportIds(Object? interests) {
  if (interests is! List) return null;
  final ids = <String>{
    for (final v in interests)
      if (v is String && v.trim().isNotEmpty) v.trim().toLowerCase(),
  };
  return ids.isEmpty ? null : ids;
}

/// Whether a post with [sportId] passes the Following filter.
bool passesFollowingFilter(String? sportId, Set<String>? followedSportIds) {
  if (followedSportIds == null || followedSportIds.isEmpty) return true;
  if (sportId == null || sportId.trim().isEmpty) return true; // untagged
  return followedSportIds.contains(sportId.trim().toLowerCase());
}

/// Client-side filter for feeds whose rows come from an RPC.
List<T> filterByFollowedSports<T>(
  List<T> items,
  Set<String>? followedSportIds,
  String? Function(T item) sportIdOf,
) {
  if (followedSportIds == null || followedSportIds.isEmpty) return items;
  return items
      .where((i) => passesFollowingFilter(sportIdOf(i), followedSportIds))
      .toList();
}

/// PostgREST `or=` expression applying the filter inside a `posts` query
/// (keeps server-side pagination intact). Returns `null` for "no filter".
String? followedSportsOrFilter(Set<String>? followedSportIds) {
  if (followedSportIds == null || followedSportIds.isEmpty) return null;
  final ids = followedSportIds.toList()..sort();
  return 'sport_id.is.null,sport_id.in.(${ids.join(',')})';
}

/// Reads the signed-in viewer's Following (`profiles.interests`) from their
/// oldest active profile. Any failure returns `null` → unfiltered feed, so a
/// lookup problem can never empty or break a feed.
Future<Set<String>?> loadViewerFollowedSportIds(SupabaseClient db) async {
  try {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return null;
    final rows = await db
        .from(SupabaseConfig.usersTable)
        .select('interests')
        .eq('user_id', uid)
        .eq('is_active', true)
        .order('created_at', ascending: true)
        .limit(1);
    if (rows.isEmpty) return null;
    return parseFollowedSportIds(rows.first['interests']);
  } catch (_) {
    return null;
  }
}
