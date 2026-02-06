import 'package:dabbler/data/models/social/post.dart';
import '../../../../utils/enums/social_enums.dart';

/// Data model for social posts with JSON serialization.
///
/// This bridges the canonical `public.posts` schema (plus joined `profiles`)
/// into the social domain `Post` used by the UI.
class PostModel extends Post {
  const PostModel({
    required super.id,
    required super.authorId,
    required super.authorName,
    required super.authorAvatar,
    super.authorProfileId,
    required super.content,
    required super.mediaUrls,
    required super.createdAt,
    required super.updatedAt,
    required super.likesCount,
    required super.commentsCount,
    required super.sharesCount,
    required super.visibility,
    super.gameId,
    super.cityName,
    super.venueId,
    super.locationTagId,
    super.isLiked,
    super.isBookmarked,
    super.authorBio,
    super.authorVerified,
    super.tags,
    super.mentionedUsers,
    super.isEdited,
    super.editedAt,
    super.replyToPostId,
    super.shareOriginalId,
    super.activityType,
    super.activityData,
    super.kind,
    super.primaryVibeId,
    super.primaryVibe,
    super.vibeEmoji,
    super.vibeLabel,
    super.postVibes,
    super.reactions,
    super.mentions,
    super.locationTag,
    super.mediaMetadata,
  });

  /// Create PostModel from Supabase JSON response
  factory PostModel.fromJson(Map<String, dynamic> json) {
    // Parse author data from nested profiles table
    final authorData = json['profiles'] ?? json['author'] ?? {};

    // Parse media URLs - handle both legacy media_urls and DB media jsonb.
    List<String> mediaUrls = [];
    if (json['media_urls'] != null) {
      if (json['media_urls'] is String) {
        // Single URL stored as string
        final urlString = json['media_urls'] as String;
        if (urlString.isNotEmpty) {
          mediaUrls = [urlString];
        }
      } else if (json['media_urls'] is List) {
        // Multiple URLs stored as array
        mediaUrls = (json['media_urls'] as List)
            .map((url) => url.toString())
            .where((url) => url.isNotEmpty)
            .toList();
      }
    } else if (json['media'] != null) {
      final mediaData = json['media'];
      if (mediaData is Map) {
        // Single media object (from PostService - per spec)
        if (mediaData['url'] != null) {
          final url = mediaData['url'].toString();
          if (url.isNotEmpty) mediaUrls.add(url);
        } else if (mediaData['path'] != null) {
          // Storage path - construct URL or use path as-is
          final path = mediaData['path'].toString();
          if (path.isNotEmpty) mediaUrls.add(path);
        }
      } else if (mediaData is List) {
        // Array of media items (legacy format)
        for (final item in mediaData) {
          if (item is Map && item['url'] != null) {
            final url = item['url'].toString();
            if (url.isNotEmpty) mediaUrls.add(url);
          } else if (item is Map && item['path'] != null) {
            final path = item['path'].toString();
            if (path.isNotEmpty) mediaUrls.add(path);
          } else if (item is String && item.isNotEmpty) {
            mediaUrls.add(item);
          }
        }
      }
    }

    // Parse tags from string or array
    List<String> tags = [];
    if (json['tags'] != null) {
      if (json['tags'] is String) {
        // Tags stored as comma-separated string
        final tagString = json['tags'] as String;
        if (tagString.isNotEmpty) {
          tags = tagString.split(',').map((tag) => tag.trim()).toList();
        }
      } else if (json['tags'] is List) {
        // Tags stored as array
        tags = (json['tags'] as List)
            .map((tag) => tag.toString().trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
    }

    // Parse mentioned users
    List<String> mentionedUsers = [];
    if (json['mentioned_users'] != null && json['mentioned_users'] is List) {
      mentionedUsers = (json['mentioned_users'] as List)
          .map((userId) => userId.toString())
          .toList();
    }

    // Parse visibility enum (maps DB visibility values to domain enum).
    PostVisibility visibility = PostVisibility.public;
    if (json['visibility'] != null) {
      switch (json['visibility'].toString().toLowerCase()) {
        case 'public':
          visibility = PostVisibility.public;
          break;
        case 'friends':
        case 'circle':
          visibility = PostVisibility.friends;
          break;
        case 'private':
          visibility = PostVisibility.private;
          break;
        case 'game_participants':
        case 'link':
          visibility = PostVisibility.gameParticipants;
          break;
        default:
          visibility = PostVisibility.public;
      }
    }

    // Map DB kind (moment/dab/kickin/...) if present.
    final String kind = json['kind']?.toString() ?? 'moment';

    // Map primary vibe ID if present.
    final String? primaryVibeId = json['primary_vibe_id']?.toString();

    // Parse primary vibe data if joined
    Map<String, dynamic>? primaryVibe;
    String? vibeEmoji;
    String? vibeLabel;
    if (json['vibe'] != null && json['vibe'] is Map) {
      primaryVibe = json['vibe'] as Map<String, dynamic>;
      vibeEmoji = primaryVibe['emoji']?.toString();
      vibeLabel =
          primaryVibe['label']?.toString() ??
          primaryVibe['label_en']?.toString() ??
          primaryVibe['key']?.toString();
    } else if (json['vibes'] != null && json['vibes'] is Map) {
      primaryVibe = json['vibes'] as Map<String, dynamic>;
      vibeEmoji = primaryVibe['emoji']?.toString();
      vibeLabel =
          primaryVibe['label']?.toString() ??
          primaryVibe['label_en']?.toString() ??
          primaryVibe['key']?.toString();
    } else if (json['vibe_emoji'] != null) {
      vibeEmoji = json['vibe_emoji']?.toString();
      vibeLabel = json['vibe_label']?.toString();
      // No full vibe data available, just emoji and label
    }

    // Parse post_vibes (all assigned vibes)
    List<Map<String, dynamic>> postVibes = [];
    if (json['post_vibes'] != null && json['post_vibes'] is List) {
      postVibes = (json['post_vibes'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }

    // Parse post_reactions
    List<Map<String, dynamic>> reactions = [];
    if (json['post_reactions'] != null && json['post_reactions'] is List) {
      reactions = (json['post_reactions'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }

    // Parse post_mentions
    List<Map<String, dynamic>> mentions = [];
    if (json['post_mentions'] != null && json['post_mentions'] is List) {
      mentions = (json['post_mentions'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }

    // Parse location_tag (joined)
    Map<String, dynamic>? locationTag;
    if (json['location_tag'] != null && json['location_tag'] is Map) {
      locationTag = json['location_tag'] as Map<String, dynamic>;
    } else if (json['location_tags'] != null && json['location_tags'] is Map) {
      locationTag = json['location_tags'] as Map<String, dynamic>;
    }

    // Parse media metadata (from posts.media jsonb array)
    List<Map<String, dynamic>> mediaMetadata = [];
    if (json['media'] != null && json['media'] is List) {
      mediaMetadata = (json['media'] as List)
          .map(
            (e) =>
                e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{},
          )
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (json['media'] is Map) {
      mediaMetadata = [Map<String, dynamic>.from(json['media'])];
    }

    return PostModel(
      id: json['id']?.toString() ?? '',
      authorId:
          json['author_id'] ?? json['user_id'] ?? json['author_user_id'] ?? '',
      authorProfileId: json['author_profile_id']?.toString(),
      authorName:
          authorData['display_name'] ??
          authorData['username'] ??
          authorData['full_name'] ??
          'Unknown User',
      authorAvatar:
          authorData['avatar_url'] ?? authorData['profile_picture'] ?? '',
      content: json['body'] ?? json['content'] ?? '',
      mediaUrls: mediaUrls,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      likesCount: _parseInt(json['likes_count'] ?? json['like_count'] ?? 0),
      commentsCount: _parseInt(
        json['comments_count'] ?? json['comment_count'] ?? 0,
      ),
      sharesCount: _parseInt(json['shares_count'] ?? json['share_count'] ?? 0),
      visibility: visibility,
      gameId: json['game_id']?.toString(),
      cityName: json['location_name']?.toString(),
      venueId: json['venue_id']?.toString(),
      locationTagId: json['location_tag_id']?.toString(),
      isLiked: json['is_liked'] == true || json['user_has_liked'] == true,
      isBookmarked:
          json['is_bookmarked'] == true || json['user_has_bookmarked'] == true,
      authorBio: authorData['bio'] ?? authorData['description'],
      authorVerified:
          _parseBoolean(authorData['verified']) ||
          _parseBoolean(authorData['is_verified']),
      tags: tags,
      mentionedUsers: mentionedUsers,
      isEdited: json['is_edited'] == true,
      editedAt: json['edited_at'] != null
          ? _parseDateTime(json['edited_at'])
          : null,
      replyToPostId: json['reply_to_post_id']?.toString(),
      shareOriginalId: json['share_original_id']?.toString(),
      activityType: json['activity_type']?.toString(),
      activityData: json['activity_data'] != null
          ? Map<String, dynamic>.from(json['activity_data'])
          : null,
      kind: kind,
      primaryVibeId: primaryVibeId,
      primaryVibe: primaryVibe,
      vibeEmoji: vibeEmoji,
      vibeLabel: vibeLabel,
      postVibes: postVibes,
      reactions: reactions,
      mentions: mentions,
      locationTag: locationTag,
      mediaMetadata: mediaMetadata,
    );
  }

  /// Convert PostModel to JSON for API requests
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'author_id': authorId,
      'content': content,
      'media_urls': mediaUrls,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'shares_count': sharesCount,
      'visibility': _visibilityToString(visibility),
      'kind': kind,
      'primary_vibe_id': primaryVibeId,
      'vibe_emoji': vibeEmoji,
      'vibe_label': vibeLabel,
    };

    // Add optional fields only if they have values
    if (gameId != null) json['game_id'] = gameId;
    if (cityName != null) json['location_name'] = cityName;
    if (tags.isNotEmpty) json['tags'] = tags;
    if (mentionedUsers.isNotEmpty) {
      json['mentioned_users'] = mentionedUsers;
    }
    if (isEdited == true) {
      json['is_edited'] = true;
      if (editedAt != null) {
        json['edited_at'] = editedAt!.toIso8601String();
      }
    }
    if (replyToPostId != null) json['reply_to_post_id'] = replyToPostId;
    if (shareOriginalId != null) json['share_original_id'] = shareOriginalId;
    if (activityType != null) json['activity_type'] = activityType;
    if (activityData != null) json['activity_data'] = activityData;

    return json;
  }

  /// Create JSON for creating a new post (excludes read-only fields)
  Map<String, dynamic> toCreateJson() {
    final json = <String, dynamic>{
      'author_id': authorId,
      'content': content,
      'visibility': _visibilityToString(visibility),
      'kind': kind,
    };

    // Add optional fields
    if (mediaUrls.isNotEmpty) json['media_urls'] = mediaUrls;
    if (gameId != null) json['game_id'] = gameId;
    if (cityName != null) json['location_name'] = cityName;
    if (tags.isNotEmpty) json['tags'] = tags;
    if (mentionedUsers.isNotEmpty) {
      json['mentioned_users'] = mentionedUsers;
    }
    if (replyToPostId != null) json['reply_to_post_id'] = replyToPostId;
    if (shareOriginalId != null) json['share_original_id'] = shareOriginalId;
    if (activityType != null) json['activity_type'] = activityType;
    if (activityData != null) json['activity_data'] = activityData;

    return json;
  }

  /// Create JSON for updating a post (only editable fields)
  Map<String, dynamic> toUpdateJson() {
    final json = <String, dynamic>{
      'content': content,
      'visibility': _visibilityToString(visibility),
      'is_edited': true,
      'edited_at': DateTime.now().toIso8601String(),
      'kind': kind,
    };

    // Add optional fields
    if (mediaUrls.isNotEmpty) json['media_urls'] = mediaUrls;
    if (cityName != null) json['location_name'] = cityName;
    if (tags.isNotEmpty) json['tags'] = tags;
    if (mentionedUsers.isNotEmpty) {
      json['mentioned_users'] = mentionedUsers;
    }

    return json;
  }

  /// Create a copy with updated fields
  PostModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? content,
    List<String>? mediaUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    PostVisibility? visibility,
    String? gameId,
    String? locationName,
    bool? isLiked,
    bool? isBookmarked,
    String? authorBio,
    bool? authorVerified,
    List<String>? tags,
    List<String>? mentionedUsers,
    bool? isEdited,
    DateTime? editedAt,
    String? replyToPostId,
    String? shareOriginalId,
    String? kind,
    String? primaryVibeId,
    String? vibeEmoji,
    String? vibeLabel,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      visibility: visibility ?? this.visibility,
      gameId: gameId ?? this.gameId,
      cityName: cityName ?? cityName,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      authorBio: authorBio ?? this.authorBio,
      authorVerified: authorVerified ?? this.authorVerified,
      tags: tags ?? this.tags,
      mentionedUsers: mentionedUsers ?? this.mentionedUsers,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      replyToPostId: replyToPostId ?? this.replyToPostId,
      shareOriginalId: shareOriginalId ?? this.shareOriginalId,
      kind: kind ?? this.kind,
      primaryVibeId: primaryVibeId ?? this.primaryVibeId,
      vibeEmoji: vibeEmoji ?? this.vibeEmoji,
      vibeLabel: vibeLabel ?? this.vibeLabel,
    );
  }

  // Helper methods for parsing
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    if (value is double) return value.round();
    return 0;
  }

  static bool _parseBoolean(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is int) return value == 1;
    return false;
  }

  static String _visibilityToString(PostVisibility visibility) {
    switch (visibility) {
      case PostVisibility.public:
        return 'public';
      case PostVisibility.friends:
        return 'circle';
      case PostVisibility.private:
        return 'private';
      case PostVisibility.gameParticipants:
        return 'link';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PostModel{id: $id, authorName: $authorName, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}}';
  }
}

/// Post comment model for nested comment data
class PostCommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likesCount;
  final bool isLiked;
  final String? replyToCommentId;
  final List<PostCommentModel> replies;

  const PostCommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.likesCount,
    required this.isLiked,
    this.replyToCommentId,
    this.replies = const [],
  });

  factory PostCommentModel.fromJson(Map<String, dynamic> json) {
    final authorData = json['profiles'] ?? json['author'] ?? {};

    // Parse replies if present
    List<PostCommentModel> replies = [];
    if (json['replies'] != null && json['replies'] is List) {
      replies = (json['replies'] as List)
          .map((reply) => PostCommentModel.fromJson(reply))
          .toList();
    }

    return PostCommentModel(
      id: json['id'] ?? '',
      postId: json['post_id'] ?? '',
      authorId: json['author_id'] ?? json['user_id'] ?? '',
      authorName:
          authorData['display_name'] ??
          authorData['username'] ??
          authorData['full_name'] ??
          'Unknown User',
      authorAvatar:
          authorData['avatar_url'] ?? authorData['profile_picture'] ?? '',
      // Map `body` (post_comments.body) primarily, with `content` as fallback.
      content: json['body'] ?? json['content'] ?? '',
      createdAt: PostModel._parseDateTime(json['created_at']),
      updatedAt: PostModel._parseDateTime(json['updated_at']),
      likesCount: PostModel._parseInt(json['likes_count'] ?? 0),
      isLiked: json['is_liked'] == true || json['user_has_liked'] == true,
      // Support both legacy `reply_to_comment_id` and current `parent_comment_id`.
      replyToCommentId:
          json['reply_to_comment_id'] ?? json['parent_comment_id'],
      replies: replies,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'author_id': authorId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'likes_count': likesCount,
      if (replyToCommentId != null) 'reply_to_comment_id': replyToCommentId,
    };
  }
}
