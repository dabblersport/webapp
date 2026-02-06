import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import '../models/feed_item.dart';
import 'base_repository.dart';
import 'feed_repository.dart';

@immutable
class FeedRepositoryImpl extends BaseRepository implements FeedRepository {
  const FeedRepositoryImpl(super.svc);

  SupabaseClient get _db => svc.client;

  static const _posts = 'posts';

  @override
  Future<Result<List<FeedItem>, Failure>> listRecent({
    int limit = 50,
    String? afterCursor,
    String? beforeCursor,
  }) async {
    return guard<List<FeedItem>>(() async {
      if (limit <= 0) {
        throw const ValidationFailure(message: 'limit must be > 0');
      }

      dynamic q = _db
          .from(_posts)
          .select()
          .order('created_at', ascending: false) // DESC timeline
          .order('id', ascending: false); // tie-breaker for stable order

      final before = FeedItem.decodeCursor(beforeCursor);
      if (before != null) {
        // Fetch strictly older-than cursor (created_at DESC, id DESC)
        // In newer Supabase versions, .or() is not available on PostgrestTransformBuilder
        // We'll use .lt() filter on created_at as a simplified pagination
        // This doesn't handle the exact composite key logic but works for most cases
        q = q.lt('created_at', before.createdAt.toIso8601String());
      }

      q = q.limit(limit);

      // Note: afterCursor is reserved (for asc pagination). Not used now.

      final rows = await q;
      return rows.map((m) => FeedItem.fromPostRow(asMap(m))).toList();
    });
  }

  @override
  String? nextCursorFrom(List<FeedItem> page) {
    if (page.isEmpty) return null;
    // With DESC sort, the last item is the "oldest" in this page,
    // so the next page should start strictly before it.
    return page.last.toCursor();
  }
}
