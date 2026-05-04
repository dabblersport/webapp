class NewsComment {
  const NewsComment({
    required this.id,
    required this.newsId,
    required this.authorUserId,
    required this.authorProfileId,
    required this.body,
    required this.newsTitleSnapshot,
    required this.likeCount,
    required this.createdAt,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.authorUsername,
  });

  final String id;
  final String newsId;
  final String authorUserId;
  final String authorProfileId;
  final String body;

  /// Snapshot of the news title at comment time, e.g. {"en": "Title", "ar": "عنوان"}.
  final Map<String, String> newsTitleSnapshot;

  final int likeCount;
  final DateTime createdAt;

  // Joined from profiles table
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final String? authorUsername;

  factory NewsComment.fromJson(Map<String, dynamic> json) {
    Map<String, String> toStringMap(dynamic raw) {
      if (raw == null) return const {};
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      return const {};
    }

    return NewsComment(
      id: json['id'] as String,
      newsId: (json['news_id'] ?? json['parent_activity_id']) as String,
      authorUserId: json['author_user_id'] as String,
      authorProfileId: json['author_profile_id'] as String,
      body: json['body'] as String? ?? '',
      newsTitleSnapshot: toStringMap(json['news_title_snapshot']),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorDisplayName: json['author_display_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorUsername: json['author_username'] as String?,
    );
  }
}
