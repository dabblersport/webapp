import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

/// The clock Home's Upcoming countdown reads. Defaults to [DateTime.now];
/// tests override it to pin the date (KAN-784).
final homeNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Re-exports the home feed from post_providers for backward compatibility.
/// Uses page 0 (first page) as the default home view.
final latestFeedPostsProvider = FutureProvider.autoDispose<List<Post>>((
  ref,
) async {
  return ref.watch(homeFeedProvider(0).future);
});
