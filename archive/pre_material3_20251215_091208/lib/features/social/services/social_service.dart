import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/data/models/social/post_model.dart';
import 'package:dabbler/core/services/auth_service.dart';
import '../../../utils/enums/social_enums.dart';

class SocialService {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;
  SocialService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  /// Ensure session is fresh before making Supabase queries
  Future<void> _ensureValidSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return;

      // Check if session expires in less than 5 minutes
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        (session.expiresAt ?? 0) * 1000,
      );
      final now = DateTime.now();
      final timeToExpiry = expiresAt.difference(now);

      if (timeToExpiry.inMinutes < 5) {
        await _authService.refreshSession();
      }
    } catch (e) {}
  }

  /// Create a new post
  Future<PostModel> createPost({
    required String content,
    List<String> mediaUrls = const [],
    String? locationName,
    PostVisibility visibility = PostVisibility.public,
    List<String> tags = const [],
  }) async {
    try {
      await _ensureValidSession();

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get user profile information (for validation and to get profile ID)
      final userProfile = await _supabase
          .from('profiles')
          .select('id, user_id, display_name, avatar_url, verified')
          .eq('user_id', user.id)
          .single();

      // Check for duplicate posts to prevent spam/reposting
      await _checkForDuplicatePost(user.id, content, mediaUrls);

      // Map domain visibility enum to DB `posts.visibility` values.
      // DB allowed values: 'public', 'circle', 'link', 'private'.
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
          // For now, map to 'link' (shareable-by-link style posts).
          dbVisibility = 'link';
          break;
      }

      // Map to actual database schema
      final postData = {
        // Required fields - must be set explicitly
        'author_user_id': user.id, // REQUIRED: Set the user ID
        'author_profile_id': userProfile['id'], // REQUIRED: Set the profile ID
        'kind': 'moment', // Default post type
        'visibility': dbVisibility,
        'body': content, // Map content -> body
        'media': mediaUrls
            .map((url) => {'url': url})
            .toList(), // Map to media array format
        // Optional fields
        if (locationName != null) 'venue_id': locationName,
        // Stats fields default on server side
        // Timestamps handled by server
      };

      // Insert the post using actual database schema
      final inserted = await _supabase
          .from('posts')
          .insert(postData)
          .select()
          .single();

      // Transform database response to PostModel format
      final transformedPost = {
        'id': inserted['id'],
        'author_id':
            inserted['author_user_id'], // Map author_user_id -> author_id
        'content': inserted['body'] ?? '', // Map body -> content
        'media_urls': inserted['media'] ?? [], // Map media array -> media_urls
        'visibility': inserted['visibility'],
        'created_at': inserted['created_at'],
        'updated_at': inserted['updated_at'],
        'likes_count': inserted['like_count'] ?? 0,
        'comments_count': inserted['comment_count'] ?? 0,
        'shares_count': 0,
        'location_name': inserted['venue_id'],
        'tags': tags,
        'profiles': {
          'id': userProfile['user_id'],
          'display_name': userProfile['display_name'],
          'avatar_url': userProfile['avatar_url'],
          'verified': userProfile['verified'],
        },
      };

      return PostModel.fromJson(transformedPost);
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  /// Get posts for the social feed
  Future<List<PostModel>> getFeedPosts({int limit = 20, int offset = 0}) async {
    try {
      await _ensureValidSession();

      // Query posts using actual database schema, join vibe data
      final postsResponse = await _supabase
          .from('posts')
          .select(
            '*, vibe:vibes!primary_vibe_id(emoji, label_en, key, color_hex)',
          )
          .eq('visibility', 'public')
          .eq('is_deleted', false)
          .eq('is_hidden_admin', false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      // Get unique author IDs from actual field name
      final authorIds = postsResponse
          .map((post) => post['author_user_id'] as String)
          .toSet()
          .toList();

      // Fetch all required profiles in batch
      final profilesResponse = await _supabase
          .from('profiles')
          .select('user_id, display_name, avatar_url, verified')
          .inFilter('user_id', authorIds);

      // Create a map for quick profile lookup
      final profilesMap = <String, Map<String, dynamic>>{};
      for (final profile in profilesResponse) {
        profilesMap[profile['user_id']] = profile;
      }

      // Fetch current user's liked post IDs
      final user = _supabase.auth.currentUser;
      final Set<String> likedPostIds = {};
      if (user != null) {
        final postIds = postsResponse
            .map((post) => post['id'].toString())
            .toList();
        if (postIds.isNotEmpty) {
          final likedPosts = await _supabase
              .from('post_likes')
              .select('post_id')
              .eq('user_id', user.id)
              .inFilter('post_id', postIds);
          likedPostIds.addAll(
            likedPosts.map((like) => like['post_id'].toString()),
          );
        }
      }

      // Transform database posts to match PostModel expectations
      final enrichedPosts = postsResponse.map((post) {
        final authorId = post['author_user_id'] as String;
        final profile = profilesMap[authorId];
        final postId = post['id'].toString();

        // Extract media URL from posts.media jsonb using Supabase Storage
        List<String> mediaUrls = [];
        final mediaData = post['media'];
        if (mediaData is Map<String, dynamic>) {
          final bucket = mediaData['bucket'] as String?;
          final path = mediaData['path'] as String?;
          if (bucket != null && path != null) {
            final publicUrl = _supabase.storage.from(bucket).getPublicUrl(path);
            if (publicUrl.isNotEmpty) {
              mediaUrls = [publicUrl];
            }
          }
        }

        // Transform database schema to PostModel schema
        return {
          'id': postId,
          'author_id':
              post['author_user_id'], // Map author_user_id -> author_id
          'content': post['body'] ?? '', // Map body -> content
          'media_urls': mediaUrls, // Extract URLs from media array
          'visibility': post['visibility'],
          // Pass through kind and primary_vibe_id so PostModel can surface them.
          'kind': post['kind'],
          'primary_vibe_id': post['primary_vibe_id'],
          'vibe': post['vibe'], // Pass joined vibe data
          'created_at': post['created_at'],
          'updated_at': post['updated_at'],
          'likes_count':
              post['like_count'] ?? 0, // Map like_count -> likes_count
          'comments_count':
              post['comment_count'] ?? 0, // Map comment_count -> comments_count
          'shares_count': 0, // Not in database, default to 0
          'location_name': post['venue_id'], // Could be mapped differently
          'tags': [], // Not directly in schema
          'is_liked': likedPostIds.contains(
            postId,
          ), // Set is_liked based on user's likes
          'profiles': profile != null
              ? {
                  'id': profile['user_id'],
                  'display_name': profile['display_name'],
                  'avatar_url': profile['avatar_url'],
                  'verified': profile['verified'],
                }
              : null,
        };
      }).toList();

      return enrichedPosts
          .map<PostModel>((json) => PostModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load feed posts: $e');
    }
  }

  /// Get posts by a specific user
  Future<List<PostModel>> getUserPosts({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      await _ensureValidSession();

      // Query posts using actual database schema
      final postsResponse = await _supabase
          .from('posts')
          .select(
            '*, vibe:vibes!primary_vibe_id(emoji, label_en, key, color_hex)',
          )
          .eq('author_user_id', userId) // Use correct field name
          .eq('is_deleted', false)
          .eq('is_hidden_admin', false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      // Get the user profile
      final profileResponse = await _supabase
          .from('profiles')
          .select('user_id, display_name, avatar_url, verified')
          .eq('user_id', userId)
          .maybeSingle();

      // Fetch current user's liked post IDs
      final user = _supabase.auth.currentUser;
      final Set<String> likedPostIds = {};
      if (user != null) {
        final postIds = postsResponse
            .map((post) => post['id'].toString())
            .toList();
        if (postIds.isNotEmpty) {
          final likedPosts = await _supabase
              .from('post_likes')
              .select('post_id')
              .eq('user_id', user.id)
              .inFilter('post_id', postIds);
          likedPostIds.addAll(
            likedPosts.map((like) => like['post_id'].toString()),
          );
        }
      }

      // Transform database posts to match PostModel expectations
      final enrichedPosts = postsResponse.map((post) {
        final postId = post['id'].toString();

        // Extract media URLs from media (handles both single object and array)
        List<String> mediaUrls = [];
        final mediaData = post['media'];
        if (mediaData != null) {
          if (mediaData is Map) {
            // Single media object (from PostService)
            if (mediaData['url'] != null) {
              mediaUrls.add(mediaData['url'].toString());
            } else if (mediaData['path'] != null &&
                mediaData['bucket'] != null) {
              final bucket = mediaData['bucket'].toString();
              final path = mediaData['path'].toString();
              // Construct full URL from storage bucket + path using Supabase Storage API
              final url = _supabase.storage.from(bucket).getPublicUrl(path);
              if (url.isNotEmpty) {
                mediaUrls.add(url);
              }
            }
          } else if (mediaData is List) {
            // Array of media items (legacy format)
            for (var mediaItem in mediaData) {
              if (mediaItem is Map && mediaItem['url'] != null) {
                mediaUrls.add(mediaItem['url'].toString());
              } else if (mediaItem is Map &&
                  mediaItem['path'] != null &&
                  mediaItem['bucket'] != null) {
                final bucket = mediaItem['bucket'].toString();
                final path = mediaItem['path'].toString();
                final url = _supabase.storage.from(bucket).getPublicUrl(path);
                if (url.isNotEmpty) {
                  mediaUrls.add(url);
                }
              } else if (mediaItem is String && mediaItem.isNotEmpty) {
                mediaUrls.add(mediaItem);
              }
            }
          }
        }

        return {
          'id': postId,
          'author_id':
              post['author_user_id'], // Map author_user_id -> author_id
          'content': post['body'] ?? '', // Map body -> content
          'media_urls': mediaUrls, // Extract URLs from media array
          'visibility': post['visibility'],
          'kind': post['kind'],
          'primary_vibe_id': post['primary_vibe_id'],
          'created_at': post['created_at'],
          'updated_at': post['updated_at'],
          'likes_count':
              post['like_count'] ?? 0, // Map like_count -> likes_count
          'comments_count':
              post['comment_count'] ?? 0, // Map comment_count -> comments_count
          'shares_count': 0, // Not in database, default to 0
          'location_name': post['venue_id'], // Could be mapped differently
          'tags': [], // Not directly in schema
          'is_liked': likedPostIds.contains(
            postId,
          ), // Set is_liked based on user's likes
          'profiles': profileResponse != null
              ? {
                  'id': profileResponse['user_id'],
                  'display_name': profileResponse['display_name'],
                  'avatar_url': profileResponse['avatar_url'],
                  'verified': profileResponse['verified'],
                }
              : null,
        };
      }).toList();

      return enrichedPosts
          .map<PostModel>((json) => PostModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load user posts: $e');
    }
  }

  /// Get a single post by ID with joined profile data.
  Future<PostModel> getPostById(String postId) async {
    try {
      await _ensureValidSession();

      // Parse postId to int if it's a string from URL
      final postIdInt = int.tryParse(postId) ?? postId;

      // Fetch the post with joins (excluding location_tags as it's often null)
      final post = await _supabase
          .from('posts')
          .select('''
            *,
            profiles!author_profile_id(id, user_id, display_name, avatar_url, verified),
            vibes!primary_vibe_id(id, key, label_en, label_ar, emoji, color_hex, gradient, urgency_level, type, usage)
          ''')
          .eq('id', postIdInt)
          .eq('is_deleted', false)
          .eq('is_hidden_admin', false)
          .maybeSingle();

      if (post == null) {
        throw Exception('Post not found');
      }

      final authorId = post['author_user_id'] as String;

      // Fetch location_tags separately if location_tag_id is not null
      Map<String, dynamic>? locationTagData;
      if (post['location_tag_id'] != null) {
        try {
          locationTagData = await _supabase
              .from('location_tags')
              .select(
                'id, name, address, city, country, latitude, longitude, place_id, meta',
              )
              .eq('id', post['location_tag_id'])
              .maybeSingle();
        } catch (e) {}
      }

      // Fetch post_vibes (all vibes assigned to this post)
      // Note: FK relationship missing, so we fetch vibes separately
      List<Map<String, dynamic>> postVibes = [];
      try {
        final vibesData = await _supabase
            .from('post_vibes')
            .select('vibe_id, assigned_at')
            .eq('post_id', postIdInt);

        // Fetch vibe details for each vibe_id
        if (vibesData.isNotEmpty) {
          final vibeIds = (vibesData as List).map((v) => v['vibe_id']).toList();
          final vibes = await _supabase
              .from('vibes')
              .select('id, key, label_en, label_ar, emoji, color_hex, type')
              .inFilter('id', vibeIds);

          // Merge vibe data back into post_vibes
          final vibeMap = {for (var v in vibes) v['id']: v};
          postVibes = (vibesData as List).map((pv) {
            final vibe = vibeMap[pv['vibe_id']];
            return Map<String, dynamic>.from({...pv, 'vibes': vibe});
          }).toList();
        }
      } catch (e) {}

      // Fetch post_reactions (user reactions with their profiles)
      // Note: FK relationship missing for vibes, column is created_at not reacted_at
      List<Map<String, dynamic>> postReactions = [];
      try {
        final reactionsData = await _supabase
            .from('post_reactions')
            .select('''
              vibe_id, created_at,
              profiles!actor_profile_id(id, user_id, display_name, avatar_url, verified)
            ''')
            .eq('post_id', postIdInt)
            .order('created_at', ascending: false);

        // Fetch vibe details for each vibe_id
        if (reactionsData.isNotEmpty) {
          final vibeIds = (reactionsData as List)
              .map((r) => r['vibe_id'])
              .toList();
          final vibes = await _supabase
              .from('vibes')
              .select('id, key, label_en, emoji, color_hex')
              .inFilter('id', vibeIds);

          // Merge vibe data back into reactions
          final vibeMap = {for (var v in vibes) v['id']: v};
          postReactions = (reactionsData as List).map((r) {
            final vibe = vibeMap[r['vibe_id']];
            return Map<String, dynamic>.from({...r, 'vibes': vibe});
          }).toList();
        } else {
          postReactions = List<Map<String, dynamic>>.from(reactionsData);
        }
      } catch (e) {}

      // Fetch post_mentions (mentioned users)
      List<Map<String, dynamic>> postMentions = [];
      try {
        final mentionsData = await _supabase
            .from('post_mentions')
            .select('''
              mentioned_profile_id,
              profiles!mentioned_profile_id(id, user_id, display_name, username, avatar_url, verified)
            ''')
            .eq('post_id', postIdInt);
        postMentions = List<Map<String, dynamic>>.from(mentionsData);
      } catch (e) {}

      // Fetch author profile separately if not in join
      Map<String, dynamic>? profileResponse = post['profiles'];
      profileResponse ??= await _supabase
          .from('profiles')
          .select('user_id, display_name, avatar_url, verified')
          .eq('user_id', authorId)
          .maybeSingle();

      // Check if current user has liked this post
      final user = _supabase.auth.currentUser;
      bool isLiked = false;
      if (user != null) {
        final existingLike = await _supabase
            .from('post_likes')
            .select('post_id')
            .eq('post_id', postIdInt)
            .eq('user_id', user.id)
            .maybeSingle();
        isLiked = existingLike != null;
      }

      // Extract media URLs from media (handles both single object and array)
      List<String> mediaUrls = [];
      final mediaData = post['media'];
      if (mediaData != null) {
        if (mediaData is Map) {
          // Single media object (from PostService)
          if (mediaData['url'] != null) {
            mediaUrls.add(mediaData['url'].toString());
          } else if (mediaData['path'] != null && mediaData['bucket'] != null) {
            final bucket = mediaData['bucket'].toString();
            final path = mediaData['path'].toString();
            // Construct full URL from storage bucket + path using Supabase Storage API
            final url = _supabase.storage.from(bucket).getPublicUrl(path);
            if (url.isNotEmpty) {
              mediaUrls.add(url);
            }
          }
        } else if (mediaData is List) {
          // Array of media items (legacy format)
          for (var mediaItem in mediaData) {
            if (mediaItem is Map && mediaItem['url'] != null) {
              mediaUrls.add(mediaItem['url'].toString());
            } else if (mediaItem is Map &&
                mediaItem['path'] != null &&
                mediaItem['bucket'] != null) {
              final bucket = mediaItem['bucket'].toString();
              final path = mediaItem['path'].toString();
              final url = _supabase.storage.from(bucket).getPublicUrl(path);
              if (url.isNotEmpty) {
                mediaUrls.add(url);
              }
            } else if (mediaItem is String && mediaItem.isNotEmpty) {
              mediaUrls.add(mediaItem);
            }
          }
        }
      }

      final enriched = {
        'id': post['id'],
        'author_id': post['author_user_id'],
        'author_profile_id': post['author_profile_id'],
        'content': post['body'] ?? '',
        'media_urls': mediaUrls,
        'media': mediaData, // Include full media metadata
        'visibility': post['visibility'],
        'kind': post['kind'],
        'primary_vibe_id': post['primary_vibe_id'],
        'vibes': post['vibes'], // Primary vibe from join
        'post_vibes': postVibes, // All assigned vibes
        'reactions': postReactions, // User reactions
        'mentions': postMentions, // Mentioned users
        'location_tag': locationTagData, // Location data fetched separately
        'location_tag_id': post['location_tag_id'],
        'venue_id': post['venue_id'],
        'created_at': post['created_at'],
        'updated_at': post['updated_at'],
        'likes_count': post['like_count'] ?? 0,
        'comments_count': post['comment_count'] ?? 0,
        'shares_count': 0,
        'location_name': post['venue_id'],
        'tags': [],
        'is_liked': isLiked, // Set is_liked based on user's like status
        'profiles': profileResponse != null
            ? {
                'id': profileResponse['user_id'] ?? profileResponse['id'],
                'user_id': profileResponse['user_id'],
                'display_name': profileResponse['display_name'],
                'avatar_url': profileResponse['avatar_url'],
                'verified': profileResponse['verified'],
              }
            : null,
      };

      return PostModel.fromJson(enriched);
    } catch (e) {
      throw Exception('Failed to load post: $e');
    }
  }

  /// Like/unlike a post
  Future<void> toggleLike(String postId) async {
    try {
      await _ensureValidSession();

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get current user's profile_id (required for post_likes)
      final profileRes = await _supabase
          .from('profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileRes == null) {
        throw Exception('Profile not found for current user');
      }

      final profileId = profileRes['id'] as String;

      // Check if already liked - use the original postId consistently
      // post_likes table uses composite key (post_id, user_id), no id column
      final existingLikes = await _supabase
          .from('post_likes')
          .select('post_id')
          .eq('post_id', postId)
          .eq('user_id', user.id);

      final isCurrentlyLiked = existingLikes.isNotEmpty;

      if (isCurrentlyLiked) {
        // Unlike: Remove the like (trigger will decrement like_count automatically)
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', user.id);
      } else {
        // Like: Add the like (trigger will increment like_count automatically)
        await _supabase.from('post_likes').insert({
          'post_id': postId,
          'user_id': user.id,
          'profile_id':
              profileId, // Required: use profile_id per social model spec
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  /// Get post likes with user details
  Future<List<dynamic>> getPostLikes(String postId) async {
    try {
      await _ensureValidSession();

      final likes = await _supabase
          .from('post_likes')
          .select(
            'user_id, created_at, profiles!post_likes_profile_id_fkey(display_name, avatar_url)',
          )
          .eq('post_id', postId)
          .order('created_at', ascending: false);

      return likes;
    } catch (e) {
      throw Exception('Failed to fetch post likes: $e');
    }
  }

  /// Like/unlike a comment
  Future<void> toggleCommentLike(String commentId) async {
    try {
      // Parse commentId to int if it's a string from URL
      final commentIdInt = int.tryParse(commentId) ?? commentId;

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get current user's profile_id (required for comment_likes)
      final profileRes = await _supabase
          .from('profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileRes == null) {
        throw Exception('Profile not found for current user');
      }

      final profileId = profileRes['id'] as String;

      // Check if already liked
      final existingLike = await _supabase
          .from('comment_likes')
          .select('comment_id')
          .eq('comment_id', commentIdInt)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike: Remove the like (trigger will decrement like_count automatically)
        await _supabase
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentIdInt)
            .eq('user_id', user.id);
      } else {
        // Like: Add the like (trigger will increment like_count automatically)
        await _supabase.from('comment_likes').insert({
          'comment_id': commentIdInt,
          'user_id': user.id,
          'profile_id':
              profileId, // Required: use profile_id per social model spec
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      throw Exception('Failed to toggle comment like: $e');
    }
  }

  /// Hide a post for the current user (post_hides).
  Future<void> hidePost(String postId) async {
    try {
      // Parse postId to int if it's a string from URL
      final postIdInt = int.tryParse(postId) ?? postId;

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('post_hides').upsert({
        'post_id': postIdInt,
        'owner_user_id': user.id,
      });
    } catch (e) {
      throw Exception('Failed to hide post: $e');
    }
  }

  /// Delete a post (only owner can delete)
  Future<void> deletePost(String postId) async {
    try {
      await _ensureValidSession();

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get the current user's profile ID
      final profileRes = await _supabase
          .from('profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileRes == null) {
        throw Exception('Profile not found');
      }

      final profileId = profileRes['id'] as String;

      // Verify ownership before deleting
      final postData = await _supabase
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
      await _supabase.from('posts').delete().eq('id', postId);
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  /// Unhide a post for the current user.
  Future<void> unhidePost(String postId) async {
    try {
      // Parse postId to int if it's a string from URL
      final postIdInt = int.tryParse(postId) ?? postId;

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('post_hides')
          .delete()
          .eq('post_id', postIdInt)
          .eq('owner_user_id', user.id);
    } catch (e) {
      throw Exception('Failed to unhide post: $e');
    }
  }

  /// Get IDs of posts hidden by the current user.
  Future<Set<String>> getHiddenPostIdsForCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return <String>{};
      }

      final rows = await _supabase
          .from('post_hides')
          .select('post_id')
          .eq('owner_user_id', user.id);

      return rows
          .map((row) => row['post_id']?.toString())
          .whereType<String>()
          .toSet();
    } catch (e) {
      throw Exception('Failed to load hidden posts: $e');
    }
  }

  /// Add a comment to a post
  Future<Map<String, dynamic>> addComment({
    required String postId,
    required String body,
    String? parentCommentId,
  }) async {
    try {
      await _ensureValidSession();

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get user profile
      final profile = await _supabase
          .from('profiles')
          .select('id')
          .eq('user_id', user.id)
          .single();

      // Insert comment (trigger will increment comment_count automatically)
      final comment = await _supabase
          .from('post_comments')
          .insert({
            'post_id': postId,
            'author_user_id': user.id,
            'author_profile_id': profile['id'],
            'body': body,
            if (parentCommentId != null) 'parent_comment_id': parentCommentId,
          })
          .select()
          .single();

      return comment;
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  /// Get comments for a post with nested replies
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      await _ensureValidSession();

      // Parse postId to int if it's a string from URL
      final postIdInt = int.tryParse(postId) ?? postId;

      // Fetch all comments for the post (including replies) with joins
      final allComments = await _supabase
          .from('post_comments')
          .select('''
            *,
            profiles!author_profile_id(id, user_id, display_name, avatar_url, verified)
          ''')
          .eq('post_id', postIdInt)
          .eq('is_deleted', false)
          .eq('is_hidden_admin', false)
          .order('created_at', ascending: true);

      final commentsList = List<Map<String, dynamic>>.from(allComments);

      // Fetch comment mentions for all comments
      final Map<String, List<Map<String, dynamic>>> commentMentionsMap = {};
      if (commentsList.isNotEmpty) {
        final commentIds = commentsList.map((c) => c['id']).toList();
        try {
          final mentionsData = await _supabase
              .from('comment_mentions')
              .select('''
                comment_id, mentioned_profile_id,
                profiles!mentioned_profile_id(id, user_id, display_name, username, avatar_url, verified)
              ''')
              .inFilter('comment_id', commentIds);

          for (var mention in mentionsData) {
            final commentId = mention['comment_id'].toString();
            if (!commentMentionsMap.containsKey(commentId)) {
              commentMentionsMap[commentId] = [];
            }
            commentMentionsMap[commentId]!.add(mention);
          }
        } catch (e) {}
      }

      // Fetch current user's liked comment IDs
      final user = _supabase.auth.currentUser;
      final Set<dynamic> likedCommentIds = {};
      if (user != null && commentsList.isNotEmpty) {
        final commentIds = commentsList
            .map((comment) => comment['id'])
            .toList();
        final likedComments = await _supabase
            .from('comment_likes')
            .select('comment_id')
            .eq('user_id', user.id)
            .inFilter('comment_id', commentIds);
        likedCommentIds.addAll(likedComments.map((like) => like['comment_id']));
      }

      // Add like information and mentions to each comment
      for (final comment in commentsList) {
        final commentId = comment['id'];
        comment['is_liked'] = likedCommentIds.contains(commentId);
        comment['likes_count'] = comment['like_count'] ?? 0;
        comment['author_profile_id'] = comment['author_profile_id'];

        // Add mentions for this comment
        final commentIdStr = commentId.toString();
        comment['comment_mentions'] = commentMentionsMap[commentIdStr] ?? [];
      }

      // Build nested structure: separate top-level comments from replies
      final topLevelComments = <Map<String, dynamic>>[];
      final repliesMap = <dynamic, List<Map<String, dynamic>>>{};

      for (final comment in commentsList) {
        final parentId = comment['parent_comment_id'];

        if (parentId == null) {
          // Top-level comment
          topLevelComments.add(comment);
        } else {
          // Reply - add to replies map
          repliesMap.putIfAbsent(parentId, () => []).add(comment);
        }
      }

      // Attach replies to their parent comments
      for (final comment in topLevelComments) {
        final commentId = comment['id'];
        if (repliesMap.containsKey(commentId)) {
          comment['replies'] = repliesMap[commentId]!;
        } else {
          comment['replies'] = <Map<String, dynamic>>[];
        }
      }

      return topLevelComments;
    } catch (e) {
      throw Exception('Failed to load comments: $e');
    }
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId) async {
    try {
      // Parse commentId to int if it's a string from URL
      final commentIdInt = int.tryParse(commentId) ?? commentId;

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Soft delete (trigger will decrement comment_count automatically)
      await _supabase
          .from('post_comments')
          .update({'is_deleted': true})
          .eq('id', commentIdInt)
          .eq('author_user_id', user.id);
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  /// Report a post (deprecated - use ModerationService.submitReport instead).
  /// This method now delegates to ModerationService for consistency with the new moderation system.
  @Deprecated('Use ModerationService.submitReport() instead')
  Future<void> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final trimmedReason = reason.trim();
      if (trimmedReason.length < 3 || trimmedReason.length > 140) {
        throw Exception('Reason must be between 3 and 140 characters');
      }

      // Use the new ModerationService instead of direct table access
      final moderationService = ModerationService();

      // Map reason string to ReportReason enum
      ReportReason reportReason;
      switch (trimmedReason.toLowerCase()) {
        case 'spam':
          reportReason = ReportReason.spam;
          break;
        case 'abuse':
        case 'inappropriate content':
          reportReason = ReportReason.abuse;
          break;
        case 'hate':
          reportReason = ReportReason.hate;
          break;
        case 'harassment':
          reportReason = ReportReason.harassment;
          break;
        case 'nudity':
          reportReason = ReportReason.nudity;
          break;
        case 'illegal':
          reportReason = ReportReason.illegal;
          break;
        case 'danger':
          reportReason = ReportReason.danger;
          break;
        case 'scam':
          reportReason = ReportReason.scam;
          break;
        case 'impersonation':
          reportReason = ReportReason.impersonation;
          break;
        default:
          reportReason = ReportReason.other;
      }

      await moderationService.submitReport(
        target: ModTarget.post,
        targetId: postId,
        reason: reportReason,
        details: details?.trim(),
      );
    } catch (e) {
      throw Exception('Failed to report post: $e');
    }
  }

  /// DEPRECATED: Use SocialRepository.uploadPostMedia instead.
  /// This legacy method has incorrect MIME/extension handling.
  @Deprecated('Use SocialRepository.uploadPostMedia instead')
  Future<List<String>> uploadImages(List<String> imagePaths) async {
    throw UnimplementedError(
      'uploadImages is deprecated. '
      'Use SocialRepository.uploadPostMedia to upload XFile objects '
      'with correct MIME type detection and extension handling.',
    );
  }

  // -----------------------------------------------------------------------------
  // VIBES
  // -----------------------------------------------------------------------------

  /// Get all active vibes (basic catalog).
  Future<List<Map<String, dynamic>>> getVibes() async {
    try {
      final rows = await _supabase
          .from('vibes')
          .select('id, key, label, emoji, color, is_active')
          .eq('is_active', true)
          .order('label');
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      throw Exception('Failed to load vibes: $e');
    }
  }

  /// Get vibes assigned to a post (via post_vibes).
  Future<List<Map<String, dynamic>>> getPostVibes(String postId) async {
    try {
      // Parse postId to int if it's a string from URL
      final postIdInt = int.tryParse(postId) ?? postId;

      final rows = await _supabase
          .from('post_vibes')
          .select(
            'vibe_id, assigned_at, vibes:vibe_id(id, key, label, emoji, color)',
          )
          .eq('post_id', postIdInt)
          .order('assigned_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      throw Exception('Failed to load post vibes: $e');
    }
  }

  /// Set primary vibe on posts.primary_vibe_id.
  Future<void> setPrimaryVibe({
    required String postId,
    required String vibeId,
  }) async {
    try {
      // Parse postId to int if it's a string from URL
      final postIdInt = int.tryParse(postId) ?? postId;

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      await _supabase
          .from('posts')
          .update({'primary_vibe_id': vibeId})
          .eq('id', postIdInt)
          .eq('author_user_id', user.id);
    } catch (e) {
      throw Exception('Failed to set primary vibe: $e');
    }
  }

  /// Toggle a vibe membership in post_vibes (add/remove).
  Future<void> togglePostVibe({
    required String postId,
    required String vibeId,
  }) async {
    try {
      // Parse postId to int if it's a string from URL
      final postIdInt = int.tryParse(postId) ?? postId;

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      // Check if exists
      final existing = await _supabase
          .from('post_vibes')
          .select('post_id, vibe_id')
          .eq('post_id', postIdInt)
          .eq('vibe_id', vibeId)
          .maybeSingle();
      if (existing != null) {
        await _supabase
            .from('post_vibes')
            .delete()
            .eq('post_id', postIdInt)
            .eq('vibe_id', vibeId);
      } else {
        await _supabase.from('post_vibes').insert({
          'post_id': postIdInt,
          'vibe_id': vibeId,
        });
      }
    } catch (e) {
      throw Exception('Failed to toggle post vibe: $e');
    }
  }

  /// Check for duplicate posts to prevent spam/reposting
  Future<void> _checkForDuplicatePost(
    String userId,
    String content,
    List<String> mediaUrls,
  ) async {
    try {
      // Define time window for duplicate checking (e.g., 5 minutes)
      final timeWindow = DateTime.now().subtract(const Duration(minutes: 5));

      // Check for exact content duplicates from the same user in recent time
      // Using correct field names: author_user_id and body
      final duplicateContentCheck = await _supabase
          .from('posts')
          .select('id, created_at')
          .eq('author_user_id', userId) // Correct field name
          .eq('body', content) // Correct field name
          .gte('created_at', timeWindow.toIso8601String())
          .limit(1);

      if (duplicateContentCheck.isNotEmpty) {
        throw Exception(
          'You recently posted the same content. Please wait before posting again.',
        );
      }

      // Check for rapid posting from the same user (rate limiting)
      final recentPostsCheck = await _supabase
          .from('posts')
          .select('id, created_at')
          .eq('author_user_id', userId) // Correct field name
          .gte(
            'created_at',
            DateTime.now()
                .subtract(const Duration(minutes: 1))
                .toIso8601String(),
          )
          .limit(3); // Allow max 3 posts per minute

      if (recentPostsCheck.length >= 3) {
        throw Exception(
          'You are posting too frequently. Please wait a moment before posting again.',
        );
      }

      // If content is very short and no media, check for identical recent posts
      if (content.trim().length < 10 && mediaUrls.isEmpty) {
        final shortContentCheck = await _supabase
            .from('posts')
            .select('id')
            .eq('author_user_id', userId) // Correct field name
            .eq('body', content.trim()) // Correct field name
            .gte(
              'created_at',
              DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
            )
            .limit(1);

        if (shortContentCheck.isNotEmpty) {
          throw Exception(
            'You already posted this content recently. Please create a new post with different content.',
          );
        }
      }
    } catch (e) {
      // Re-throw the exception to be handled by the calling method
      rethrow;
    }
  }
}
