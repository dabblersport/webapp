import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import '../models/social/comment.dart';
import '../models/social/post.dart';
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
    return enriched.map((r) => Post.fromJson(r)).toList();
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
    return rows
        .map((r) => Post.fromJson(r['posts'] as Map<String, dynamic>))
        .toList();
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
    return rows
        .map((r) => Post.fromJson(r['posts'] as Map<String, dynamic>))
        .toList();
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
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final enriched = await _enrichRows(rows);
    return enriched.map((r) => Post.fromJson(r)).toList();
  });

  @override
  Future<Result<Post, Failure>> getPost(String postId) => guard(() async {
    final row = await _db.from('posts').select().eq('id', postId).single();
    final enriched = await _enrichRows([row]);
    return Post.fromJson(enriched.first);
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
            'p_tags': <String>[],
            if (vibeId != null) 'p_primary_vibe_id': vibeId,
            'p_vibe_ids': vibeId != null ? <String>[vibeId] : <String>[],
            'p_circle_ids': <String>[circleId!],
          },
        );
        return Post.fromJson(res as Map<String, dynamic>);
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
      };

      print('INSERT PAYLOAD: $data');

      final row = await _db.from('posts').insert(data).select().single();
      return Post.fromJson(row);
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
    final enriched = rows.map((r) {
      final row = Map<String, dynamic>.from(r);
      final profile = row.remove('profiles');
      if (profile is Map && profile['display_name'] != null) {
        row['author_display_name'] = profile['display_name'];
      }
      return row;
    }).toList();
    return enriched.map((r) => PostComment.fromJson(r)).toList();
  });

  @override
  Future<Result<PostComment, Failure>> addComment({
    required String postId,
    required String body,
    String? parentCommentId,
  }) => guard(() async {
    final uid = svc.authUserId()!;
    final pid = await _profileId();
    final data = <String, dynamic>{
      'post_id': postId,
      'author_user_id': uid,
      'author_profile_id': pid,
      'body': body,
      if (parentCommentId != null) 'parent_comment_id': parentCommentId,
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
    final uid = svc.authUserId()!;
    final pid = await _profileId();
    await _db.from('post_reposts').insert({
      'original_post_id': postId,
      'reposter_user_id': uid,
      'reposter_profile_id': pid,
      if (commentary != null) 'commentary': commentary,
    });
    return const Unit();
  });

  @override
  Future<Result<Unit, Failure>> undoRepost(String repostId) => guard(() async {
    await _db.from('post_reposts').delete().eq('id', repostId);
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
}
