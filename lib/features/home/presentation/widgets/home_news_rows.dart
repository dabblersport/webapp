import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/providers/locale_provider.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/public_activity.dart';
import 'package:dabbler/features/social/providers/post_providers.dart'
    show myReactionsProvider, postActionsProvider;
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_feed_parts.dart';

/// The user-agent / accept headers the news CDN requires for cover images.
const Map<String, String> _coverHeaders = <String, String>{
  'User-Agent':
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
};

void _openNews(BuildContext context, FeedNewsItem item) => context.pushNamed(
  RouteNames.newsDetail,
  pathParameters: {'newsId': item.newsId},
  extra: item,
);

/// A cover photo clipped to the design system's card radius.
///
/// DS GAP: no image / media component. The photo is the article's own content;
/// it is drawn with the framework image and the DS surface as its placeholder.
class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.radius});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final placeholder = ColoredBox(color: colors.surfaceSunken);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              headers: _coverHeaders,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : placeholder,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact news row (Most Recent feed)
// ─────────────────────────────────────────────────────────────────────────────

/// Compact horizontal news row. Swiping it toward the end calls [onDismiss]
/// ("Hide news"), exactly as the previous row did.
class HomeNewsCompactRow extends ConsumerWidget {
  const HomeNewsCompactRow({super.key, required this.item, this.onDismiss});

  final FeedNewsItem item;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DabblerColors.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final rawBody = item.localizedBody(lang);
    final preview =
        rawBody.length > 80 ? '${rawBody.substring(0, 80)}…' : rawBody;

    final Widget row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openNews(context, item),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space6,
          vertical: DabblerSpacing.space3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: _Cover(url: item.coverImageUrl, radius: DabblerRadius.lg),
            ),
            const SizedBox(width: DabblerSpacing.space4),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.sourceLabel != null)
                      Text(
                        item.sourceLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: homeType(
                          context,
                          DabblerType.caption1,
                          colors.brandPrimary,
                          weight: DabblerType.semibold,
                        ),
                      ),
                    Text(
                      item.localizedTitle(lang),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: homeType(
                        context,
                        DabblerType.subheadline,
                        colors.textPrimary,
                        weight: DabblerType.semibold,
                      ),
                    ),
                    if (preview.isNotEmpty)
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: homeType(
                          context,
                          DabblerType.footnote,
                          colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final VoidCallback? hide = onDismiss;
    if (hide == null) return row;

    // `Dismissible` is the framework's swipe behaviour (no visual of its own);
    // the reveal behind the row is design-system painted. The row never leaves
    // the list: the callback opens the confirmation sheet.
    return Dismissible(
      key: ValueKey<String>('news-${item.newsId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        hide();
        return false;
      },
      background: ColoredBox(
        color: colors.surfaceSunken,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: DabblerSpacing.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DabblerIcon('eye-slash', size: 22, color: colors.textPrimary),
                Text(
                  'Hide',
                  style: homeType(context, DabblerType.caption1, colors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
      child: row,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full news card (News tab)
// ─────────────────────────────────────────────────────────────────────────────

class HomeNewsCard extends ConsumerWidget {
  const HomeNewsCard({super.key, required this.item});

  final FeedNewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DabblerColors.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final body = item.localizedBody(lang);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openNews(context, item),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space4,
          vertical: DabblerSpacing.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Cover(url: item.coverImageUrl, radius: DabblerRadius.card),
                  if (item.feedLabel != null)
                    PositionedDirectional(
                      top: DabblerSpacing.space3,
                      start: DabblerSpacing.space3,
                      child: DabblerBadge(label: item.feedLabel!),
                    ),
                  if (item.isPinned)
                    PositionedDirectional(
                      top: DabblerSpacing.space3,
                      end: DabblerSpacing.space3,
                      child: DabblerIcon(
                        'bookmark-2',
                        size: 18,
                        color: colors.surfaceCard,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: DabblerSpacing.space3,
                vertical: DabblerSpacing.space3,
              ),
              child: Row(
                children: [
                  HomeNewsReactionButton(newsId: item.newsId),
                  const Spacer(),
                  HomeActionItem(
                    icon: 'message-text',
                    count: item.commentCount,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: DabblerSpacing.space4),
                  HomeActionItem(
                    icon: 'eye',
                    count: item.viewCount,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: DabblerSpacing.space4),
                  Text(
                    timeago.format(item.createdAt, locale: lang),
                    style: homeType(
                      context,
                      DabblerType.caption1,
                      colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (item.sourceLabel != null)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: DabblerSpacing.space3,
                ),
                child: Text(
                  item.sourceLabel!,
                  style: homeType(
                    context,
                    DabblerType.caption1,
                    colors.brandPrimary,
                    weight: DabblerType.semibold,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: DabblerSpacing.space3,
              ),
              child: Text(
                item.localizedTitle(lang),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: homeType(
                  context,
                  DabblerType.headline,
                  colors.textPrimary,
                ),
              ),
            ),
            if (body.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  DabblerSpacing.space3,
                  DabblerSpacing.space1,
                  DabblerSpacing.space3,
                  0,
                ),
                child: Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: homeType(
                    context,
                    DabblerType.footnote,
                    colors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// News reaction button (tap toggles, long-press opens the picker)
// ─────────────────────────────────────────────────────────────────────────────

/// The six reactions a news item takes (same ids as the previous like bar).
class _NewsReaction {
  const _NewsReaction(this.id, this.emoji, this.label);
  final String id;
  final String emoji;
  final String label;
}

const List<_NewsReaction> _newsReactions = <_NewsReaction>[
  _NewsReaction('bbcccbeb-e506-4906-8a58-018659d0a43d', '❤️', 'Loving'),
  _NewsReaction('477472a9-7535-42b6-b08d-d6054eee9856', '💪', 'Determined'),
  _NewsReaction('350a7cca-b044-4b22-8c96-add0dd39c059', '🔥', 'Motivated'),
  _NewsReaction('177211d5-73a4-4835-a7f2-48fd238c778d', '🏅', 'Proud'),
  _NewsReaction('f4a9f402-2dbd-40a9-8a6c-61cbea065145', '🥲', 'Disappointed'),
  _NewsReaction('4af43b42-a0f3-4008-812b-0b40548e32f6', '😡', 'Angry'),
];

final homeNewsReactionCountsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, newsId) async {
      final db = Supabase.instance.client;
      final allowedIds = _newsReactions.map((r) => r.id).toList();
      final rows =
          await db
                  .from(SupabaseConfig.reactionsTable)
                  .select('vibe_id')
                  .eq('parent_activity_id', newsId)
                  .inFilter('vibe_id', allowedIds)
              as List;
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['vibe_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    });

class HomeNewsReactionButton extends ConsumerWidget {
  const HomeNewsReactionButton({super.key, required this.newsId});

  final String newsId;

  Future<void> _toggle(
    WidgetRef ref,
    _NewsReaction reaction,
    Set<String> mine,
  ) async {
    final actions = ref.read(postActionsProvider.notifier);
    if (mine.contains(reaction.id)) {
      await actions.removeReaction(newsId, reaction.id);
    } else {
      for (final id in mine) {
        await actions.removeReaction(newsId, id);
      }
      await actions.reactToPost(newsId, reaction.id);
    }
    ref.invalidate(homeNewsReactionCountsProvider(newsId));
    ref.invalidate(myReactionsProvider(newsId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DabblerColors.of(context);
    final mine = ref.watch(myReactionsProvider(newsId)).valueOrNull ?? const <String>{};
    final counts =
        ref.watch(homeNewsReactionCountsProvider(newsId)).valueOrNull ?? const {};
    final active = _newsReactions.firstWhere(
      (r) => mine.contains(r.id),
      orElse: () => _newsReactions.first,
    );
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(ref, active, mine),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showDabblerSheet<void>(
          context: context,
          title: 'React',
          detents: const <double>[0.4],
          builder: (ctx) => Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DabblerSpacing.space6,
              DabblerSpacing.space2,
              DabblerSpacing.space6,
              DabblerSpacing.space8,
            ),
            child: Wrap(
              spacing: DabblerSpacing.space2,
              runSpacing: DabblerSpacing.space2,
              children: [
                for (final r in _newsReactions)
                  DabblerChip(
                    label: '${r.emoji} ${r.label}',
                    selected: mine.contains(r.id),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _toggle(ref, r, mine);
                    },
                  ),
              ],
            ),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DabblerIcon(
            'heart',
            weight: mine.isNotEmpty
                ? DabblerIconWeight.bold
                : DabblerIconWeight.linear,
            size: 20,
            color: mine.isNotEmpty ? colors.brandPrimary : colors.textSecondary,
          ),
          if (total > 0) ...[
            const SizedBox(width: DabblerSpacing.space2),
            Text(
              homeCompactCount(total),
              style: homeType(context, DabblerType.caption1, colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity row (Following)
// ─────────────────────────────────────────────────────────────────────────────

/// A `public_activities` row: avatar, "name action · time", and the news item it
/// points at when it is a comment on one.
class HomeActivityRow extends StatelessWidget {
  const HomeActivityRow({super.key, required this.activity});

  final PublicActivity activity;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final hasNewsTarget =
        activity.activityType == PublicActivityType.comment &&
        activity.targetNewsId != null;
    final newsTitle = activity.localizedTargetTitle(locale);
    final base = homeType(context, DabblerType.subheadline, colors.textPrimary);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasNewsTarget ? () => _navigateToNews(context) : null,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space6,
          vertical: DabblerSpacing.space4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeAvatar(
              name: activity.actorUsername,
              imageUrl: activity.actorAvatarUrl,
            ),
            const SizedBox(width: DabblerSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: base,
                      children: [
                        TextSpan(
                          text: activity.actorUsername,
                          style: base.copyWith(fontWeight: DabblerType.semibold),
                        ),
                        TextSpan(text: ' ${activity.actionLabel}'),
                        TextSpan(
                          text:
                              '  ·  ${timeago.format(activity.createdAt, allowFromNow: true, locale: locale)}',
                          style: homeType(
                            context,
                            DabblerType.caption1,
                            colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasNewsTarget && newsTitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: DabblerSpacing.space2,
                      ),
                      child: DabblerCard(
                        padding: const EdgeInsets.all(DabblerSpacing.space3),
                        child: Row(
                          children: [
                            if (activity.targetCoverImageUrl != null) ...[
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: _Cover(
                                  url: activity.targetCoverImageUrl,
                                  radius: DabblerRadius.sm,
                                ),
                              ),
                              const SizedBox(width: DabblerSpacing.space2),
                            ],
                            Expanded(
                              child: Text(
                                newsTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: homeType(
                                  context,
                                  DabblerType.footnote,
                                  colors.textSecondary,
                                  weight: DabblerType.medium,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
    // A minimal item for the route — the detail screen fetches the rest.
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
