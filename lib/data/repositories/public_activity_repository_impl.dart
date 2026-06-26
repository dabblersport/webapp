import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/data/repositories/public_activity_repository.dart';

class PublicActivityRepositoryImpl implements PublicActivityRepository {
  PublicActivityRepositoryImpl(this._db);

  final SupabaseClient _db;

  @override
  Future<Result<List<PublicActivity>, Failure>> fetchFollowingActivities({
    int limit = 20,
    int offset = 0,
  }) =>
      Result.guard(
        () async {
          final userId = _db.auth.currentUser?.id;
          if (userId == null) return const <PublicActivity>[];

          final profileRows = await _db
              .from('profiles')
              .select('id')
              .eq('user_id', userId)
              .limit(1) as List;
          if (profileRows.isEmpty) return const <PublicActivity>[];
          final myProfileId = profileRows.first['id'] as String;

          final followRows = await _db
              .from('profile_follows')
              .select('following_profile_id')
              .eq('follower_profile_id', myProfileId) as List;

          final followedIds = followRows
              .map((r) => r['following_profile_id'] as String)
              .toList();
          if (followedIds.isEmpty) return const <PublicActivity>[];

          return _fetchActivities(
            actorIds: followedIds,
            limit: limit,
            offset: offset,
          );
        },
        (e) => Failure.from(e),
      );

  @override
  Future<Result<List<PublicActivity>, Failure>> fetchUserActivities({
    required String profileId,
    int limit = 20,
    int offset = 0,
  }) =>
      Result.guard(
        () => _fetchActivities(
          profileId: profileId,
          limit: limit,
          offset: offset,
        ),
        (e) => Failure.from(e),
      );

  // ---------------------------------------------------------------------------

  Future<List<PublicActivity>> _fetchActivities({
    String? profileId,
    List<String>? actorIds,
    required int limit,
    required int offset,
  }) async {
    dynamic query = _db
        .from('public_activities')
        .select('id, activity_type, actor_profile_id, parent_activity_id, created_at')
        .not('actor_profile_id', 'is', null);

    if (profileId != null) {
      query = (query as dynamic).eq('actor_profile_id', profileId);
    } else if (actorIds != null && actorIds.isNotEmpty) {
      query = (query as dynamic).inFilter('actor_profile_id', actorIds);
    }

    final rows = await (query as dynamic)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1) as List;

    if (rows.isEmpty) return const [];

    // Batch-fetch actor profiles.
    final actorProfileIds = rows
        .map((r) => r['actor_profile_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final profileRows = await _db
        .from('profiles')
        .select('id, username, avatar_url')
        .inFilter('id', actorProfileIds) as List;

    final profileById = <String, Map<String, dynamic>>{
      for (final p in profileRows)
        p['id'] as String: Map<String, dynamic>.from(p as Map),
    };

    // Batch-fetch news titles for comment activities.
    final parentIds = rows
        .where((r) => r['activity_type'] == 'comment')
        .map((r) => r['parent_activity_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final newsById = <String, Map<String, dynamic>>{};
    if (parentIds.isNotEmpty) {
      try {
        final newsRows = await _db
            .from('published_news')
            .select('id, title, cover_image_url')
            .inFilter('id', parentIds) as List;
        for (final n in newsRows) {
          newsById[n['id'] as String] = Map<String, dynamic>.from(n as Map);
        }
      } catch (_) {}
    }

    final result = <PublicActivity>[];
    for (final row in rows) {
      final actorId = row['actor_profile_id'] as String?;
      if (actorId == null) continue;
      final profile = profileById[actorId];
      if (profile == null) continue;

      var activity = PublicActivity.fromRow(
        Map<String, dynamic>.from(row as Map),
        actorUsername: profile['username'] as String? ?? 'User',
        actorAvatarUrl: profile['avatar_url'] as String?,
      );

      final parentId = activity.parentActivityId;
      if (activity.activityType == PublicActivityType.comment &&
          parentId != null) {
        final news = newsById[parentId];
        if (news != null) {
          activity = activity.withTarget(
            targetTitle: PublicActivity.toStringMap(news['title']),
            targetCoverImageUrl: news['cover_image_url'] as String?,
            targetNewsId: news['id'] as String?,
          );
        }
      }

      result.add(activity);
    }

    return result;
  }
}
