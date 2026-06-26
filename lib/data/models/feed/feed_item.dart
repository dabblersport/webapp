import 'dart:convert';

import 'package:dabbler/data/models/social/post.dart';

/// Union type for items that appear in the `feed_posts` Supabase VIEW.
///
/// Branch on `news_id` presence:
///   news_id != null  →  FeedNewsItem
///   news_id == null  →  FeedPostItem (social post)
sealed class FeedItem {
  const FeedItem();

  static FeedItem fromFeedPostsRow(Map<String, dynamic> json) {
    // Treat only a non-empty news_id as a news row; an empty string would
    // otherwise route here and corrupt dedup keys downstream.
    final newsId = json['news_id'];
    if (newsId is String && newsId.isNotEmpty) {
      return FeedNewsItem.fromJson(json);
    }
    return FeedPostItem.fromFeedPostsRow(json);
  }
}

// ---------------------------------------------------------------------------
// Social post variant
// ---------------------------------------------------------------------------

final class FeedPostItem extends FeedItem {
  const FeedPostItem(this.post);

  final Post post;

  factory FeedPostItem.fromFeedPostsRow(Map<String, dynamic> json) =>
      FeedPostItem(Post.fromJson(json));
}

// ---------------------------------------------------------------------------
// News variant
// ---------------------------------------------------------------------------

final class FeedNewsItem extends FeedItem {
  const FeedNewsItem({
    required this.newsId,
    required this.id,
    required this.title,
    required this.body,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    required this.tags,
    required this.isPinned,
    required this.priorityScore,
    required this.createdAt,
    this.coverImageUrl,
    this.sourceLabel,
    this.sourceUrl,
    this.feedLabel,
    this.sportId,
    this.areaId,
    this.regions = const [],
  });

  final String newsId;
  final String id;

  /// Multilingual title map, e.g. {"en": "...", "ar": "..."}.
  final Map<String, String> title;

  /// Multilingual body map — used as preview text.
  final Map<String, String> body;

  final String? coverImageUrl;
  final String? sourceLabel;
  final String? sourceUrl;

  /// Feed label badge value, e.g. "Breaking", "Trending".
  final String? feedLabel;

  final int likeCount;
  final int commentCount;
  final int viewCount;
  final String? sportId;
  final String? areaId;
  final List<String> tags;
  final List<String> regions;
  final bool isPinned;
  final double priorityScore;
  final DateTime createdAt;

  factory FeedNewsItem.fromJson(Map<String, dynamic> json) {
    Map<String, String> toStringMap(dynamic raw) {
      if (raw == null) return const {};
      // published_news stores title/body as a JSON string — decode it first.
      if (raw is String) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {
          return {'en': raw};
        }
      }
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      return const {};
    }

    List<String> toStringList(dynamic raw) {
      if (raw == null) return const [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return const [];
    }

    // news_body may not exist on the VIEW — fall back to the shared `body` column.
    final rawBody = json['news_body'] ?? {'en': json['body'] ?? ''};

    final newsId = json['news_id'];
    if (newsId is! String || newsId.isEmpty) {
      throw FormatException('FeedNewsItem requires a non-empty news_id', newsId);
    }

    return FeedNewsItem(
      newsId: newsId,
      id: json['id'] as String,
      title: toStringMap(json['news_title']),
      body: toStringMap(rawBody),
      coverImageUrl: json['news_cover_image_url'] as String?,
      sourceLabel: json['news_source_label'] as String?,
      sourceUrl: json['news_source_url'] as String?,
      feedLabel: json['news_feed_label'] as String?,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      sportId: json['sport_id'] as String?,
      areaId: json['area_id'] as String?,
      tags: toStringList(json['tags']),
      regions: toStringList(json['regions']),
      isPinned: json['is_pinned'] as bool? ?? false,
      priorityScore: (json['priority_score'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Returns the localised title, falling back to English.
  String localizedTitle(String languageCode) =>
      title[languageCode] ?? title['en'] ?? '';

  /// Returns the localised body preview, falling back to English.
  String localizedBody(String languageCode) =>
      body[languageCode] ?? body['en'] ?? '';
}
