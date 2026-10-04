import 'package:flutter/widgets.dart';

import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_row.dart';

/// Resolves which row widget to render for a given [Post].
///
/// Every post — plain, repost or allocated kind — is a design-system post row
/// ([HomePostRow] / [HomeRepostRow]); the row itself shows a repost's quote and
/// an allocated kind's badge.
///
/// Callers must not branch on [Post.originType] or [Post.postType] directly;
/// all layout decisions live here.
Widget resolvePostLayout(
  Post post, {
  bool showNearbyChipInHeader = false,
  bool showActions = true,
}) => HomePostRow.resolve(
  post,
  showNearbyChipInHeader: showNearbyChipInHeader,
  showActions: showActions,
);
