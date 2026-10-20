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

/// Fetches the `interests` row(s) of ONE profile: the viewer's active
/// profile whose `persona_type` is [personaType]. Injectable for tests.
typedef ActiveProfileInterestsFetch =
    Future<List<Map<String, dynamic>>> Function(
      String userId,
      String personaType,
    );

/// Following is PER PROFILE (per persona): resolves the Following of the
/// ACTIVE persona only. Returns `null` (no filter) when the user or the
/// active persona is unknown, the profile is missing, its interests are
/// NULL/empty, or the lookup fails. Never falls back to another persona.
Future<Set<String>?> loadFollowedSportIdsFor({
  required String? userId,
  required String? personaType,
  required ActiveProfileInterestsFetch fetch,
}) async {
  try {
    if (userId == null || personaType == null || personaType.isEmpty) {
      return null;
    }
    final rows = await fetch(userId, personaType);
    if (rows.isEmpty) return null;
    return parseFollowedSportIds(rows.first['interests']);
  } catch (_) {
    return null;
  }
}

/// Reads the signed-in viewer's Following (`profiles.interests`) from the
/// profile of the ACTIVE persona [personaType] (from `activePersonaProvider`).
/// Unknown persona or any failure returns `null` → unfiltered feed.
Future<Set<String>?> loadViewerFollowedSportIds(
  SupabaseClient db, {
  required String? personaType,
}) {
  String? uid;
  try {
    uid = db.auth.currentUser?.id;
  } catch (_) {
    uid = null;
  }
  return loadFollowedSportIdsFor(
    userId: uid,
    personaType: personaType,
    fetch: (userId, persona) async => List<Map<String, dynamic>>.from(
      await db
          .from(SupabaseConfig.usersTable)
          .select('interests')
          .eq('user_id', userId)
          .eq('is_active', true)
          .eq('persona_type', persona)
          .limit(1),
    ),
  );
}
