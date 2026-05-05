import 'dart:convert';

/// A row from `public_activities` enriched with actor profile info and,
/// for comment activities, the target news title.
///
/// Distinct from [ActivityFeedEvent] which models the personal activity log
/// (rpc_get_activity_feed) — this is the public social timeline.
class PublicActivity {
  const PublicActivity({
    required this.id,
    required this.activityType,
    required this.actorProfileId,
    required this.actorUsername,
    this.actorAvatarUrl,
    this.parentActivityId,
    this.targetTitle = const {},
    this.targetCoverImageUrl,
    this.targetNewsId,
    required this.createdAt,
  });

  final String id;

  /// 'comment', 'like', 'post', 'repost', 'game_create', 'meetup_create', etc.
  final String activityType;
  final String actorProfileId;
  final String actorUsername;
  final String? actorAvatarUrl;

  /// ID of the parent `public_activities` row (e.g. the news activity for comments).
  final String? parentActivityId;

  /// Multilingual news title, e.g. {"en": "...", "ar": "..."}.
  final Map<String, String> targetTitle;
  final String? targetCoverImageUrl;

  /// News UUID used to navigate to NewsDetailScreen.
  final String? targetNewsId;

  final DateTime createdAt;

  String localizedTargetTitle(String languageCode) =>
      targetTitle[languageCode] ?? targetTitle['en'] ?? '';

  String get actionLabel {
    switch (activityType) {
      case 'comment':
        return 'commented on a news article';
      case 'like':
        return 'liked a post';
      case 'repost':
        return 'reposted';
      case 'game_create':
        return 'created a game';
      case 'meetup_create':
        return 'created a meetup';
      case 'post':
        return 'posted';
      default:
        return 'was active';
    }
  }

  static Map<String, String> toStringMap(dynamic raw) {
    if (raw == null) return const {};
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
        }
        return {'en': raw};
      } catch (_) {
        return {'en': raw};
      }
    }
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }
    return const {};
  }

  PublicActivity withTarget({
    Map<String, String>? targetTitle,
    String? targetCoverImageUrl,
    String? targetNewsId,
  }) =>
      PublicActivity(
        id: id,
        activityType: activityType,
        actorProfileId: actorProfileId,
        actorUsername: actorUsername,
        actorAvatarUrl: actorAvatarUrl,
        parentActivityId: parentActivityId,
        targetTitle: targetTitle ?? this.targetTitle,
        targetCoverImageUrl: targetCoverImageUrl ?? this.targetCoverImageUrl,
        targetNewsId: targetNewsId ?? this.targetNewsId,
        createdAt: createdAt,
      );

  factory PublicActivity.fromRow(
    Map<String, dynamic> row, {
    required String actorUsername,
    String? actorAvatarUrl,
  }) =>
      PublicActivity(
        id: row['id'] as String,
        activityType: row['activity_type'] as String? ?? 'unknown',
        actorProfileId: row['actor_profile_id'] as String,
        actorUsername: actorUsername,
        actorAvatarUrl: actorAvatarUrl,
        parentActivityId: row['parent_activity_id'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
