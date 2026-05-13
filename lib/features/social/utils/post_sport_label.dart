import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

/// Resolves the locale-appropriate sport label for a post.
///
/// Looks up the cached [Sport] via [Post.sportId] from `sportsProvider` and
/// returns its `localizedName(context)`. Falls back to the snapshot
/// [Post.sport] string when the lookup misses (sportId null, provider not
/// loaded, or sport not found).
String resolvePostSportLabel(
  BuildContext context,
  WidgetRef ref,
  Post post,
) {
  if (post.sportId != null) {
    final sports = ref.watch(sportsProvider).valueOrNull;
    if (sports != null) {
      for (final s in sports) {
        if (s.id == post.sportId) return s.localizedName(context);
      }
    }
  }
  return post.sport ?? '';
}
