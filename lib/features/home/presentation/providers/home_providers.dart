import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

/// Re-exports the home feed from post_providers for backward compatibility.
/// Uses page 0 (first page) as the default home view.
final latestFeedPostsProvider = FutureProvider.autoDispose<List<Post>>((
  ref,
) async {
  return ref.watch(homeFeedProvider(0).future);
});
