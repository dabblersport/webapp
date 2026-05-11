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
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            if (item.sourceLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Text(
                  item.sourceLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.coverImageUrl != null)
            CachedNetworkImage(
              imageUrl: item.coverImageUrl!,
              httpHeaders: const {
                'User-Agent':
                    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
                'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
              },
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.item});
  final FeedNewsItem item;

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: Row(
        children: [
          NewsLikeBar(newsId: item.newsId),
          const Spacer(),
          Icon(Iconsax.message_copy, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(_fmt(item.commentCount), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(width: 10),
          Icon(Iconsax.eye_copy, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(_fmt(item.viewCount), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(width: 10),
          Text(
            timeago.format(item.createdAt, locale: lang),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
