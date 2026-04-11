import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_post.dart';
import 'package:dabbler/data/repositories/base_repository.dart';
import 'package:dabbler/data/repositories/feed_repository.dart';

class FeedRepositoryImpl extends BaseRepository implements FeedRepository {
  const FeedRepositoryImpl(super.svc);

  @override
  Future<Result<List<FeedPost>, Failure>> getNearbyFeed({
    required double lat,
    required double lng,
    int radius = 5000,
  }) {
    return guard<List<FeedPost>>(() async {
      final rows =
          await svc.client.rpc(
                'get_nearby_posts',
                params: {'p_lat': lat, 'p_lng': lng, 'p_radius': radius},
              )
              as List<dynamic>;
      return rows.cast<Map<String, dynamic>>().map(FeedPost.fromJson).toList();
    });
  }
}
