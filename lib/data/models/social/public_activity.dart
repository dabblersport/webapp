import 'dart:convert';

/// The kind of a [PublicActivity]. [wireValue] is the `activity_type` column
/// value. [unknown] keeps the model forward-compatible with server-added types.
enum PublicActivityType {
  comment('comment'),
  like('like'),
  repost('repost'),
  post('post'),
  gameCreate('game_create'),
  meetupCreate('meetup_create'),
  unknown('unknown');

  const PublicActivityType(this.wireValue);

  final String wireValue;

  static PublicActivityType fromWire(String? value) {
    for (final t in PublicActivityType.values) {
      if (t.wireValue == value) return t;
    }
    return PublicActivityType.unknown;
  }
}

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

  /// The activity kind, parsed from the `activity_type` column.
  final PublicActivityType activityType;
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

  String get actionLabel => switch (activityType) {
        PublicActivityType.comment => 'commented on a news article',
        PublicActivityType.like => 'liked a post',
        PublicActivityType.repost => 'reposted',
        PublicActivityType.gameCreate => 'created a game',
        PublicActivityType.meetupCreate => 'created a meetup',
        PublicActivityType.post => 'posted',
        PublicActivityType.unknown => 'was active',
      };

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
        activityType: PublicActivityType.fromWire(
          row['activity_type'] as String?,
        ),
        actorProfileId: row['actor_profile_id'] as String,
        actorUsername: actorUsername,
        actorAvatarUrl: actorAvatarUrl,
        parentActivityId: row['parent_activity_id'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
