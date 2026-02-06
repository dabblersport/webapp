import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/models/social/post_model.dart';
import 'package:dabbler/features/social/services/social_service.dart';

/// Provides the most recent public posts for surfaces like the home screen.
final latestFeedPostsProvider = FutureProvider.autoDispose<List<PostModel>>((
  ref,
) async {
  final socialService = SocialService();
  // Fetch more posts for the home screen feed (default limit is 20)
  final posts = await socialService.getFeedPosts(limit: 20);
  return posts;
});
