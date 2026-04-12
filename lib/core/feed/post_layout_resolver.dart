import 'package:flutter/material.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/social/presentation/widgets/feed_post_card.dart';
import 'package:dabbler/features/social/presentation/widgets/repost_card.dart';
import 'package:dabbler/features/social/presentation/widgets/kind_cards/alert_kind_card.dart';
import 'package:dabbler/features/social/presentation/widgets/kind_cards/announcement_kind_card.dart';
import 'package:dabbler/features/social/presentation/widgets/kind_cards/feature_kind_card.dart';
import 'package:dabbler/features/social/presentation/widgets/kind_cards/general_kind_card.dart';
import 'package:dabbler/features/social/presentation/widgets/kind_cards/highlight_kind_card.dart';
import 'package:dabbler/features/social/presentation/widgets/kind_cards/news_kind_card.dart';

/// Resolves which card widget to render for a given [Post].
///
/// Routing rules:
///   - Reposts (`OriginType.repost`)  -> [RepostCard]
///   - `PostType.allocated`           -> kind-specific card via [_resolveKindCard]
///   - Everything else                -> [FeedPostCard]
///
/// Callers must not branch on [Post.originType] or [Post.postType] directly;
/// all layout decisions live here.
Widget resolvePostLayout(Post post, {bool showNearbyChipInHeader = false}) {
  if (post.originType == OriginType.repost) {
    return RepostCard(post: post);
  }

  switch (post.postType) {
    case PostType.allocated:
      return _resolveKindCard(post);

    case PostType.moment:
    case PostType.dab:
    case PostType.kickIn:
      return FeedPostCard(
        post: post,
        showNearbyChipInHeader: showNearbyChipInHeader,
      );
  }
}

/// Maps a [PostKind] to its dedicated card widget.
Widget _resolveKindCard(Post post) {
  switch (post.kind) {
    case PostKind.news:
      return NewsKindCard(post: post);
    case PostKind.announcement:
      return AnnouncementKindCard(post: post);
    case PostKind.alert:
      return AlertKindCard(post: post);
    case PostKind.highlight:
      return HighlightKindCard(post: post);
    case PostKind.feature:
      return FeatureKindCard(post: post);
    case PostKind.general:
    case PostKind.original:
      return GeneralKindCard(post: post);
  }
}

/// Returns `true` when the post maps to a kind-specific card that manages
/// its own spacing/dividers.
bool postNativesSeparator(Post post) =>
    post.originType != OriginType.repost && post.postType == PostType.allocated;
