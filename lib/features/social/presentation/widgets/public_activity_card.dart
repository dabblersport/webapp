import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// A `public_activities` row ("username [action] · time", plus an optional
/// news preview), drawn by [DabblerActivityRow].
class PublicActivityCard extends StatelessWidget {
  const PublicActivityCard({super.key, required this.activity});

  final PublicActivity activity;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final hasNewsTarget =
        activity.activityType == PublicActivityType.comment &&
        activity.targetNewsId != null;
    final newsTitle = activity.localizedTargetTitle(locale);

    return DabblerActivityRow(
      leading: DabblerAvatar(
        seed: activity.actorUsername,
        imageUrl: activity.actorAvatarUrl,
        size: DabblerAvatarSize.sm,
      ),
      actor: activity.actorUsername,
      verb: activity.actionLabel,
      subject: hasNewsTarget && newsTitle.isNotEmpty ? newsTitle : null,
      when: timeago.format(
        activity.createdAt,
        allowFromNow: true,
        locale: locale,
      ),
      thumbnail: hasNewsTarget && activity.targetCoverImageUrl != null
          ? DabblerImage(
              url: activity.targetCoverImageUrl,
              radius: BorderRadius.zero,
            )
          : null,
      onTap: hasNewsTarget ? () => _navigateToNews(context) : null,
    );
  }

  void _navigateToNews(BuildContext context) {
    final newsId = activity.targetNewsId!;
    // Build a minimal FeedNewsItem for the route — NewsDetailScreen fetches
    // full data from the DB, so counts/body being empty here is fine.
    final item = FeedNewsItem(
      newsId: newsId,
      id: activity.parentActivityId ?? newsId,
      title: activity.targetTitle,
      body: const {},
      likeCount: 0,
      commentCount: 0,
      viewCount: 0,
      tags: const [],
      isPinned: false,
      priorityScore: 0,
      createdAt: activity.createdAt,
      coverImageUrl: activity.targetCoverImageUrl,
    );
    context.pushNamed(
      RouteNames.newsDetail,
      pathParameters: {'newsId': newsId},
      extra: item,
    );
  }
}
