import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/language_detector.dart';
import '../models/social/comment.dart';
import '../models/social/post.dart';
import '../models/social/post_create_request.dart';
import 'base_repository.dart';
import 'post_repository.dart';

/// Concrete [PostRepository] backed by Supabase.
///
/// All visibility filtering is handled by RLS + `can_view_post()` at the
/// database level. This repository intentionally keeps queries minimal.
class PostRepositoryImpl extends BaseRepository implements PostRepository {
  PostRepositoryImpl(super.svc);
  SupabaseClient get _db => svc.client;

  // ── In-memory enrichment (no FK joins required) ─────────────────

  /// Batch-fetch sport and vibe rows referenced by [rows] via their
  /// `sport_id` / `vibe_id` columns, then backfill `sport` (text) and
  /// `post_vibes` (synthetic junction shape) so [Post.fromJson] works.
  Future<List<Map<String, dynamic>>> _enrichRows(
    List<Map<String, dynamic>> rows,
  ) async {
    // Collect unique non-null IDs.
    final sportIds = <String>{};
    final vibeIds = <String>{};
    final profileIds = <String>{};
    for (final r in rows) {
      final sid = r['sport_id'];
      final vid = r['vibe_id'];
      final pid = r['author_profile_id'];
      if (sid is String && sid.isNotEmpty) sportIds.add(sid);
      if (vid is String && vid.isNotEmpty) vibeIds.add(vid);
      if (pid is String && pid.isNotEmpty) profileIds.add(pid);
    }

    // Batch-fetch author avatars, usernames, and primary_sport from profiles.
    final Map<String, Map<String, dynamic>> profilesMap = {};
    final primarySportKeys = <String>{};
    if (profileIds.isNotEmpty) {
      final profileRows = await _db
          .from('profiles')
          .select('id, avatar_url, username, primary_sport')
          .inFilter('id', profileIds.toList());
      for (final p in profileRows) {
        profilesMap[p['id'] as String] = p;
        // Collect primary_sport keys (text, not UUID) for a separate lookup.
        final ps = p['primary_sport'];
        if (ps is String && ps.isNotEmpty) primarySportKeys.add(ps);
      }
    }

    // Batch-fetch referenced sports by UUID (post sport_id).
    final Map<String, Map<String, dynamic>> sportsMap = {};
    if (sportIds.isNotEmpty) {
      final sportRows = await _db
          .from('sports')
          .select('id, name_en, emoji, sport_key, category')
          .inFilter('id', sportIds.toList());
      for (final s in sportRows) {
        sportsMap[s['id'] as String] = s;
      }
    }

    // Batch-fetch sports by sport_key for profile primary_sport resolution.
    final Map<String, Map<String, dynamic>> sportKeyMap = {};
    if (primarySportKeys.isNotEmpty) {
      final keyRows = await _db
          .from('sports')
          .select('id, name_en, emoji, sport_key, category')
          .inFilter('sport_key', primarySportKeys.toList());
      for (final s in keyRows) {
        final key = s['sport_key'];
        if (key is String) sportKeyMap[key] = s;
      }
    }

    // Batch-fetch referenced vibes.
    final Map<String, Map<String, dynamic>> vibesMap = {};
    if (vibeIds.isNotEmpty) {
      final vibeRows = await _db
          .from('vibes')
          .select('id, key, label_en, label_ar, emoji, color_hex')
          .inFilter('id', vibeIds.toList());
      for (final v in vibeRows) {
        vibesMap[v['id'] as String] = v;
      }
    }

    return rows
        .map(
          (raw) =>
              _enrichRow(raw, sportsMap, vibesMap, profilesMap, sportKeyMap),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _enrichCommentRows(
    List<Map<String, dynamic>> rows,
  ) async {
    final profileIds = <String>{};
    for (final row in rows) {
      final profileId = row['author_profile_id'];
      if (profileId is String && profileId.isNotEmpty) {
        profileIds.add(profileId);
      }
    }

    if (profileIds.isEmpty) {
      return rows;
    }

    final profilesMap = <String, Map<String, dynamic>>{};
    final profileRows = await _db
        .from('profiles')
        .select('id, display_name, avatar_url')
        .inFilter('id', profileIds.toList());

    for (final profileRow in profileRows) {
      profilesMap[profileRow['id'] as String] = Map<String, dynamic>.from(
        profileRow,
      );
    }

    return rows.map((raw) {
      final row = Map<String, dynamic>.from(raw);
      final authorProfileId = row['author_profile_id'];
      if (authorProfileId is String && authorProfileId.isNotEmpty) {
        final authorProfile = profilesMap[authorProfileId];
        if (authorProfile != null) {
          row['author_display_name'] =
              authorProfile['display_name'] ?? row['author_display_name'];
          row['author_avatar_url'] =
              authorProfile['avatar_url'] ?? row['author_avatar_url'];
        }
      }
      return row;
    }).toList();
  }

  /// Enrich a single row using pre-fetched lookup maps.
  static Map<String, dynamic> _enrichRow(
    Map<String, dynamic> raw,
    Map<String, Map<String, dynamic>> sportsMap,
    Map<String, Map<String, dynamic>> vibesMap,
    Map<String, Map<String, dynamic>> profilesMap,
    Map<String, Map<String, dynamic>> sportKeyMap,
  ) {
    final row = Map<String, dynamic>.from(raw);

    // Inject author avatar_url and username from the profiles batch lookup.
    final authorProfileId = row['author_profile_id'];
    if (authorProfileId is String && authorProfileId.isNotEmpty) {
      final authorProfile = profilesMap[authorProfileId];
      if (authorProfile != null) {
        row['author_avatar_url'] ??= authorProfile['avatar_url'];
        row['author_username'] ??= authorProfile['username'];

        // Resolve author's primary sport emoji via sport_key lookup.
        final primarySportKey = authorProfile['primary_sport'];
        if (primarySportKey is String && primarySportKey.isNotEmpty) {
          final sportRef = sportKeyMap[primarySportKey];
          if (sportRef != null) {
            row['author_sport_emoji'] = sportRef['emoji'];
          }
        }
      }
    }

    // Backfill sport display text from lookup.
    if (row['sport'] == null) {
      final sid = row['sport_id'];
      if (sid is String) {
        final sportRef = sportsMap[sid];
        if (sportRef != null) {
          final name = sportRef['name_en'];
          final emoji = sportRef['emoji'];
          if (name != null) {
            row['sport'] = emoji != null ? '$emoji $name' : name;
          }
        }
      }
    }

    // Synthesise post_vibes for _vibesFromJson.
    final vid = row['vibe_id'];
    if (vid is String) {
      final vibeRef = vibesMap[vid];
      if (vibeRef != null) {
        row['post_vibes'] = [
          {'vibe': vibeRef},
        ];
      } else {
        row['post_vibes'] = <dynamic>[];
      }
    } else {
      row['post_vibes'] = <dynamic>[];
    }

    return row;
  }

  Future<List<Map<String, dynamic>>> _attachOriginalPosts(
    List<Map<String, dynamic>> rows,
  ) async {
    for (final row in rows) {
      if (row['origin_type'] != 'repost' || row['origin_id'] == null) {
        row['original_post'] = null;
      }
    }

    final repostRows = rows
        .where(
          (row) => row['origin_type'] == 'repost' && row['origin_id'] != null,
        )
        .toList();

    if (repostRows.isEmpty) {
      return rows;
    }

    final originIds = repostRows
        .map((row) => row['origin_id'] as String)
        .toSet()
        .toList();

    final originalRows = await _db
        .from('posts')
        .select()
        .inFilter('id', originIds)
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false);

    if (originalRows.isEmpty) {
      return rows;
    }

    final enrichedOriginalRows = await _enrichRows(originalRows);
    final originalById = {
      for (final row in enrichedOriginalRows) row['id'] as String: row,
    };

    for (final repostRow in repostRows) {
      final original = originalById[repostRow['origin_id'] as String];
      if (original != null) {
        repostRow['original_post'] = original;
      }
    }

    return rows;
  }

  Future<List<Post>> _fetchPostsByIds(
    List<String> postIds, {
    String? sportId,
  }) async {
    if (postIds.isEmpty) {
      return const <Post>[];
    }

    var query = _db
        .from('posts')
        .select()
        .inFilter('id', postIds)
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false);

    if (sportId != null && sportId.isNotEmpty) {
      query = query.eq('sport_id', sportId);
    }

    final rows = await query;
    final enriched = await _enrichRows(rows);
    final postsById = {
      for (final row in enriched) (row['id'] as String): Post.fromJson(row),
    };

    return postIds
        .where(postsById.containsKey)
        .map((postId) => postsById[postId]!)
        .toList();
  }

  /// Resolve the `profiles.id` for the currently authenticated user.
  ///
  /// Mirrors [AuthService.getUserProfile] selection rules:
  /// - filters `is_active = true`
  /// - optionally filters by `persona_type`
  /// - returns the oldest matching active profile
  Future<String> _profileId({String? personaType}) async {
    final uid = svc.authUserId()!;

    Future<List<dynamic>> fetch({String? personaTypeFilter}) async {
      var query = _db
          .from('profiles')
          .select('id')
          .eq('user_id', uid)
          .eq('is_active', true);
      if (personaTypeFilter != null) {
        query = query.eq('persona_type', personaTypeFilter);
      }
      return await query.order('created_at', ascending: true).limit(1);
    }

    var rows = await fetch(personaTypeFilter: personaType);
    if (rows.isEmpty && personaType != null) {
      rows = await fetch();
    }

    if (rows.isEmpty) {
      throw Exception('No active profile found for current user');
    }

    final row = rows.first;
    return row['id'] as String;
  }

  // ── Feeds ──────────────────────────────────────────────────────────

  @override
  Future<Result<List<Post>, Failure>> getHomeFeed({
    int limit = 20,
    int offset = 0,
  }) => guard(() async {
    final rows = await _db
        .from('posts')
        .select()
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    final enriched = await _enrichRows(rows);
    final hydrated = await _attachOriginalPosts(enriched);
    return hydrated.map((r) => Post.fromJson(r)).toList();
  });

  @override
  Future<Result<List<Post>, Failure>> getCircleFeed({
    required String circleId,
    int limit = 20,
    int offset = 0,
  }) => guard(() async {
    // Join through the post_circles junction table.
    final rows = await _db
        .from('post_circles')
        .select('posts(*)')
        .eq('circle_id', circleId)
        .order('created_at', ascending: false, referencedTable: 'posts')
        .range(offset, offset + limit - 1);
    final postRows = rows
        .map(
          (r) => Map<String, dynamic>.from(r['posts'] as Map<String, dynamic>),
        )
        .toList();
    final enriched = await _enrichRows(postRows);
    final hydrated = await _attachOriginalPosts(enriched);
    return hydrated.map((r) => Post.fromJson(r)).toList();
  });

  @override
  Future<Result<List<Post>, Failure>> getSquadFeed({
    required String squadId,
    int limit = 20,
    int offset = 0,
  }) => guard(() async {
    final rows = await _db
        .from('post_squads')
        .select('posts(*)')
        .eq('squad_id', squadId)
        .order('created_at', ascending: false, referencedTable: 'posts')
        .range(offset, offset + limit - 1);
    final postRows = rows
        .map(
          (r) => Map<String, dynamic>.from(r['posts'] as Map<String, dynamic>),
        )
        .toList();
    final enriched = await _enrichRows(postRows);
    final hydrated = await _attachOriginalPosts(enriched);
    return hydrated.map((r) => Post.fromJson(r)).toList();
  });

  @override
  Future<Result<List<Post>, Failure>> getUserPosts({
    required String profileId,
    int limit = 20,
    int offset = 0,
  }) => guard(() async {
    final rows = await _db
        .from('posts')
        .select()
        .eq('author_profile_id', profileId)
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false)
        .neq('origin_type', 'repost')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final enriched = await _enrichRows(rows);
    return enriched.map((r) => Post.fromJson(r)).toList();
  });

  @override
  Future<Result<List<Post>, Failure>> getUserPostsBySport({
    required String profileId,
    required String sportId,
    int limit = 20,
    int offset = 0,
  }) => guard(() async {
    final rows = await _db
        .from('posts')
        .select()
        .eq('author_profile_id', profileId)
        .eq('sport_id', sportId)
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final enriched = await _enrichRows(rows);
    return enriched.map((r) => Post.fromJson(r)).toList();
  });

  @override
  Future<Result<List<Post>, Failure>> getCommentedPostsBySport({
    required String profileId,
    required String sportId,
    int limit = 20,
    int offset = 0,
  }) => guard(() async {
    final rows = await _db
        .from('post_comments')
        .select('post_id, created_at')
        .eq('author_profile_id', profileId)
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false)
        .order('created_at', ascending: false)
        .range(0, (limit + offset) * 3);

    final orderedIds = <String>[];
    final seen = <String>{};

    for (final row in rows) {
      final postId = row['post_id'];
      if (postId is! String || postId.isEmpty || seen.contains(postId)) {
        continue;
      }
      seen.add(postId);
      orderedIds.add(postId);
    }

    final posts = await _fetchPostsByIds(orderedIds, sportId: sportId);
    final start = offset.clamp(0, posts.length);
    final end = (start + limit).clamp(0, posts.length);
    return posts.sublist(start, end);
  });

  @override
  Future<Result<List<Post>, Failure>> getReactedPostsBySport({
    required String profileId,
    required String sportId,
    int limit = 20,
    int offset = 0,
  }) => guard(() async {
    final rows = await _db
        .from('post_reactions')
        .select('post_id, created_at')
        .eq('actor_profile_id', profileId)
        .order('created_at', ascending: false)
        .range(0, (limit + offset) * 3);

    final orderedIds = <String>[];
    final seen = <String>{};

    for (final row in rows) {
      final postId = row['post_id'];
      if (postId is! String || postId.isEmpty || seen.contains(postId)) {
        continue;
      }
      seen.add(postId);
      orderedIds.add(postId);
    }

    final posts = await _fetchPostsByIds(orderedIds, sportId: sportId);
    final start = offset.clamp(0, posts.length);
    final end = (start + limit).clamp(0, posts.length);
    return posts.sublist(start, end);
  });

  @override
  Future<Result<List<Post>, Failure>> getUserLikedPosts({
    required String profileId,
    int limit = 20,
    int offset = 0,
  }) => guard(() async {
    final rows = await _db
        .from('post_likes')
        .select('post_id, created_at')
        .eq('profile_id', profileId)
        .order('created_at', ascending: false)
        .range(0, (limit + offset) * 3);

    final orderedIds = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      final postId = row['post_id'];
      if (postId is! String || postId.isEmpty || seen.contains(postId)) {
        continue;
      }
      seen.add(postId);
      orderedIds.add(postId);
    }

    final posts = await _fetchPostsByIds(orderedIds);
    final start = offset.clamp(0, posts.length);
    final end = (start + limit).clamp(0, posts.length);
    return posts.sublist(start, end);
  });

  @override
  Future<Result<List<Post>, Failure>> getUserCommentedPosts({
    required String profileId,
    int limit = 20,
    int offset = 0,
  }) => guard(() async {
    final rows = await _db
        .from('post_comments')
        .select('post_id, created_at')
        .eq('author_profile_id', profileId)
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false)
        .order('created_at', ascending: false)
        .range(0, (limit + offset) * 3);

    final orderedIds = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      final postId = row['post_id'];
      if (postId is! String || postId.isEmpty || seen.contains(postId)) {
        continue;
      }
      seen.add(postId);
      orderedIds.add(postId);
    }

    final posts = await _fetchPostsByIds(orderedIds);
    final start = offset.clamp(0, posts.length);
    final end = (start + limit).clamp(0, posts.length);
    return posts.sublist(start, end);
  });

  @override
  Future<Result<List<Post>, Failure>> getUserReposts({
    required String profileId,
    int limit = 20,
    int offset = 0,
  }) => guard(() async {
    final rows = await _db
        .from('post_reposts')
        .select('original_post_id, created_at')
        .eq('reposter_profile_id', profileId)
        .order('created_at', ascending: false)
        .range(0, (limit + offset) * 3);

    final orderedIds = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      final postId = row['original_post_id'];
      if (postId is! String || postId.isEmpty || seen.contains(postId)) {
        continue;
      }
      seen.add(postId);
      orderedIds.add(postId);
    }

    final posts = await _fetchPostsByIds(orderedIds);
    final start = offset.clamp(0, posts.length);
    final end = (start + limit).clamp(0, posts.length);
    return posts.sublist(start, end);
  });

  @override
  Future<Result<List<Post>, Failure>> getHashtagFeed({
    required String hashtag,
    int limit = 20,
    int offset = 0,
  }) => guard(() async {
    final normalised = hashtag
        .trim()
        .replaceFirst(RegExp(r'^#+'), '')
        .toLowerCase();
    if (normalised.isEmpty) return const <Post>[];

    final hashtagRows = await _db
        .from('hashtags')
        .select('id')
        .eq('tag', normalised)
        .limit(1);

    if (hashtagRows.isEmpty) return const <Post>[];
    final hashtagId = hashtagRows.first['id'] as String;

    final rows = await _db
        .from('post_hashtags')
        .select('post_id, created_at')
        .eq('hashtag_id', hashtagId)
        .order('created_at', ascending: false)
        .range(0, (limit + offset) * 3);

    final orderedIds = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      final postId = row['post_id'];
      if (postId is! String || postId.isEmpty || seen.contains(postId)) {
        continue;
      }
      seen.add(postId);
      orderedIds.add(postId);
    }

    final posts = await _fetchPostsByIds(orderedIds);
    final start = offset.clamp(0, posts.length);
    final end = (start + limit).clamp(0, posts.length);
    return posts.sublist(start, end);
  });

  @override
  Future<Result<Post, Failure>> getPost(String postId) => guard(() async {
    final row = await _db.from('posts').select().eq('id', postId).single();
    final enriched = await _enrichRows([row]);
    final hydrated = await _attachOriginalPosts(enriched);

    return Post.fromJson(hydrated.first);
  });

  // ── Write ──────────────────────────────────────────────────────────

  @override
  Future<Result<Post, Failure>> createPost({
    required String kind,
    required String visibility,
    String? postType,
    String? originType,
    String? body,
    String? sport,
    List<dynamic>? media,
    List<String>? tags,
    String? gameId,
    String? locationTagId,
    String? primaryVibeId,
    List<String>? vibeIds,
    List<String>? circleIds,
    List<String>? squadIds,
    List<String>? mentionProfileIds,
  }) => guard(() async {
    // Use RPC to bypass RLS timing issues — the SECURITY DEFINER function
    // resolves profile, inserts the post + all junction rows, and returns
    // the full post JSON with vibes.
    final res = await _db.rpc(
      'create_post',
      params: {
        'p_kind': kind,
        'p_visibility': visibility,
        if (postType != null) 'p_post_type': postType,
        if (originType != null) 'p_origin_type': originType,
        if (body != null) 'p_body': body,
        if (sport != null) 'p_sport': sport,
        'p_media': media ?? [],
        'p_tags': tags ?? [],
        if (gameId != null) 'p_game_id': gameId,
        if (locationTagId != null) 'p_location_tag_id': locationTagId,
        if (primaryVibeId != null) 'p_primary_vibe_id': primaryVibeId,
        'p_vibe_ids': vibeIds ?? [],
        if (circleIds != null) 'p_circle_ids': circleIds,
        if (squadIds != null) 'p_squad_ids': squadIds,
        if (mentionProfileIds != null)
          'p_mention_profile_ids': mentionProfileIds,
      },
    );
    return Post.fromJson(res as Map<String, dynamic>);
  });

  @override
  Future<Result<Post, Failure>> insertPost({
    String? body,
    String? vibeId,
    String? sportId,
    String visibility = 'public',
    String postType = 'moment',
    String? personaType,
    String? circleId,
    String? locationTagId,
    String? locationName,
    double? geoLat,
    double? geoLng,
  }) async {
    // Step 1 — Verify authenticated session exists.
    final initialSession = _db.auth.currentSession;
    if (initialSession == null) {
      return const Err(UnauthenticatedFailure());
    }

    // Proactively refresh if token is about to expire (within 30s).
    var activeSession = initialSession;
    final expiresAt = activeSession.expiresAt;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiresAt != null && expiresAt - now < 30) {
      try {
        final refreshed = await _db.auth.refreshSession();
        if (refreshed.session != null) {
          activeSession = refreshed.session!;
        }
      } catch (_) {
        // If refresh fails, continue with existing session — guard() will
        // retry on JWT-expired errors.
      }
    }

    print('SESSION USER ID: ${activeSession.user.id}');
    print('ACCESS TOKEN EXISTS: ${activeSession.accessToken.isNotEmpty}');
    print(
      'TOKEN EXPIRES AT: ${DateTime.fromMillisecondsSinceEpoch((activeSession.expiresAt ?? 0) * 1000)}',
    );
    print('CURRENT TIME: ${DateTime.now()}');

    final isCircleVisibility = visibility == 'circle';
    final extractedTags = body != null ? extractHashtags(body) : <String>[];
    final authorUserId = activeSession.user.id;
    if (isCircleVisibility && (circleId == null || circleId.isEmpty)) {
      return const Err(
        Failure(
          category: FailureCode.validation,
          message: 'Pick a circle to post to.',
        ),
      );
    }

    // Step 2 — Insert the post. DB triggers handle author columns:
    //   author_user_id      → trg_set_post_author sets auth.uid()
    //   author_profile_id   → trg_posts_fill_author_display_name
    //   author_display_name → trg_posts_fill_author_display_name
    return guard(() async {
      // Circle visibility posts must be created + linked in one DB transaction.
      // The `create_post` RPC is the canonical path and satisfies the DB
      // validation rules around `posts.visibility` and `post_circles`.
      if (isCircleVisibility) {
        // Some DB setups require the author profile to be a circle member.
        // Ensure the current author profile is a member of the selected circle
        // before invoking the RPC.
        final pid = await _profileId(personaType: personaType);
        await _db.from('circle_members').upsert({
          'circle_id': circleId,
          'member_profile_id': pid,
        }, onConflict: 'circle_id,member_profile_id');

        String? sportKey;
        if (sportId != null && sportId.isNotEmpty) {
          final sportRow = await _db
              .from('sports')
              .select('sport_key')
              .eq('id', sportId)
              .maybeSingle();
          sportKey = sportRow?['sport_key'] as String?;
        }

        final res = await _db.rpc(
          'create_post',
          params: {
            'p_kind': 'moment',
            'p_visibility': 'circle',
            'p_post_type': postType,
            'p_origin_type': 'manual',
            if (body != null) 'p_body': body,
            if (sportKey != null) 'p_sport': sportKey,
            'p_media': <dynamic>[],
            'p_tags': extractedTags,
            if (vibeId != null) 'p_primary_vibe_id': vibeId,
            'p_vibe_ids': vibeId != null ? <String>[vibeId] : <String>[],
            'p_circle_ids': <String>[circleId!],
          },
        );
        final post = Post.fromJson(res as Map<String, dynamic>);
        if (extractedTags.isNotEmpty) {
          await _linkHashtags(
            postId: post.id,
            tags: extractedTags,
            sportId: sportId,
            authorUserId: authorUserId,
          );
        }
        return post;
      }

      final data = <String, dynamic>{
        if (body != null) 'body': body,
        'visibility': visibility,
        'kind': 'moment',
        'post_type': postType,
        'origin_type': 'manual',
        'content_class': 'social',
        'is_active': true,
        if (vibeId != null) 'vibe_id': vibeId,
        if (sportId != null) 'sport_id': sportId,
        if (locationTagId != null) 'location_tag_id': locationTagId,
        if (locationName != null) 'location_name': locationName,
        if (geoLat != null) 'geo_lat': geoLat,
        if (geoLng != null) 'geo_lng': geoLng,
      };

      print('INSERT PAYLOAD: $data');

      final row = await _db.from('posts').insert(data).select().single();
      final post = Post.fromJson(row);
      if (extractedTags.isNotEmpty) {
        await _linkHashtags(
          postId: post.id,
          tags: extractedTags,
          sportId: sportId,
          authorUserId: authorUserId,
        );
      }
      return post;
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> listVibes() =>
      guard(() async {
        final rows = await _db
            .from('vibes')
            .select('id, key, label_en, label_ar, emoji, color_hex')
            .order('label_en');
        return rows.cast<Map<String, dynamic>>();
      });

  // ── Full Post Creation ─────────────────────────────────────────────

  @override
  Future<Result<Post, Failure>> createFullPost(
    PostCreateRequest request,
  ) async {
    final session = _db.auth.currentSession;
    if (session == null) {
      return const Err(UnauthenticatedFailure());
    }

    // Proactively refresh token if near expiry.
    var activeSession = session;
    final expiresAt = activeSession.expiresAt;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiresAt != null && expiresAt - nowSec < 30) {
      try {
        final refreshed = await _db.auth.refreshSession();
        if (refreshed.session != null) {
          activeSession = refreshed.session!;
        }
      } catch (_) {}
    }

    return guard(() async {
      // Resolve author profile and user IDs (RLS-safe).
      final authorProfileId = await _profileId();
      final authorUserId = activeSession.user.id;

      final payload = request.toInsertPayload(
        authorProfileId: authorProfileId,
        authorUserId: authorUserId,
      );

      // Circle-visibility requires the create_post RPC for atomic linking.
      if (request.visibility.name == 'circle' && request.circleId != null) {
        // Ensure membership first.
        await _db.from('circle_members').upsert({
          'circle_id': request.circleId,
          'member_profile_id': authorProfileId,
        }, onConflict: 'circle_id,member_profile_id');

        // Resolve sport_key from sport_id for RPC compatibility.
        String? sportKey;
        if (request.sportId != null) {
          final sportRow = await _db
              .from('sports')
              .select('sport_key')
              .eq('id', request.sportId!)
              .maybeSingle();
          sportKey = sportRow?['sport_key'] as String?;
        }

        final res = await _db.rpc(
          'create_post',
          params: {
            'p_kind': request.kind.name,
            'p_visibility': 'circle',
            'p_post_type': request.kind.defaultPostType.dbValue,
            'p_origin_type': request.originType.name,
            if (request.body != null) 'p_body': request.body,
            if (sportKey != null) 'p_sport': sportKey,
            'p_media': request.media ?? <dynamic>[],
            'p_tags': request.tags ?? <String>[],
            if (request.vibeId != null) 'p_primary_vibe_id': request.vibeId,
            'p_vibe_ids': request.vibeId != null
                ? [request.vibeId!]
                : <String>[],
            'p_circle_ids': [request.circleId!],
          },
        );
        final post = Post.fromJson(res as Map<String, dynamic>);
        // Link hashtags to public.hashtags / post_hashtags tables.
        await _linkHashtags(
          postId: post.id,
          tags: request.tags,
          sportId: request.sportId,
          authorUserId: authorUserId,
        );
        return post;
      }

      // Squad-visibility: insert post + link to post_squads junction.
      if (request.visibility.name == 'squad' && request.squadId != null) {
        final row = await _db.from('posts').insert(payload).select().single();
        // Link to squad junction table.
        await _db.from('post_squads').insert({
          'post_id': row['id'],
          'squad_id': request.squadId,
        });
        final post = Post.fromJson(row);
        await _linkHashtags(
          postId: post.id,
          tags: request.tags,
          sportId: request.sportId,
          authorUserId: authorUserId,
        );
        return post;
      }

      // Standard insert path.
      final row = await _db.from('posts').insert(payload).select().single();
      final post = Post.fromJson(row);
      await _linkHashtags(
        postId: post.id,
        tags: request.tags,
        sportId: request.sportId,
        authorUserId: authorUserId,
      );
      return post;
    });
  }

  // ── Hashtag linking ────────────────────────────────────────────────

  /// Upsert each tag into `public.hashtags` and create junction rows
  /// in `public.post_hashtags`.
  ///
  /// Runs best-effort — hashtag linking failures do not fail the post.
  Future<void> _linkHashtags({
    required String postId,
    List<String>? tags,
    String? sportId,
    String? authorUserId,
  }) async {
    if (tags == null || tags.isEmpty) return;

    for (final tag in tags) {
      try {
        final normalised = tag.toLowerCase().trim().replaceFirst(
          RegExp(r'^#+'),
          '',
        );
        if (normalised.isEmpty) continue;

        Map<String, dynamic>? existing;
        try {
          existing = await _db
              .from('hashtags')
              .select('id')
              .eq('tag', normalised)
              .maybeSingle();
        } catch (_) {
          existing = null;
        }

        if (existing == null) {
          try {
            existing = await _db
                .from('hashtags')
                .select('id')
                .eq('slug', normalised)
                .maybeSingle();
          } catch (_) {
            existing = null;
          }
        }

        String hashtagId;
        if (existing != null) {
          hashtagId = existing['id'] as String;
        } else {
          Map<String, dynamic>? row;

          // Try minimal insert first (most schema-compatible).
          try {
            row = await _db
                .from('hashtags')
                .insert({'tag': normalised})
                .select('id')
                .single();
          } catch (_) {}

          // Fallback: schemas that rely on slug.
          if (row == null) {
            try {
              row = await _db
                  .from('hashtags')
                  .insert({'slug': normalised})
                  .select('id')
                  .single();
            } catch (_) {}
          }

          // Fallback: schemas that expect both.
          row ??= await _db
              .from('hashtags')
              .insert({'tag': normalised, 'slug': normalised})
              .select('id')
              .single();

          hashtagId = row['id'] as String;
        }

        // Insert junction row (composite PK prevents duplicates).
        await _db.from('post_hashtags').upsert({
          'post_id': postId,
          'hashtag_id': hashtagId,
          if (sportId != null) 'sport_id': sportId,
          if (authorUserId != null) 'created_by': authorUserId,
        }, onConflict: 'post_id,hashtag_id');
      } catch (e) {
        if (e is PostgrestException && e.code == '42703') {
          rethrow;
        }
        // Best-effort per tag — don't fail post creation.
        // ignore: avoid_print
        print('[PostRepo] _linkHashtags warning for "$tag": $e');
      }
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> searchVenues(
    String query,
  ) => guard(() async {
    final rows = await _db
        .from('venues')
        .select('id, name_en, city, latitude, longitude')
        .ilike('name_en', '%$query%')
        .limit(20)
        .order('name_en');
    return rows.cast<Map<String, dynamic>>();
  });

  @override
  Future<Result<List<Map<String, dynamic>>, Failure>> searchGames(
    String query,
  ) => guard(() async {
    final rows = await _db
        .from('games')
        .select('id, title, sport, game_type, start_at, end_at')
        .ilike('title', '%$query%')
        .eq('is_cancelled', false)
        .limit(20)
        .order('start_at', ascending: false);
    return rows.cast<Map<String, dynamic>>();
  });

  @override
  Future<Result<Unit, Failure>> deletePost(String postId) => guard(() async {
    await _db.from('posts').update({'is_deleted': true}).eq('id', postId);
    return const Unit();
  });

  // ── Likes ──────────────────────────────────────────────────────────

  @override
  Future<Result<Unit, Failure>> likePost(String postId) => guard(() async {
    final uid = svc.authUserId()!;
    final pid = await _profileId();
    await _db.from('post_likes').upsert({
      'post_id': postId,
      'user_id': uid,
      'profile_id': pid,
    });
    return const Unit();
  });

  @override
  Future<Result<Unit, Failure>> unlikePost(String postId) => guard(() async {
    final uid = svc.authUserId()!;
    await _db
        .from('post_likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', uid);
    return const Unit();
  });

  @override
  Future<Result<bool, Failure>> hasLiked(String postId) => guard(() async {
    final uid = svc.authUserId()!;
    final rows = await _db
        .from('post_likes')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', uid)
        .limit(1);
    return rows.isNotEmpty;
  });

  // ── Comments ───────────────────────────────────────────────────────

  @override
  Future<Result<List<PostComment>, Failure>> getComments({
    required String postId,
    int limit = 50,
    int offset = 0,
  }) => guard(() async {
    final rows = await _db
        .from('post_comments')
        .select(
          '*, profiles!post_comments_author_profile_id_fkey(display_name)',
        )
        .eq('post_id', postId)
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false)
        .order('created_at')
        .range(offset, offset + limit - 1);
    // Flatten the joined profile into author_display_name.
    final flattened = rows.map((r) {
      final row = Map<String, dynamic>.from(r);
      final profile = row.remove('profiles');
      if (profile is Map && profile['display_name'] != null) {
        row['author_display_name'] = profile['display_name'];
      }
      return row;
    }).toList();
    final enriched = await _enrichCommentRows(flattened);
    return enriched.map((r) => PostComment.fromJson(r)).toList();
  });

  @override
  Future<Result<PostComment, Failure>> addComment({
    required String postId,
    required String body,
    String? parentCommentId,
    String? imageUrl,
    String? gifUrl,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) => guard(() async {
    final uid = svc.authUserId()!;
    final pid = await _profileId();
    final data = <String, dynamic>{
      'post_id': postId,
      'author_user_id': uid,
      'author_profile_id': pid,
      'body': body,
      if (parentCommentId != null) 'parent_comment_id': parentCommentId,
      if (imageUrl != null) 'image_url': imageUrl,
      if (gifUrl != null) 'gif_url': gifUrl,
      if (locationName != null) 'location_name': locationName,
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,
    };
    final row = await _db.from('post_comments').insert(data).select().single();
    return PostComment.fromJson(row);
  });

  @override
  Future<Result<Unit, Failure>> deleteComment(String commentId) =>
      guard(() async {
        await _db
            .from('post_comments')
            .update({'is_deleted': true})
            .eq('id', commentId);
        return const Unit();
      });

  // ── Reposts ─────────────────────────────────────────────────────────

  @override
  Future<Result<Unit, Failure>> repostPost(
    String postId, {
    String? commentary,
  }) => guard(() async {
    await _db.rpc(
      'rpc_repost_post',
      params: {'p_original_post_id': postId, 'p_quote_text': commentary},
    );
    return const Unit();
  });

  @override
  Future<Result<Unit, Failure>> undoRepost(String originalPostId) =>
      guard(() async {
        final uid = svc.authUserId()!;

        await _db
            .from('posts')
            .delete()
            .eq('origin_type', 'repost')
            .eq('origin_id', originalPostId)
            .eq('author_user_id', uid);

        await _db
            .from('post_reposts')
            .delete()
            .eq('original_post_id', originalPostId)
            .eq('reposter_user_id', uid);

        return const Unit();
      });

  @override
  Future<Result<bool, Failure>> hasReposted(String postId) => guard(() async {
    final uid = svc.authUserId()!;
    final rows = await _db
        .from('post_reposts')
        .select('id')
        .eq('original_post_id', postId)
        .eq('reposter_user_id', uid)
        .limit(1);
    return rows.isNotEmpty;
  });

  // ── Reactions ─────────────────────────────────────────────────────────

  @override
  Future<Result<Unit, Failure>> reactToPost(String postId, String vibeId) =>
      guard(() async {
        final uid = svc.authUserId()!;
        final pid = await _profileId();
        await _db.from('post_reactions').upsert({
          'post_id': postId,
          'actor_profile_id': pid,
          'vibe_id': vibeId,
          'actor_user_id': uid,
        });
        return const Unit();
      });

  @override
  Future<Result<Unit, Failure>> removeReaction(String postId, String vibeId) =>
      guard(() async {
        final pid = await _profileId();
        await _db
            .from('post_reactions')
            .delete()
            .eq('post_id', postId)
            .eq('actor_profile_id', pid)
            .eq('vibe_id', vibeId);
        return const Unit();
      });

  @override
  Future<Result<Set<String>, Failure>> getMyReactions(String postId) =>
      guard(() async {
        final pid = await _profileId();
        final rows = await _db
            .from('post_reactions')
            .select('vibe_id')
            .eq('post_id', postId)
            .eq('actor_profile_id', pid);
        return rows.map((r) => r['vibe_id'] as String).toSet();
      });

  // ── Views ───────────────────────────────────────────────────────────

  @override
  Future<Result<Unit, Failure>> recordView(String postId) => guard(() async {
    final uid = svc.authUserId()!;
    await _db.from('post_views').upsert({
      'post_id': postId,
      'viewer_user_id': uid,
    });
    return const Unit();
  });

  // ── Media Upload ────────────────────────────────────────────────────

  @override
  Future<Result<String, Failure>> uploadPostMedia(XFile file) =>
      _uploadToBucket(file, folder: 'posts');

  @override
  Future<Result<String, Failure>> uploadCommentMedia(XFile file) =>
      _uploadToBucket(file, folder: 'comments');

  Future<Result<String, Failure>> _uploadToBucket(
    XFile file, {
    required String folder,
  }) => guard(() async {
    final uid = svc.authUserId()!;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // On Flutter web, file.path is a blob URL so p.extension returns ''.
    // Prefer file.mimeType, then fall back to extension-based detection.
    final mimeFromType = file.mimeType;
    final ext = p.extension(file.path).toLowerCase();

    final contentType = mimeFromType?.isNotEmpty == true
        ? mimeFromType!
        : switch (ext) {
            '.jpg' || '.jpeg' => 'image/jpeg',
            '.png' => 'image/png',
            '.webp' => 'image/webp',
            '.gif' => 'image/gif',
            '.mp4' => 'video/mp4',
            '.mov' => 'video/quicktime',
            _ => 'image/jpeg', // safe default for images from picker
          };

    // Derive a stable extension for the file path from the resolved content type.
    final resolvedExt = ext.isNotEmpty
        ? ext
        : switch (contentType) {
            'image/jpeg' => '.jpg',
            'image/png' => '.png',
            'image/webp' => '.webp',
            'image/gif' => '.gif',
            'video/mp4' => '.mp4',
            'video/quicktime' => '.mov',
            _ => '.jpg',
          };

    // uid MUST be the first path segment so Storage RLS policies (which check
    // foldername(name)[1] = auth.uid()) continue to work.
    final filePath = '$uid/$folder/${timestamp}_media$resolvedExt';
    final bytes = await file.readAsBytes();

    await _db.storage
        .from(SupabaseConfig.postMediaBucket)
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    final publicUrl = _db.storage
        .from(SupabaseConfig.postMediaBucket)
        .getPublicUrl(filePath);

    return publicUrl;
  });
}
