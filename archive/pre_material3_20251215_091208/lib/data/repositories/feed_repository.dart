import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/feed_item.dart';

abstract class FeedRepository {
  /// Home timeline for the signed-in user.
  /// Server-side RLS decides visibility; client just paginates.
  Future<Result<List<FeedItem>, Failure>> listRecent({
    int limit = 50,
    String? afterCursor, // not used in desc sort (kept for symmetry)
    String? beforeCursor, // fetch older items before this cursor
  });

  /// Convenience: return the next page cursor given the last page returned.
  /// Implemented client-side as the last item's cursor (or null if empty).
  String? nextCursorFrom(List<FeedItem> page);
}
