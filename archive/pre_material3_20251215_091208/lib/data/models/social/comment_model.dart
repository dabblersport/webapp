/// Comment model for posts
class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorProfileId; // author_profile_id from post_comments
  final String authorName;
  final String? authorAvatar;
  final bool? authorVerified;
  final String content;
  final String? parentCommentId;
  final List<String> mentions; // list of mentioned profile IDs
  final Map<String, int>? reactions;
  final int likeCount; // from post_comments.like_count
  final bool isLiked; // whether current user liked this comment
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEdited;
  final bool isDeleted;
  final int repliesCount;
  final List<Map<String, dynamic>>
  commentMentions; // joined comment_mentions data
  final List<CommentModel> replies; // nested replies

  CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorProfileId,
    required this.authorName,
    this.authorAvatar,
    this.authorVerified,
    required this.content,
    this.parentCommentId,
    this.mentions = const [],
    this.reactions,
    this.likeCount = 0,
    this.isLiked = false,
    required this.createdAt,
    required this.updatedAt,
    this.isEdited = false,
    this.isDeleted = false,
    this.repliesCount = 0,
    this.commentMentions = const [],
    this.replies = const [],
  });

  /// Create CommentModel from JSON
  factory CommentModel.fromJson(Map<String, dynamic> json) {
    // Parse author data from nested profiles
    final authorData = json['profiles'] ?? json['author'] ?? {};

    // Parse mentions
    List<String> mentions = [];
    if (json['mentions'] != null && json['mentions'] is List) {
      mentions = (json['mentions'] as List<dynamic>).cast<String>();
    }

    // Parse comment_mentions (joined data)
    List<Map<String, dynamic>> commentMentions = [];
    if (json['comment_mentions'] != null && json['comment_mentions'] is List) {
      commentMentions = (json['comment_mentions'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    // Parse nested replies
    List<CommentModel> replies = [];
    if (json['replies'] != null && json['replies'] is List) {
      replies = (json['replies'] as List)
          .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return CommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] ?? json['author_user_id'] ?? '',
      authorProfileId: json['author_profile_id'] as String,
      authorName:
          authorData['display_name'] ?? json['author_name'] ?? 'Unknown',
      authorAvatar: authorData['avatar_url'] ?? json['author_avatar'],
      authorVerified: authorData['verified'] as bool?,
      content: json['body'] ?? json['content'] ?? '',
      parentCommentId: json['parent_comment_id'] as String?,
      mentions: mentions,
      reactions: (json['reactions'] as Map<String, dynamic>?)
          ?.cast<String, int>(),
      likeCount: json['like_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isEdited: json['is_edited'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      repliesCount: json['replies_count'] as int? ?? replies.length,
      commentMentions: commentMentions,
      replies: replies,
    );
  }

  /// Convert CommentModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'author_id': authorId,
      'author_profile_id': authorProfileId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'body': content,
      'parent_comment_id': parentCommentId,
      'mentions': mentions,
      'reactions': reactions,
      'like_count': likeCount,
      'is_liked': isLiked,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_edited': isEdited,
      'is_deleted': isDeleted,
      'replies_count': repliesCount,
    };
  }

  /// Create a copy with updated fields
  CommentModel copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorProfileId,
    String? authorName,
    String? authorAvatar,
    bool? authorVerified,
    String? content,
    String? parentCommentId,
    List<String>? mentions,
    Map<String, int>? reactions,
    int? likeCount,
    bool? isLiked,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
    bool? isDeleted,
    int? repliesCount,
    List<Map<String, dynamic>>? commentMentions,
    List<CommentModel>? replies,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorProfileId: authorProfileId ?? this.authorProfileId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorVerified: authorVerified ?? this.authorVerified,
      content: content ?? this.content,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      mentions: mentions ?? this.mentions,
      reactions: reactions ?? this.reactions,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      repliesCount: repliesCount ?? this.repliesCount,
      commentMentions: commentMentions ?? this.commentMentions,
      replies: replies ?? this.replies,
    );
  }

  @override
  String toString() {
    return 'CommentModel(id: $id, postId: $postId, authorName: $authorName, content: $content)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
