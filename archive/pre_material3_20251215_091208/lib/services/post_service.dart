import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class PostService {
  const PostService();

  /// Get the current user's profile id (profiles.id) from auth.uid()
  Future<String?> getCurrentProfileId() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final res = await supabase
        .from('profiles')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (res == null) return null;
    return res['id'] as String;
  }

  /// Load vibes filtered by post kind: 'moment' | 'dab' | 'kickin'
  Future<List<Map<String, dynamic>>> getVibesForKind(String kind) async {
    final data = await supabase
        .from('vibes')
        .select('*')
        .eq('is_active', true)
        .contains('contexts', [kind]); // contexts is text[]

    return List<Map<String, dynamic>>.from(data);
  }

  /// Upsert a location tag via the DB function and return its id.
  Future<String?> upsertLocationTag({
    required String label,
    String? venueId,
  }) async {
    final result = await supabase
        .rpc(
          'upsert_location_tag',
          params: {'_label': label, '_venue_id': venueId},
        )
        .maybeSingle();

    if (result == null) return null;
    return result['id'] as String;
  }

  /// Create a new post (moment/dab/kickin) with optional media, vibes, location, game, mentions.
  Future<String> createPost({
    required String kind, // 'moment' | 'dab' | 'kickin'
    required String visibility, // 'public' | 'circle' | 'link' | 'private'
    required String body,
    Map<String, dynamic>? media, // single-file metadata JSON
    String? gameId,
    String? locationTagId,
    String? primaryVibeId,
    List<String> vibeIds = const [],
    List<String> mentionProfileIds = const [],
  }) async {
    final profileId = await getCurrentProfileId();
    if (profileId == null) {
      throw StateError('No current profile for authenticated user');
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    // 1) Insert into posts
    // Note: media should be a single JSON object (not array) per spec
    // But DB defaults to '[]'::jsonb, so we need to handle null vs object
    final insertPayload = <String, dynamic>{
      'kind': kind,
      'visibility': visibility,
      'author_profile_id': profileId,
      'author_user_id': user.id, // Required by DB schema
      'body': body,
      if (media != null) 'media': media, // Single object, not array
      if (gameId != null) 'game_id': gameId,
      if (locationTagId != null) 'location_tag_id': locationTagId,
      if (primaryVibeId != null) 'primary_vibe_id': primaryVibeId,
    };

    final inserted = await supabase
        .from('posts')
        .insert(insertPayload)
        .select('id')
        .single();

    final postId = inserted['id'] as String;

    // 2) Attach vibes (post_vibes)
    if (vibeIds.isNotEmpty) {
      final vibeRows = vibeIds
          .map((vibeId) => {'post_id': postId, 'vibe_id': vibeId})
          .toList();

      await supabase.from('post_vibes').insert(vibeRows);
    }

    // 3) Mentions
    if (mentionProfileIds.isNotEmpty) {
      final mentionRows = mentionProfileIds
          .map((pid) => {'post_id': postId, 'mentioned_profile_id': pid})
          .toList();

      await supabase.from('post_mentions').insert(mentionRows);
    }

    return postId;
  }
}
