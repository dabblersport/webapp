import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:go_router/go_router.dart';

import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'news_label_badge.dart';
import 'news_like_bar.dart';

/// Card widget for a single news article in the feed or News tab.
///
/// Layout:
///   ┌───────────────────────────────────┐
///   │  16:9 cover image                 │
///   │  [badge top-left]   [pin top-right]│
///   │  ░░░░░ gradient overlay ░░░░░░░░  │
///   ├───────────────────────────────────┤
///   │  source label           time ago  │
///   │  Title (bold, 2 lines max)        │
///   │  Body preview (2 lines max)       │
///   ├───────────────────────────────────┤
///   │  ♥ 42   💬 7   share →           │
///   └───────────────────────────────────┘
class NewsCard extends ConsumerWidget {
  const NewsCard({super.key, required this.item});

  final FeedNewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final lang = locale.languageCode;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.newsDetail,
        pathParameters: {'newsId': item.newsId},
        extra: item,
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverImage(item: item),
            _ActionRow(item: item),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  if (item.sourceLabel != null)
                    Text(
                      item.sourceLabel!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    timeago.format(item.createdAt),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                item.localizedTitle(lang),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  height: 1.3,
                ),
              ),
            ),
            if (item.localizedBody(lang).isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text(
                  item.localizedBody(lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.item});
  final FeedNewsItem item;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.coverImageUrl != null)
            CachedNetworkImage(
              imageUrl: item.coverImageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey.shade800),
              errorWidget: (_, __, ___) =>
                  Container(color: Colors.grey.shade800),
            )
          else
            Container(color: Colors.grey.shade800),
          // Bottom gradient for legibility
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ),
          // Feed label badge — top left
          if (item.feedLabel != null)
            Positioned(
              top: 10,
              left: 10,
              child: NewsLabelBadge(item.feedLabel!),
            ),
          // Pin icon — top right
          if (item.isPinned)
            const Positioned(
              top: 10,
              right: 10,
              child: Icon(Iconsax.bookmark_2_copy, color: Colors.white, size: 18),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item});
  final FeedNewsItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: NewsLikeBar(
        newsId: item.newsId,
        commentCount: item.commentCount,
        viewCount: item.viewCount,
      ),
    );
  }
}
