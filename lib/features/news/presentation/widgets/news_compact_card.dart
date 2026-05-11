import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

/// Compact horizontal news card for the Most Recent feed.
///
/// Layout:
///   ┌──────────┬───────────────────────────┐
///   │ 160×160  │ Title (bold, 2 lines)     │
///   │  image   │ Body preview (240 chars)  │
///   └──────────┴───────────────────────────┘
class NewsCompactCard extends ConsumerWidget {
  const NewsCompactCard({
    super.key,
    required this.item,
    this.onDismiss,
  });

  final FeedNewsItem item;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final lang = locale.languageCode;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final rawBody = item.localizedBody(lang);
    final preview =
        rawBody.length > 80 ? '${rawBody.substring(0, 80)}…' : rawBody;

    final card = GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.newsDetail,
        pathParameters: {'newsId': item.newsId},
        extra: item,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Square cover image 80×80
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 80,
                height: 80,
                child: item.coverImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.coverImageUrl!,
                        httpHeaders: const {
                          'User-Agent':
                              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
                              ' AppleWebKit/537.36 (KHTML, like Gecko)'
                              ' Chrome/125.0.0.0 Safari/537.36',
                          'Accept':
                              'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
                        },
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: cs.surfaceContainerHighest),
                        errorWidget: (_, __, ___) =>
                            Container(color: cs.surfaceContainerHighest),
                      )
                    : Container(color: cs.surfaceContainerHighest),
              ),
            ),
            const SizedBox(width: 12),
            // Text block — constrained to image height
            Expanded(
              child: SizedBox(
                height: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.sourceLabel != null) ...[
                      Text(
                        item.sourceLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      item.localizedTitle(lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        height: 1.3,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onDismiss == null) return card;

    return Slidable(
      key: ValueKey(item.newsId),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.15,
        children: [
          SlidableAction(
            onPressed: (_) => onDismiss!(),
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            icon: Icons.visibility_off_outlined,
            label: 'Hide',
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
      child: card,
    );
  }
}
