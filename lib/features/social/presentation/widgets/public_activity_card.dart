import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Twitter/Facebook-style activity card rendered from a `public_activities` row.
/// Shows: avatar · "username [action]" · timestamp, plus optional news preview.
class PublicActivityCard extends StatelessWidget {
  const PublicActivityCard({super.key, required this.activity});

  final PublicActivity activity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;

    final hasNewsTarget =
        activity.activityType == 'comment' && activity.targetNewsId != null;
    final newsTitle = activity.localizedTargetTitle(locale);

    return InkWell(
      onTap: hasNewsTarget ? () => _navigateToNews(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DSAvatar(
              size: AvatarSize.small,
              customDimension: 36,
              imageUrl: activity.actorAvatarUrl,
              displayName: activity.actorUsername,
              context: AvatarContext.social,
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
              hasBorder: false,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                      children: [
                        TextSpan(
                          text: activity.actorUsername,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' ${activity.actionLabel}'),
                        TextSpan(
                          text:
                              '  ·  ${timeago.format(activity.createdAt, allowFromNow: true, locale: locale)}',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (hasNewsTarget && newsTitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          if (activity.targetCoverImageUrl != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                activity.targetCoverImageUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              newsTitle,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
