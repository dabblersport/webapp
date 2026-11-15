/// Followed sports (`profiles.interests`) and the Following feed match.
///
/// Mapping (verified against supabase/migrations/20260829080500_baseline_schema.sql):
/// - Followed sports = `profiles.interests`, type `uuid[]` — each element is a
///   `sports.id` UUID (written by `rpc_onboard_profile(p_interests uuid[])`
///   and the Profile > Sports screen). Dart reads it as `List<String>?`.
/// - A post's sport tag = `posts.sport_id`, type `uuid` (FK to `sports.id`);
///   Dart reads it as `Post.sportId` (`@JsonKey(name: 'sport_id')`).
/// - So the match is `posts.sport_id ∈ profiles.interests` — UUID to UUID.
///
/// KAN-955 (CEO 2026-11-16): only the Following tab uses followed sports.
/// For you, Nearby, Active and News show all recent posts, unfiltered. A
/// viewer whose interests are NULL or empty has no sport match, which never
/// empties a feed by error.
library;

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Normalises a raw `profiles.interests` value into a set of sport UUIDs.
///
/// Returns `null` (meaning "no followed sports") when the value is NULL, not
/// a list, or contains no usable id. UUIDs are lower-cased so a mixed-case
/// value still matches Postgres' canonical lower-case text form.
Set<String>? parseFollowedSportIds(Object? interests) {
  if (interests is! List) return null;
  final ids = <String>{
    for (final v in interests)
      if (v is String && v.trim().isNotEmpty) v.trim().toLowerCase(),
  };
  return ids.isEmpty ? null : ids;
}

/// KAN-955: PostgREST `or=` expression for the Following feed — a post whose
/// author is one of [followedProfileIds] OR whose sport is one of
/// [followedSportIds]. It is one query, so a post matching both comes back
/// once and `.range` pagination stays correct. When one set is empty only
/// the other is used; when both are empty it returns `null` and the caller
/// shows the empty state. Ids are sorted so the expression is stable.
String? followingFeedOrFilter(
  Iterable<String> followedProfileIds,
  Set<String>? followedSportIds,
) {
  final people = followedProfileIds.toSet().toList()..sort();
  final sports = (followedSportIds ?? const <String>{}).toList()..sort();
  final clauses = [
    if (people.isNotEmpty) 'author_profile_id.in.(${people.join(',')})',
    if (sports.isNotEmpty) 'sport_id.in.(${sports.join(',')})',
  ];
  return clauses.isEmpty ? null : clauses.join(',');
}

/// Fetches the `interests` row(s) of ONE profile: the viewer's active
/// profile whose `persona_type` is [personaType]. Injectable for tests.
typedef ActiveProfileInterestsFetch =
    Future<List<Map<String, dynamic>>> Function(
      String userId,
      String personaType,
    );

/// Followed sports are PER PROFILE (per persona): resolves those of the
/// ACTIVE persona only. Returns `null` (no sport match) when the user or the
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

/// Reads the signed-in viewer's followed sports (`profiles.interests`) from
/// the profile of the ACTIVE persona [personaType] (from
/// `activePersonaProvider`). Unknown persona or any failure returns `null`.
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
