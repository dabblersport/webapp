import 'package:supabase_flutter/supabase_flutter.dart';

class PostService {
  const PostService();

  SupabaseClient get _client => Supabase.instance.client;

  /// Load vibes filtered by post kind: 'moment' | 'dab' | 'kickin'
  /// The 'contexts' column is a text[] array containing applicable post types
  Future<List<Map<String, dynamic>>> getVibesForKind(String kind) async {
    try {
      final response = await _client
          .from('vibes')
          .select('id, key, label_en, emoji, color_hex, contexts')
          .eq('is_active', true)
          .contains('contexts', [kind]) // contexts is text[] - filter by kind
          .order('label_en', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Return empty list to avoid crashing UI
      return [];
    }
  }

  /// Get the current user's profile id from auth
  Future<String?> getCurrentProfileId() async {
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

  Future<void> createPost({
    required String kind,
    required String visibility,
    String? body,
    String? primaryVibeId,
    Map<String, dynamic>? media,
    String? mediaUrl,
    String? gameId,
    String? locationTagId,
    List<String> vibeIds = const [],
    List<String> mentionProfileIds = const [],
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final profileId = await getCurrentProfileId();
    if (profileId == null) throw Exception('No profile found for user');

    // Prepare post data with correct column names
    final postData = {
      'kind': kind,
      'visibility': visibility,
      'author_user_id': user.id, // Required by schema
      'author_profile_id': profileId, // Required by schema
      'body': body,
      if (media != null) 'media': media,
      if (primaryVibeId != null) 'primary_vibe_id': primaryVibeId,
      if (gameId != null) 'game_id': gameId,
      if (locationTagId != null) 'location_tag_id': locationTagId,
      // Don't send created_at, let database handle it with DEFAULT
    };

    final inserted = await _client
        .from('posts')
        .insert(postData)
        .select('id')
        .single();

    final postId = inserted['id'] as String;

    // Attach additional vibes (post_vibes)
    if (vibeIds.isNotEmpty) {
      final vibeRows = vibeIds
          .map((vibeId) => {'post_id': postId, 'vibe_id': vibeId})
          .toList();

      await _client.from('post_vibes').insert(vibeRows);
    }

    // Mentions
    if (mentionProfileIds.isNotEmpty) {
      final mentionRows = mentionProfileIds
          .map((pid) => {'post_id': postId, 'mentioned_profile_id': pid})
          .toList();

      await _client.from('post_mentions').insert(mentionRows);
    }
  }

  Future<String?> upsertLocationTag({
    required String label,
    String? venueId,
  }) async {
    final result = await _client
        .rpc(
          'upsert_location_tag',
          params: {'_label': label, '_venue_id': venueId},
        )
        .maybeSingle();

    if (result == null) return null;
    return result['id'] as String;
  }
}
