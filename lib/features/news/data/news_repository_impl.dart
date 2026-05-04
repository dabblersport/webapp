import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/news/news_comment.dart';
import 'package:dabbler/data/repositories/base_repository.dart';
import 'news_repository.dart';

class NewsRepositoryImpl extends BaseRepository implements NewsRepository {
  const NewsRepositoryImpl(super.svc);

  @override
  Future<Result<List<FeedNewsItem>, Failure>> fetchNewsTab({
    int limit = 20,
    int offset = 0,
  }) =>
      guard(() async {
        final rows = await svc.client
            .from(SupabaseConfig.publishedNewsTable)
            .select()
            .order('is_pinned', ascending: false)
            .order('priority_score', ascending: false)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        return (rows as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((row) => FeedNewsItem.fromJson(_normalizeRow(row)))
            .toList();
      });

  // ── Comments ──────────────────────────────────────────────────────────────

  @override
  Future<Result<List<NewsComment>, Failure>> fetchComments(
    String newsId, {
    int limit = 50,
    int offset = 0,
  }) =>
      guard(() async {
        final rows = await svc.client
            .from('comments')
            .select(
              '*, profiles!post_comments_author_profile_id_fkey'
              '(display_name, username, avatar_url)',
            )
            .eq('parent_activity_id', newsId)
            .order('created_at')
            .range(offset, offset + limit - 1);

        final flattened = (rows as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((r) {
              final row = Map<String, dynamic>.from(r);
              final profile = row.remove('profiles');
              if (profile is Map) {
                row['author_display_name'] = profile['display_name'];
                row['author_username'] = profile['username'];
                row['author_avatar_url'] = profile['avatar_url'];
              }
              return row;
            })
            .toList();

        return flattened.map(NewsComment.fromJson).toList();
      });

  @override
  Future<Result<NewsComment, Failure>> addComment(
    String newsId,
    String body,
    Map<String, String> newsTitleSnapshot,
  ) =>
      guard(() async {
        final uid = svc.authUserId()!;
        final pid = await _profileId();

        // Insert without chained .single() — RLS on RETURNING can block 0 rows.
        await svc.client.from('comments').insert({
          'parent_activity_id': newsId,
          'author_user_id': uid,
          'author_profile_id': pid,
          'body': body,
        });

        // Fetch the just-inserted row with profile join.
        final rows = await svc.client
            .from('comments')
            .select(
              '*, profiles!post_comments_author_profile_id_fkey'
              '(display_name, username, avatar_url)',
            )
            .eq('parent_activity_id', newsId)
            .eq('author_profile_id', pid)
            .order('created_at', ascending: false)
            .limit(1);

        final list = rows as List<dynamic>;
        if (list.isEmpty) throw Exception('comment not found after insert');

        final r = Map<String, dynamic>.from(list.first as Map);
        final profile = r.remove('profiles');
        if (profile is Map) {
          r['author_display_name'] = profile['display_name'];
          r['author_username'] = profile['username'];
          r['author_avatar_url'] = profile['avatar_url'];
        }
        return NewsComment.fromJson(r);
      });

  Future<String> _profileId() async {
    final uid = svc.authUserId()!;
    final rows = await svc.client
        .from('profiles')
        .select('id')
        .eq('user_id', uid)
        .limit(1);
    final list = rows as List<dynamic>;
    if (list.isEmpty) throw Exception('profile not found for user $uid');
    return (list.first as Map<String, dynamic>)['id'] as String;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// `published_news` uses `id` as its primary key (same value as `news_id`
  /// in the feed_posts view). Remap column names so FeedNewsItem.fromJson
  /// can parse without branching.
  static Map<String, dynamic> _normalizeRow(Map<String, dynamic> row) => {
        ...row,
        if (!row.containsKey('news_id')) 'news_id': row['id'],
        if (!row.containsKey('news_title')) 'news_title': row['title'],
        if (!row.containsKey('news_body')) 'news_body': row['body'],
        if (!row.containsKey('news_cover_image_url'))
          'news_cover_image_url': row['cover_image_url'],
        if (!row.containsKey('news_source_label'))
          'news_source_label': row['source_label'],
        if (!row.containsKey('news_source_url'))
          'news_source_url': row['source_url'],
        if (!row.containsKey('news_feed_label'))
          'news_feed_label': row['feed_label'],
      };
}
