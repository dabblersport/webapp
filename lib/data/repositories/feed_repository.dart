import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_post.dart';

abstract class FeedRepository {
  Future<Result<List<FeedPost>, Failure>> getNearbyFeed({
    required double lat,
    required double lng,
    int radius = 5000,
  });
}
