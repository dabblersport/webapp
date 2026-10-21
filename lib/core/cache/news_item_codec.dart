import 'package:dabbler/data/models/feed/feed_item.dart';

/// Cache codec for a news item (KAN-605): the `feed_posts` row shape
/// [FeedNewsItem.fromJson] reads, so a cached item opens as a full detail.
extension FeedNewsItemCacheJson on FeedNewsItem {
  Map<String, dynamic> toCacheJson() => {
    'news_id': newsId,
    'id': id,
    'news_title': title,
    'news_body': body,
    'news_cover_image_url': coverImageUrl,
    'news_source_label': sourceLabel,
    'news_source_url': sourceUrl,
    'news_feed_label': feedLabel,
    'like_count': likeCount,
    'comment_count': commentCount,
    'view_count': viewCount,
    'sport_id': sportId,
    'area_id': areaId,
    'tags': tags,
    'regions': regions,
    'is_pinned': isPinned,
    'priority_score': priorityScore,
    'created_at': createdAt.toIso8601String(),
  };
}
