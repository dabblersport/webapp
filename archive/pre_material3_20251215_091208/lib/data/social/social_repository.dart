import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:dabbler/data/models/social/post_model.dart';
import 'package:dabbler/utils/enums/social_enums.dart';

/// Unified repository for social posts, media, vibes and interactions.
///
/// This module follows the contract in `docs/social_model_dabbler.md`:
/// - posts.kind: 'moment' | 'dab' | 'kickin'
/// - identity: profiles.id (author_profile_id, profile_id, etc.)
/// - media: single JSON object in posts.media pointing to Supabase Storage.
class SocialRepository {
  SocialRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _mediaBucket = 'post-media';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String?> _getCurrentProfileId() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final res = await _client
        .from('profiles')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (res == null) return null;
    return res['id'] as String;
  }

  Future<void> _checkForDuplicatePost({
    required String authorUserId,
    required String body,
    required bool hasMedia,
  }) async {
    // Same logic as SocialService._checkForDuplicatePost but kept internal here.
    final now = DateTime.now();
    final recentWindow = now.subtract(const Duration(minutes: 5));

    final duplicate = await _client
        .from('posts')
        .select('id, created_at')
        .eq('author_user_id', authorUserId)
        .eq('body', body)
        .gte('created_at', recentWindow.toIso8601String())
        .limit(1);

    if (duplicate.isNotEmpty) {
      throw Exception(
        'You recently posted the same content. Please wait before posting again.',
      );
    }

    final rapidPosts = await _client
        .from('posts')
        .select('id, created_at')
        .eq('author_user_id', authorUserId)
        .gte(
          'created_at',
          now.subtract(const Duration(minutes: 1)).toIso8601String(),
        )
        .limit(3);

    if (rapidPosts.length >= 3) {
      throw Exception(
        'You are posting too frequently. Please wait a moment before posting again.',
      );
    }

    if (body.trim().length < 10 && !hasMedia) {
      final shortDup = await _client
          .from('posts')
          .select('id')
          .eq('author_user_id', authorUserId)
          .eq('body', body.trim())
          .gte(
            'created_at',
            now.subtract(const Duration(hours: 1)).toIso8601String(),
          )
          .limit(1);

      if (shortDup.isNotEmpty) {
        throw Exception(
          'You already posted this content recently. Please create a new post with different content.',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Vibes
  // ---------------------------------------------------------------------------

  /// Fetch vibes for a given post kind ('moment', 'dab', 'kickin').
  ///
  /// This matches the behaviour previously provided by PostService.getVibesForKind
  /// and uses the `contexts` array on the `vibes` table to filter.
  Future<List<Map<String, dynamic>>> getVibesForKind(String kind) async {
    final rows = await _client
        .from('vibes')
        .select('id, key, label_en, emoji, color_hex, contexts')
        .contains('contexts', [kind]);

    return rows
        .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Media (posts.media, post-media bucket)
  // ---------------------------------------------------------------------------

  /// Upload a single image to `post-media` and return the `posts.media` JSON.
  ///
  /// Follows social_model_dabbler.md:
  ///   {
  ///     "bucket": "post-media",
  ///     "path": "posts/<uuid>.<ext>",
  ///     "kind": "image",
  ///     "mime_type": "image/<...>"
  ///   }
  Future<Map<String, dynamic>> uploadPostMedia(XFile file) async {
    final bytes = await file.readAsBytes();

    final path = file.path;
    String ext = '';
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < path.length - 1) {
      ext = path.substring(dotIndex + 1).toLowerCase();
    }
    if (ext.isEmpty) {
      ext = 'jpg';
    }

    final mimeType = lookupMimeType(path, headerBytes: bytes) ?? 'image/jpeg';

    final id = const Uuid().v4();
    final storagePath = 'posts/$id.$ext';

    await _client.storage
        .from(_mediaBucket)
        .uploadBinary(storagePath, Uint8List.fromList(bytes));

    return <String, dynamic>{
      'bucket': _mediaBucket,
      'path': storagePath,
      'kind': 'image',
      'mime_type': mimeType,
    };
  }

  // ---------------------------------------------------------------------------
  // Post creation
  // ---------------------------------------------------------------------------

  Future<PostModel> createPost({
    required String kind,
    required PostVisibility visibility,
    String? body,
    Map<String, dynamic>? media,
    String? primaryVibeId,
    String? gameId,
    String? locationTagId,
    List<String> extraVibeIds = const [],
    List<String> mentionProfileIds = const [],
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final profileId = await _getCurrentProfileId();
    if (profileId == null) {
      throw Exception('Profile not found for current user');
    }

    final textBody = body ?? '';
    await _checkForDuplicatePost(
      authorUserId: user.id,
      body: textBody,
      hasMedia: media != null,
    );

    String dbVisibility;
    switch (visibility) {
      case PostVisibility.public:
        dbVisibility = 'public';
        break;
      case PostVisibility.friends:
        dbVisibility = 'circle';
        break;
      case PostVisibility.private:
        dbVisibility = 'private';
        break;
      case PostVisibility.gameParticipants:
        dbVisibility = 'link';
        break;
    }

    final postData = <String, dynamic>{
      'kind': kind,
      'visibility': dbVisibility,
      'author_profile_id': profileId,
      'author_user_id': user.id,
      'body': textBody,
      if (media != null) 'media': media,
      if (primaryVibeId != null) 'primary_vibe_id': primaryVibeId,
      if (gameId != null) 'game_id': gameId,
      if (locationTagId != null) 'location_tag_id': locationTagId,
    };

    final inserted = await _client
        .from('posts')
        .insert(postData)
        .select('*')
        .single();

    final postId = inserted['id']; // Keep as original type (likely int)

    // Optional: Insert extra vibes (requires post_vibes table)
    if (extraVibeIds.isNotEmpty) {
      try {
        final rows = extraVibeIds
            .map((vibeId) => {'post_id': postId, 'vibe_id': vibeId})
            .toList();
        await _client.from('post_vibes').insert(rows);
      } catch (e) {
        // post_vibes table may not exist yet, continue without it
      }
    }

    // Optional: Insert mentions (requires post_mentions table)
    if (mentionProfileIds.isNotEmpty) {
      try {
        final rows = mentionProfileIds
            .map((pid) => {'post_id': postId, 'mentioned_profile_id': pid})
            .toList();
        await _client.from('post_mentions').insert(rows);
      } catch (e) {
        // post_mentions table may not exist yet, continue without it
      }
    }

    return _mapPostRowToModel(inserted, currentUserId: user.id);
  }

  /// Create a comment on a post, optionally with media.
  Future<void> createComment({
    required String postId,
    required String body,
    Map<String, dynamic>? media,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final profileId = await _getCurrentProfileId();
    if (profileId == null) {
      throw Exception('Profile not found for current user');
    }

    // Parse postId to int if it's a string from URL
    final postIdInt = int.tryParse(postId) ?? postId;

    final data = <String, dynamic>{
      'post_id': postIdInt,
      'author_profile_id': profileId,
      'author_user_id': user.id,
      'body': body,
      if (media != null) 'media': media,
    };

    await _client.from('post_comments').insert(data);
  }

  // ---------------------------------------------------------------------------
  // Feed & queries
  // ---------------------------------------------------------------------------

  Future<List<PostModel>> getFeedPosts({int limit = 20, int offset = 0}) async {
    final posts = await _client
        .from('posts')
        .select('*')
        .eq('visibility', 'public')
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final user = _client.auth.currentUser;
    final currentUserId = user?.id;

    // Preload profiles
    final authorIds = posts
        .map((p) => p['author_user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final profiles = await _client
        .from('profiles')
        .select('user_id, display_name, avatar_url, verified')
        .inFilter('user_id', authorIds);

    final profileMap = <String, Map<String, dynamic>>{
      for (final row in profiles) row['user_id'] as String: row,
    };

    // Preload likes for current user
    final likedPostIds = <dynamic>{};
    if (currentUserId != null && posts.isNotEmpty) {
      final postIds = posts.map((p) => p['id']).toList();
      final likedRows = await _client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', currentUserId)
          .inFilter('post_id', postIds);
      likedPostIds.addAll(likedRows.map((r) => r['post_id']));
    }

    return posts
        .map<PostModel>(
          (row) => _mapPostRowToModel(
            row,
            currentUserId: currentUserId,
            profilesCache: profileMap,
            likedPostIds: likedPostIds,
          ),
        )
        .toList();
  }

  Future<PostModel> getPostById(String postId) async {
    final row = await _client
        .from('posts')
        .select('*')
        .eq('id', postId)
        .eq('is_deleted', false)
        .eq('is_hidden_admin', false)
        .maybeSingle();

    if (row == null) {
      throw Exception('Post not found');
    }

    final user = _client.auth.currentUser;
    final currentUserId = user?.id;

    return _mapPostRowToModel(row, currentUserId: currentUserId);
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  PostModel _mapPostRowToModel(
    Map<String, dynamic> row, {
    String? currentUserId,
    Map<String, Map<String, dynamic>>? profilesCache,
    Set<dynamic>? likedPostIds,
  }) {
    final postId = row['id'];

    // Media: convert posts.media json -> public URL list
    List<String> mediaUrls = [];
    final mediaData = row['media'];
    if (mediaData is Map<String, dynamic>) {
      final bucket = mediaData['bucket'] as String?;
      final path = mediaData['path'] as String?;
      if (bucket != null && path != null) {
        final url = _client.storage.from(bucket).getPublicUrl(path);
        if (url.isNotEmpty) {
          mediaUrls = [url];
        }
      }
    }

    Map<String, dynamic>? profile;
    final authorUserId = row['author_user_id'] as String?;
    if (authorUserId != null) {
      if (profilesCache != null && profilesCache.containsKey(authorUserId)) {
        profile = profilesCache[authorUserId];
      } else {
        // Lazy fetch if not cached
        // This is sync in signature but only used when cache is null; caller
        // should generally preload profiles.
      }
    }

    final isLiked = likedPostIds?.contains(postId) ?? false;

    final json = <String, dynamic>{
      'id': postId,
      'author_id': authorUserId,
      'content': row['body'] ?? '',
      'media_urls': mediaUrls,
      'visibility': row['visibility'],
      'kind': row['kind'],
      'primary_vibe_id': row['primary_vibe_id'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
      'likes_count': row['like_count'] ?? 0,
      'comments_count': row['comment_count'] ?? 0,
      'shares_count': 0,
      'location_name': row['location_tag_id'],
      'tags': <String>[],
      'is_liked': isLiked,
      'profiles': profile != null
          ? {
              'id': profile['user_id'],
              'display_name': profile['display_name'],
              'avatar_url': profile['avatar_url'],
              'verified': profile['verified'],
            }
          : null,
    };

    return PostModel.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Delete post
  // ---------------------------------------------------------------------------

  Future<bool> deletePost(String postId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Get the current user's profile ID
    final profileId = await _getCurrentProfileId();
    if (profileId == null) {
      throw Exception('Profile not found');
    }

    // Verify ownership before deleting
    final postData = await _client
        .from('posts')
        .select('author_profile_id')
        .eq('id', postId)
        .maybeSingle();

    if (postData == null) {
      throw Exception('Post not found');
    }

    if (postData['author_profile_id'] != profileId) {
      throw Exception('You can only delete your own posts');
    }

    // Delete the post (cascade deletes will handle related records)
    await _client.from('posts').delete().eq('id', postId);

    return true;
  }
}
