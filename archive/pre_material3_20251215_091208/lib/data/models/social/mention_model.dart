/// Model for post_mentions
class PostMentionModel {
  final String postId;
  final String mentionedProfileId;
  final DateTime createdAt;
  final Map<String, dynamic>? mentionedProfile; // Joined profile data

  const PostMentionModel({
    required this.postId,
    required this.mentionedProfileId,
    required this.createdAt,
    this.mentionedProfile,
  });

  factory PostMentionModel.fromJson(Map<String, dynamic> json) {
    return PostMentionModel(
      postId: json['post_id'] as String,
      mentionedProfileId: json['mentioned_profile_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      mentionedProfile: json['profile'] != null || json['profiles'] != null
          ? (json['profile'] ?? json['profiles']) as Map<String, dynamic>
          : null,
    );
  }

  String? get displayName => mentionedProfile?['display_name'] as String?;
  String? get username => mentionedProfile?['username'] as String?;
  String? get avatarUrl => mentionedProfile?['avatar_url'] as String?;
}

/// Model for comment_mentions
class CommentMentionModel {
  final String commentId;
  final String mentionedProfileId;
  final DateTime createdAt;
  final Map<String, dynamic>? mentionedProfile; // Joined profile data

  const CommentMentionModel({
    required this.commentId,
    required this.mentionedProfileId,
    required this.createdAt,
    this.mentionedProfile,
  });

  factory CommentMentionModel.fromJson(Map<String, dynamic> json) {
    return CommentMentionModel(
      commentId: json['comment_id'] as String,
      mentionedProfileId: json['mentioned_profile_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      mentionedProfile: json['profile'] != null || json['profiles'] != null
          ? (json['profile'] ?? json['profiles']) as Map<String, dynamic>
          : null,
    );
  }

  String? get displayName => mentionedProfile?['display_name'] as String?;
  String? get username => mentionedProfile?['username'] as String?;
  String? get avatarUrl => mentionedProfile?['avatar_url'] as String?;
}
